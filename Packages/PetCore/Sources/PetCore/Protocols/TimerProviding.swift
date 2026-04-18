import Foundation

public protocol TimerProvider: Sendable {
    func schedule(interval: TimeInterval, @MainActor action: @escaping @Sendable () -> Void) -> any Cancellable
}

public protocol Cancellable: Sendable {
    func cancel()
}

public final class RealTimerProvider: TimerProvider {
    public init() {}
    public func schedule(interval: TimeInterval, @MainActor action: @escaping @Sendable () -> Void) -> any Cancellable {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in action() }
        }
        return TimerCancellable(timer: timer)
    }
}

private final class TimerCancellable: Cancellable {
        private let timer: Timer
        fileprivate init(timer: Timer) { self.timer = timer }
        func cancel() { timer.invalidate() }
}
