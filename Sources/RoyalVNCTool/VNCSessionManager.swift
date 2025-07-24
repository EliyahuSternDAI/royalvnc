import RoyalVNCKit
import Foundation

class VNCSessionManager {
    nonisolated(unsafe) static let shared = VNCSessionManager()
    private var sessions: [UUID: VNCConnection] = [:]
    private var delegates: [UUID: ConnectionDelegate] = [:]
    private let queue = DispatchQueue(label: "VNCSessionManager.queue")

    struct SessionConfig {
        let hostname: String
        let port: UInt16
        let username: String
        let password: String
        let shared: Bool
    }

    func startSession(config: SessionConfig) -> UUID {
        let sessionID = UUID()
        let settings = VNCConnection.Settings(
            isDebugLoggingEnabled: true,
            hostname: config.hostname,
            port: config.port,
            isShared: config.shared,
            isScalingEnabled: false,
            useDisplayLink: false,
            inputMode: .forwardKeyboardShortcutsEvenIfInUseLocally,
            isClipboardRedirectionEnabled: false,
            colorDepth: .depth24Bit,
            frameEncodings: .default
        )
        settings.requestFramebufferUpdates = false
        let connection = VNCConnection(settings: settings, logger: VNCPrintLogger())
        let connectionDelegate = ConnectionDelegate(username: config.username, password: config.password)
        connection.delegate = connectionDelegate
        queue.sync {
            sessions[sessionID] = connection
            delegates[sessionID] = connectionDelegate // Keep strong reference
        }
        connection.connect()
        return sessionID
    }

    func stopSession(sessionID: UUID) {
        queue.sync {
            if let connection = sessions[sessionID] {
                connection.disconnect()
                sessions.removeValue(forKey: sessionID)
                delegates.removeValue(forKey: sessionID) // Remove strong reference
            }
        }
    }

    func getSession(sessionID: UUID) -> VNCConnection? {
        return queue.sync {
            sessions[sessionID]
        }
    }

    func allSessionIDs() -> [UUID] {
        return queue.sync {
            Array(sessions.keys)
        }
    }
    
    func shutdownAllSessions() {
        for sessionID in allSessionIDs() {
            stopSession(sessionID: sessionID)
        }
    }
}
