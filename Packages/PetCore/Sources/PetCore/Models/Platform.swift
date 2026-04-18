import Foundation

public enum Platform: String, Codable, Sendable {
    case slack
    case telegram
    case peerToPeer = "peerToPeer"
}
