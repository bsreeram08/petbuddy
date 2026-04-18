import Foundation

public enum IntegrationStatus: Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}
