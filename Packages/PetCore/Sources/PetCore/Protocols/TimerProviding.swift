import Foundation

public protocol TimerProvider {
    func schedule(interval: TimeInterval, action: @escaping @Sendable () -> Void) -> any Cancellable
}

public protocol Cancellable {
    func cancel()
}

public final class RealTimerProvider: TimerProvider {
    public init() {}

    public func schedule(interval: TimeInterval, action: @escaping @Sendable () -> Void) -> any Cancellable {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in action() }
        }
        return TimerCancellable(timer: timer)
    }
}

private final class TimerCancellable: Cancellable {
    private weak var timer: Timer?
    fileprivate init(timer: Timer) { self.timer = timer }
    func cancel() { timer?.invalidate() }
}
