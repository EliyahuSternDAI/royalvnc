import ArgumentParser
import Atomics

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#elseif canImport(Android)
import Android
#endif

import RoyalVNCKit
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

import Dispatch

enum ServerSocketSpec {
    case unix(String)
    case tcp(Int)
}

@available(macOS 15.0, *)
final actor ShutdownManager {
    var server: GRPCServer<HTTP2ServerTransport.Posix>? = nil
    func setServer(_ s: GRPCServer<HTTP2ServerTransport.Posix>) async {
        server = s
    }
    func shutdownServer() async {
        server?.beginGracefulShutdown()
    }
}

// Global atomic flag for signal handler
let shutdownRequested = ManagedAtomic(false)
@available(macOS 15.0, *)
let shutdownManager = ShutdownManager()

func vncShutdownHandler(signal: Int32) {
    shutdownRequested.store(true, ordering: .relaxed)
}

@main
@available(macOS 15.0, *)
struct VNCClientTool: AsyncParsableCommand {
    @Flag(name: [.customShort("d"), .long], help: "Enable debug output")
    var debug: Bool = false

    @Option(name: [.customShort("s"), .long], help: "tcp:port or unix:path for Unix domain socket")
    var socket: String?
    
    var socketSpec: ServerSocketSpec? {
        guard let soc = socket else {
            return .tcp(5959) // Default port
        }
        
        if soc.hasPrefix("unix:") {
            let path = String(soc.dropFirst(5))
            return .unix(path)
        } else if soc.hasPrefix("tcp:") {
            let portString = String(soc.dropFirst(4))
            if let port = Int(portString) {
                return .tcp(port)
            }
        }
        
        return nil
    }
    
    @available(macOS 15.0, *)
    func run() async throws {
        print("Starting gRPC server on \(socketSpec.map { String(describing: $0) } ?? "none")")
        shutdownRequested.store(false, ordering: .relaxed)
        signal(SIGINT, vncShutdownHandler)
        signal(SIGTERM, vncShutdownHandler)

        switch socketSpec {
        case .unix(let path):
            let s = GRPCServer(
                transport: .http2NIOPosix(
                    address: .unixDomainSocket(path: path),
                    transportSecurity: .plaintext
                ),
                services: [VNCServiceImpl()]
            )
            await shutdownManager.setServer(s)
            try await s.serve()
        case .tcp(let sPort):
            let s = GRPCServer(
                transport: .http2NIOPosix(
                    address: .ipv4(host: "127.0.0.1", port: sPort),
                    transportSecurity: .plaintext
                ),
                services: [VNCServiceImpl()]
            )
            await shutdownManager.setServer(s)
            try await s.serve()
        case .none:
            print("Error: No valid socket specification provided.")
            Foundation.exit(EXIT_FAILURE)
        }

        // Poll for shutdownRequested
        while !shutdownRequested.load(ordering: .relaxed) {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        print("Shutdown requested, stopping server and sessions...")
        await shutdownManager.shutdownServer()
        VNCSessionManager.shared.shutdownAllSessions()
    }
}
