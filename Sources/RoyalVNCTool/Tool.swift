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
import GRPC
import NIO

import Dispatch

enum ServerSocketSpec {
    case unix(String)
    case tcp(Int)
}

actor ShutdownManager {
    private var server: Server?

    func setServer(_ s: Server) {
        self.server = s
    }

    func shutdownServer() {
        // This is non-blocking, so it's safe to call from a synchronous context
        // if needed, but the actor guarantees mutual exclusion.
        server?.close().whenComplete { _ in }
    }
}

let shutdownRequested = ManagedAtomic(false)
let shutdownManager = ShutdownManager()

func vncShutdownHandler(signal: Int32) {
    shutdownRequested.store(true, ordering: .relaxed)
}

@main
struct VNCClientTool: ParsableCommand {
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
    
    func run() throws {
        let logger = VNCPrintLogger()
        
        if debug {
            logger.isDebugLoggingEnabled = true
        }
                
        print("Starting gRPC server on \(socketSpec.map { String(describing: $0) } ?? "none")")
        shutdownRequested.store(false, ordering: .relaxed)
        signal(SIGINT, vncShutdownHandler)
        signal(SIGTERM, vncShutdownHandler)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { try? group.syncShutdownGracefully() }

        let service: any CallHandlerProvider = VNCServiceImpl()
        let server: Server
        switch socketSpec {
        case .unix(let path):
            server = try Server.insecure(group: group)
                .withServiceProviders([service])
                .bind(unixDomainSocketPath: path)
                .wait()
        case .tcp(let sPort):
            server = try Server.insecure(group: group)
                .withServiceProviders([service])
                .bind(host: "127.0.0.1", port: sPort)
                .wait()
        case .none:
            print("Error: No valid socket specification provided.")
            Foundation.exit(EXIT_FAILURE)
        }

        Task {
            await shutdownManager.setServer(server)
        }

        // Poll for shutdownRequested
        while !shutdownRequested.load(ordering: .relaxed) {
            Thread.sleep(forTimeInterval: 0.1) // 100ms
        }
        print("Shutdown requested, stopping server and sessions...")
        Task {
            await shutdownManager.shutdownServer()
        }
        VNCSessionManager.shared.shutdownAllSessions()
    }
}
