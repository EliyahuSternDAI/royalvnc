import GRPCCore
import Foundation
import NIO
import NIOTransportServices // or NIOTransportServices if using on Apple platforms
// Import your generated code module (e.g., RoyalVNCKit)
import RoyalVNCKit

@available(macOS 15.0, iOS 18.0, *)
final class VNCServiceImpl: @unchecked Sendable, Vnc_VNCService.SimpleServiceProtocol {
    // Remove single VNCConnection, use session manager
    init() {}
    
    // Start a new VNC session
    func startSession(request: Vnc_StartSessionRequest, context: GRPCCore.ServerContext) async throws -> Vnc_StartSessionResponse {
        let port: UInt16 = request.hasPort ? UInt16(request.port) : 5900
        let password: String = request.hasPassword ? request.password : ""
        let shared: Bool = request.hasShared ? request.shared : true
        let config = VNCSessionManager.SessionConfig(
            hostname: request.hostname,
            port: port,
            username: request.username,
            password: password,
            shared: shared
        )
        let sessionID = VNCSessionManager.shared.startSession(config: config)
        return Vnc_StartSessionResponse.with {
            $0.sessionID = sessionID.uuidString
            $0.success = true
            $0.message = "Session started"
        }
    }
    
    // Stop a VNC session
    func stopSession(request: Vnc_StopSessionRequest, context: GRPCCore.ServerContext) async throws -> Vnc_EventAck {
        guard let sessionID = UUID(uuidString: request.sessionID) else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Invalid session ID"
            }
        }
        VNCSessionManager.shared.stopSession(sessionID: sessionID)
        return Vnc_EventAck.with {
            $0.success = true
            $0.message = "Session stopped"
        }
    }
    
    // Helper to get session
    func getConnection(sessionID: String) async -> VNCConnection? {
        guard let uuid = UUID(uuidString: sessionID) else { return nil }
        return VNCSessionManager.shared.getSession(sessionID: uuid)
    }
    
    func sendPointerEvent(request: Vnc_PointerEvent, context: GRPCCore.ServerContext) async throws -> Vnc_EventAck {
        guard let uuid = UUID(uuidString: request.sessionID) else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        let connection = VNCSessionManager.shared.getSession(sessionID: uuid)
        guard let connection = connection else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        print("Received Pointer Event:", request)
        connection.mouseMove(x: UInt16(request.x), y: UInt16(request.y))
        return Vnc_EventAck.with {
            $0.success = true
            $0.message = "Pointer event added to queue"
        }
    }
    
    func sendMouseWheelEvent(request: Vnc_MouseWheelEvent, context: GRPCCore.ServerContext) async throws -> Vnc_EventAck {
        guard let uuid = UUID(uuidString: request.sessionID) else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        let connection = VNCSessionManager.shared.getSession(sessionID: uuid)
        guard let connection = connection else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        print("Received Mouse Wheel Event:", request)
        if (request.steps > 0) {
            print("Mouse wheel scrolled up")
            connection.mouseWheel(.up, x: UInt16(request.x), y: UInt16(request.y), steps: UInt32(request.steps))
        } else if (request.steps < 0) {
            print("Mouse wheel scrolled down")
            connection.mouseWheel(.down, x: UInt16(request.x), y: UInt16(request.y), steps: UInt32(-request.steps))
        }
        return Vnc_EventAck.with {
            $0.success = true
            $0.message = "Mouse wheel event added to queue"
        }
    }
    
    func sendMouseButtonEvent(request: Vnc_MouseButtonEvent, context: GRPCCore.ServerContext) async throws -> Vnc_EventAck {
        guard let uuid = UUID(uuidString: request.sessionID) else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        let connection = VNCSessionManager.shared.getSession(sessionID: uuid)
        guard let connection = connection else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        func buttonType(for number: UInt32) -> VNCMouseButton? {
            switch number {
            case 0: return .left
            case 1: return .middle
            case 2: return .right
            default: return nil
            }
        }
        guard let btn = buttonType(for: request.button) else {
            let action = request.pressed ? "pressed" : "released"
            print("Unknown mouse button \(action):", request.button)
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Unknown mouse button \(request.button) \(action)"
            }
        }
        let action = request.pressed ? "pressed" : "released"
        print("Mouse button \(action):", request.button)
        if request.pressed {
            connection.mouseButtonDown(btn, x: UInt16(request.x), y: UInt16(request.y))
        } else {
            connection.mouseButtonUp(btn, x: UInt16(request.x), y: UInt16(request.y))
        }
        return Vnc_EventAck.with {
            $0.success = true
            $0.message = "Mouse button event added to queue: \(btn) \(action) at (\(request.x), \(request.y))"
        }
    }
    
    func sendKeyEvent(request: Vnc_KeyEvent, context: GRPCCore.ServerContext) async throws -> Vnc_EventAck {
        guard let uuid = UUID(uuidString: request.sessionID) else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        let connection = VNCSessionManager.shared.getSession(sessionID: uuid)
        guard let connection = connection else {
            return Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found"
            }
        }
        print("Received Key Event:", request)
        if let scalar = UnicodeScalar(request.keycode) {
            let char = Character(scalar)
            if (request.pressed) {
                for keyCode in VNCKeyCode.withCharacter(char) {
                    connection.keyDown(keyCode)
                }
            } else {
                for keyCode in VNCKeyCode.withCharacter(char) {
                    connection.keyUp(keyCode)
                }
            }
        } else {
            print("Invalid keycode: \(request.keycode)")
        }
        return Vnc_EventAck.with {
            $0.success = true
            $0.message = "Key event added to queue"
        }
    }
}
