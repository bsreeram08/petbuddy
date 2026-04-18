import Foundation

public enum LogicalPosition: Codable, Sendable {
    case region(ScreenRegion)
    case normalized(x: Double, y: Double)

    public enum ScreenRegion: String, Codable, Sendable {
        case topLeft, topCenter, topRight
        case midLeft, center, midRight
        case botLeft, botCenter, botRight
    }
}
