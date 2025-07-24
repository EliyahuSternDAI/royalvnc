#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import RoyalVNCKit

final class ConnectionDelegate: VNCConnectionDelegate {
    var username: String
    var password: String
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    func connection(_ connection: VNCConnection,
                    stateDidChange connectionState: VNCConnection.ConnectionState) {
        let connectionStateString: String

        switch connectionState.status {
            case .connecting:
                connectionStateString = "Connecting"
            case .connected:
                connectionStateString = "Connected"
            case .disconnecting:
                connectionStateString = "Disconnecting"
            case .disconnected:
                connectionStateString = "Disconnected"
        }

        connection.logger.logDebug("connection stateDidChange: \(connectionStateString)")
    }

    func connection(_ connection: VNCConnection,
                    credentialFor authenticationType: VNCAuthenticationType,
                    completion: @escaping ((any VNCCredential)?) -> Void) {
        let authenticationTypeString: String

        switch authenticationType {
            case .vnc:
                authenticationTypeString = "VNC"
            case .appleRemoteDesktop:
                authenticationTypeString = "Apple Remote Desktop"
            case .ultraVNCMSLogonII:
                authenticationTypeString = "UltraVNC MS Logon II"
            @unknown default:
                fatalError("Unknown authentication type: \(authenticationType)")
        }

        connection.logger.logDebug("connection credentialFor: \(authenticationTypeString)")

        if authenticationType.requiresUsername,
           authenticationType.requiresPassword {

            completion(VNCUsernamePasswordCredential(username: username,
                                                     password: password))
        } else if authenticationType.requiresPassword {
            completion(VNCPasswordCredential(password: password))
        } else {
            completion(nil)
        }
    }

    func connection(_ connection: VNCConnection,
                    didCreateFramebuffer framebuffer: VNCFramebuffer) {
        connection.logger.logDebug("connection didCreateFramebuffer")
    }

    func connection(_ connection: VNCConnection,
                    didResizeFramebuffer framebuffer: VNCFramebuffer) {
        connection.logger.logDebug("connection didResizeFramebuffer")
    }

    func connection(_ connection: VNCConnection,
                    didUpdateFramebuffer framebuffer: VNCFramebuffer,
                    x: UInt16, y: UInt16,
                    width: UInt16, height: UInt16) {
        connection.logger.logDebug("connection didUpdateFramebuffer")
    }

    func connection(_ connection: VNCConnection,
                    didUpdateCursor cursor: VNCCursor) {
        connection.logger.logDebug("connection didUpdateCursor")
    }
}
