import Foundation

public final class EventBus: @unchecked Sendable {
    private let continuation: AsyncStream<PetEvent>.Continuation
    public let stream: AsyncStream<PetEvent>

    public init() {
        var continuation: AsyncStream<PetEvent>.Continuation!
        stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func emit(_ event: PetEvent) {
        continuation.yield(event)
    }

    public func finish() {
        continuation.finish()
    }
}
