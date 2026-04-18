import Foundation

public struct StateKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public extension StateKey {
    static let idle  = StateKey("idle")
    static let walk  = StateKey("walk")
    static let happy = StateKey("happy")
    static let sleep = StateKey("sleep")
    static let alert = StateKey("alert")
}
