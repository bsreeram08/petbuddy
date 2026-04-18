import Foundation

public protocol PetBlueprint: Sendable {
    var id: String { get }
    var species: Species { get }
    var displayName: String { get }
    var renderer: RendererKind { get }
    var states: [StateKey: StateDescriptor] { get }
    var sounds: [String: URL] { get }
    var packURL: URL { get }
}

public struct StateDescriptor: Codable, Sendable {
    public let frames: [Int]
    public let fps: Int
    public let loop: Bool

    public init(frames: [Int], fps: Int, loop: Bool) {
        self.frames = frames
        self.fps = fps
        self.loop = loop
    }
}
