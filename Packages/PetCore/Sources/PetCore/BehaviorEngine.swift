import AppKit
import Foundation

@MainActor
public final class BehaviorEngine: ObservableObject {
    @Published public private(set) var currentState: StateKey = .idle
    @Published public private(set) var thoughtBubble: ThoughtBubble?
    @Published public private(set) var targetPosition: CGPoint?

    private let profile: PersonalityProfile
    private let misbehaviorEngine: MisbehaviorEngine
    private let timerProvider: any TimerProvider
    private var cancellables: [any Cancellable] = []
    private let misbehaviorCheckInterval: TimeInterval = 60

    public init(profile: PersonalityProfile, timerProvider: (any TimerProvider)? = nil) {
        self.profile = profile
        self.misbehaviorEngine = MisbehaviorEngine(profile: profile)
        self.timerProvider = timerProvider ?? RealTimerProvider()
        startMisbehaviorTimer()
    }

    public func onUserClick() {
        let naughtiness = profile.naughtiness.value
        if naughtiness > 70, Double.random(in: 0...1) < 0.4 {
            thoughtBubble = ThoughtBubble(text: "...", style: .normal)
            scheduleBubbleClear(seconds: 1.5)
        } else {
            currentState = .happy
            thoughtBubble = ThoughtBubble(text: affectionReaction(), style: .happy)
            scheduleBubbleClear(seconds: 2.0)
            scheduleStateReturn(to: .idle, seconds: 2.0)
        }
    }

    public func onToyDropped(kind: ToyKind, at position: CGPoint) {
        targetPosition = position
        currentState = .walk
        thoughtBubble = nil
    }

    public func onArrivedAtTarget() {
        currentState = .happy
        thoughtBubble = ThoughtBubble(text: "found it!", style: .happy)
        scheduleStateReturn(to: .idle, seconds: 2.0)
        scheduleBubbleClear(seconds: 2.0)
    }

    public func onIncomingMessage(_ msg: IncomingMessage) {
        currentState = .alert
        thoughtBubble = ThoughtBubble(text: "\(msg.fromDisplay) says hi!", style: .alert)
        scheduleBubbleClear(seconds: 3.0)
        scheduleStateReturn(to: .idle, seconds: 3.0)
    }

    public func onDNDStateChanged(isDND: Bool) {
        if isDND {
            currentState = .sleep
            thoughtBubble = nil
        } else if currentState == .sleep {
            currentState = .idle
        }
    }

    private func startMisbehaviorTimer() {
        let t = timerProvider.schedule(interval: misbehaviorCheckInterval) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.onMisbehaviorTick()
            }
        }
        cancellables.append(t)
    }

    private func onMisbehaviorTick() async {
        if let event = await misbehaviorEngine.shouldMisbehave(now: Date()) {
            handleMisbehavior(event)
        }
    }

    private func handleMisbehavior(_ event: MisbehaviorEvent) {
        switch event {
        case .ignore:
            thoughtBubble = ThoughtBubble(text: "...", style: .normal)
            scheduleBubbleClear(seconds: 1.5)
        case .knock:
            thoughtBubble = ThoughtBubble(text: "*knocks things over*", style: .normal)
            scheduleBubbleClear(seconds: 2.0)
        case .chew:
            thoughtBubble = ThoughtBubble(text: "*chomp chomp*", style: .happy)
            scheduleBubbleClear(seconds: 2.5)
        case .hide:
            thoughtBubble = ThoughtBubble(text: "scared?", style: .normal)
            scheduleBubbleClear(seconds: 2.0)
        }
    }

    private func scheduleStateReturn(to state: StateKey, seconds: Double) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                if currentState != .idle {
                    currentState = state
                }
            }
        }
    }

    private func scheduleBubbleClear(seconds: Double) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                thoughtBubble = nil
            }
        }
    }

    private func affectionReaction() -> String {
        switch Int.random(in: 0...3) {
        case 0: return "*happy bark!*"
        case 1: return "*kisses*"
        case 2: return "*wiggle wiggle*"
        default: return "*happy bark!*"
        }
    }
}
