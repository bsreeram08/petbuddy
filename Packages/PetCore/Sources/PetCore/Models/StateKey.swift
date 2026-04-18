import Foundation

public struct StateKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public extension StateKey {
    static let idle  = StateKey(rawValue: "idle")
    static let walk  = StateKey(rawValue: "walk")
    static let happy = StateKey(rawValue: "happy")
    static let sleep = StateKey(rawValue: "sleep")
    static let alert = StateKey(rawValue: "alert")
}
