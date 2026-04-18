import Foundation

public struct IncomingMessage: Sendable, Codable {
    public let platform: Platform
    public let fromDisplay: String
    public let preview: String
    public let timestamp: Date

    public init(platform: Platform, fromDisplay: String, preview: String, timestamp: Date) {
        self.platform = platform
        self.fromDisplay = fromDisplay
        self.preview = preview
        self.timestamp = timestamp
    }
}
