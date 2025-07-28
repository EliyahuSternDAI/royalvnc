import Foundation
import NIO
import RoyalVNCKit
import GRPC

final class VNCServiceImpl: Vnc_VNCServiceProvider {
    var interceptors: Vnc_VNCServiceServerInterceptorFactoryProtocol? { return nil }

    init() {}

    // Start a new VNC session
    func startSession(request: Vnc_StartSessionRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_StartSessionResponse> {
        let promise = context.eventLoop.makePromise(of: Vnc_StartSessionResponse.self)
        let port: UInt16 = request.port > 0 ? UInt16(request.port) : 5900
        let config = VNCSessionManager.SessionConfig(
            hostname: request.hostname,
            port: port,
            username: request.username,
            password: request.password,
            shared: request.shared
        )
        let sessionID = VNCSessionManager.shared.startSession(config: config)
        let response = Vnc_StartSessionResponse.with {
            $0.sessionID = sessionID.uuidString
            $0.success = true
            $0.message = "Session started successfully."
        }
        promise.succeed(response)
        return promise.futureResult
    }

    // Stop a VNC session
    func stopSession(request: Vnc_StopSessionRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_EventAck> {
        let promise = context.eventLoop.makePromise(of: Vnc_EventAck.self)
        guard let sessionID = UUID(uuidString: request.sessionID) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Invalid session ID format."
            })
            return promise.futureResult
        }
        VNCSessionManager.shared.stopSession(sessionID: sessionID)
        promise.succeed(Vnc_EventAck.with {
            $0.success = true
            $0.message = "Session stopped."
        })
        return promise.futureResult
    }

    // List all active sessions
    func listSessions(request: Vnc_ListSessionsRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_ListSessionsResponse> {
        let promise = context.eventLoop.makePromise(of: Vnc_ListSessionsResponse.self)
        let sessionInfos = VNCSessionManager.shared.allSessionInfo()
        let response = Vnc_ListSessionsResponse.with {
            $0.sessions = sessionInfos
            $0.success = true
            $0.message = "Successfully retrieved \(sessionInfos.count) active sessions."
        }
        promise.succeed(response)
        return promise.futureResult
    }

    // Send Pointer Event
    func sendPointerEvent(request: Vnc_PointerEvent, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_EventAck> {
        let promise = context.eventLoop.makePromise(of: Vnc_EventAck.self)
        guard let uuid = UUID(uuidString: request.sessionID),
              let connection = VNCSessionManager.shared.getSession(sessionID: uuid) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found or invalid ID."
            })
            return promise.futureResult
        }
        connection.mouseMove(x: UInt16(request.x), y: UInt16(request.y))
        promise.succeed(Vnc_EventAck.with {
            $0.success = true
            $0.message = "Pointer event sent successfully."
        })
        return promise.futureResult
    }

    // Send Mouse Wheel Event
    func sendMouseWheelEvent(request: Vnc_MouseWheelEvent, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_EventAck> {
        let promise = context.eventLoop.makePromise(of: Vnc_EventAck.self)
        guard let uuid = UUID(uuidString: request.sessionID),
              let connection = VNCSessionManager.shared.getSession(sessionID: uuid) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found or invalid ID."
            })
            return promise.futureResult
        }
        if (request.steps > 0) {
            connection.mouseWheel(.up, x: UInt16(request.x), y: UInt16(request.y), steps: UInt32(request.steps))
        } else if (request.steps < 0) {
            connection.mouseWheel(.down, x: UInt16(request.x), y: UInt16(request.y), steps: UInt32(-request.steps))
        }
        promise.succeed(Vnc_EventAck.with {
            $0.success = true
            $0.message = "Mouse wheel event sent successfully."
        })
        return promise.futureResult
    }

    // Send Mouse Button Event
    func sendMouseButtonEvent(request: Vnc_MouseButtonEvent, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_EventAck> {
        let promise = context.eventLoop.makePromise(of: Vnc_EventAck.self)
        guard let uuid = UUID(uuidString: request.sessionID),
              let connection = VNCSessionManager.shared.getSession(sessionID: uuid) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found or invalid ID."
            })
            return promise.futureResult
        }
        func buttonType(for number: UInt32) -> VNCMouseButton? {
            switch number {
            case 0: return .left
            case 1: return .middle
            case 2: return .right
            default: return nil
            }
        }
        guard let btn = buttonType(for: request.buttonMask) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Unknown mouse button: \(request.buttonMask)"
            })
            return promise.futureResult
        }
        if request.isPressed {
            connection.mouseButtonDown(btn, x: UInt16(request.x), y: UInt16(request.y))
        } else {
            connection.mouseButtonUp(btn, x: UInt16(request.x), y: UInt16(request.y))
        }
        promise.succeed(Vnc_EventAck.with {
            $0.success = true
            $0.message = "Mouse button event sent successfully."
        })
        return promise.futureResult
    }

    // Send Key Event
    func sendKeyEvent(request: Vnc_KeyEvent, context: StatusOnlyCallContext) -> EventLoopFuture<Vnc_EventAck> {
        let promise = context.eventLoop.makePromise(of: Vnc_EventAck.self)
        guard let uuid = UUID(uuidString: request.sessionID),
              let connection = VNCSessionManager.shared.getSession(sessionID: uuid) else {
            promise.succeed(Vnc_EventAck.with {
                $0.success = false
                $0.message = "Session not found or invalid ID."
            })
            return promise.futureResult
        }
        
        let keysym = request.keysym
        let keyCode = VNCKeyCode(keysym)

        if request.isPressed {
            connection.keyDown(keyCode)
        } else {
            connection.keyUp(keyCode)
        }
        
        promise.succeed(Vnc_EventAck.with {
            $0.success = true
            $0.message = "Key event for keysym \(keysym) sent successfully."
        })
        return promise.futureResult
    }
}
