import Foundation

public enum Species: Codable, Sendable {
    case puppy
    case cat
    case rabbit
    case custom(String)

    public var displayName: String {
        switch self {
        case .puppy: return "Puppy"
        case .cat: return "Cat"
        case .rabbit: return "Rabbit"
        case .custom(let s): return s
        }
    }
}
