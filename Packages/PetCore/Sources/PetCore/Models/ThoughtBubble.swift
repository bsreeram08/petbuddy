import Foundation

public struct ThoughtBubble: Sendable {
    public enum BubbleStyle: Sendable {
        case normal
        case happy
        case alert
    }

    public let text: String
    public let style: BubbleStyle

    public init(text: String, style: BubbleStyle = .normal) {
        self.text = text
        self.style = style
    }
}
