import XCTest
@testable import PetCore

// ── Fake timer ────────────────────────────────────────────────────────────────

final class FakeTimerProvider: TimerProvider {
    private var actions: [() -> Void] = []

    public func schedule(
        interval: TimeInterval,
        @MainActor action: @escaping @Sendable () -> Void
    ) -> any Cancellable {
        actions.append { Task { @MainActor in action() } }
        return FakeCancellable { [weak self] in self?.actions.removeAll() }
    }

    public func fireAll() { for a in actions { a() } }
}

final class FakeCancellable: Cancellable {
    private let cancelAction: () -> Void
    init(cancelAction: @escaping () -> Void) { self.cancelAction = cancelAction }
    func cancel() { cancelAction() }
}

// ── BehaviorEngine tests ─────────────────────────────────────────────────────

@MainActor
final class BehaviorEngineTests: XCTestCase {
    func testUserClickHappy() {
        let profile = PersonalityProfile(naughtiness: 50, playfulness: 50, independence: 50, affection: 50, energy: 50)
        let engine = BehaviorEngine(profile: profile, timerProvider: FakeTimerProvider())
        engine.onUserClick()
        XCTAssertEqual(engine.currentState, .happy)
        XCTAssertNotNil(engine.thoughtBubble)
    }

    func testDNDTriggersSleep() {
        let profile = PersonalityProfile(naughtiness: 50, playfulness: 50, independence: 50, affection: 50, energy: 50)
        let engine = BehaviorEngine(profile: profile, timerProvider: FakeTimerProvider())
        engine.onDNDStateChanged(isDND: true)
        XCTAssertEqual(engine.currentState, .sleep)
        engine.onDNDStateChanged(isDND: false)
        XCTAssertEqual(engine.currentState, .idle)
    }

    func testToyDropWalkState() {
        let profile = PersonalityProfile(naughtiness: 50, playfulness: 50, independence: 50, affection: 50, energy: 50)
        let engine = BehaviorEngine(profile: profile, timerProvider: FakeTimerProvider())
        engine.onToyDropped(kind: .bone, at: CGPoint(x: 100, y: 200))
        XCTAssertEqual(engine.currentState, .walk)
        XCTAssertEqual(engine.targetPosition, CGPoint(x: 100, y: 200))
    }

    func testIncomingMessageAlert() {
        let profile = PersonalityProfile(naughtiness: 50, playfulness: 50, independence: 50, affection: 50, energy: 50)
        let engine = BehaviorEngine(profile: profile, timerProvider: FakeTimerProvider())
        let msg = IncomingMessage(platform: .slack, fromDisplay: "Anika", preview: "hello!", timestamp: Date())
        engine.onIncomingMessage(msg)
        XCTAssertEqual(engine.currentState, .alert)
        XCTAssertTrue(engine.thoughtBubble?.text.contains("Anika") == true)
    }

    func testArrivedAtTargetHappy() {
        let profile = PersonalityProfile(naughtiness: 50, playfulness: 50, independence: 50, affection: 50, energy: 50)
        let engine = BehaviorEngine(profile: profile, timerProvider: FakeTimerProvider())
        engine.onArrivedAtTarget()
        XCTAssertEqual(engine.currentState, .happy)
        XCTAssertEqual(engine.thoughtBubble?.text, "found it!")
    }
}

// ── MisbehaviorEngine tests ─────────────────────────────────────────────────

@MainActor
final class MisbehaviorEngineTests: XCTestCase {
    func testNoMisbehaviorBelowThreshold() async {
        let profile = PersonalityProfile(naughtiness: 50)
        let me = MisbehaviorEngine(profile: profile)
        var fired = 0
        for i in 0..<100 {
            if await me.shouldMisbehave(now: Date().addingTimeInterval(TimeInterval(i * 400))) != nil {
                fired += 1
            }
        }
        XCTAssertEqual(fired, 0)
    }

    func testMisbehaviorFiresAboveThreshold() async {
        let profile = PersonalityProfile(naughtiness: 80)
        let me = MisbehaviorEngine(profile: profile)
        var fired = 0
        for i in 0..<200 {
            let time = Date().addingTimeInterval(TimeInterval(i * 400))
            if await me.shouldMisbehave(now: time) != nil { fired += 1 }
        }
        XCTAssertGreaterThan(fired, 5)
    }

    func testFiveMinuteCapBetweenEvents() async {
        let profile = PersonalityProfile(naughtiness: 90)
        let me = MisbehaviorEngine(profile: profile)
        let _ = await me.shouldMisbehave(now: Date())
        let event2 = await me.shouldMisbehave(now: Date().addingTimeInterval(1))
        XCTAssertNil(event2)
    }
}

// ── PersonalityTrait tests ──────────────────────────────────────────────────

final class PersonalityTraitTests: XCTestCase {
    func testClampedTo100() { XCTAssertEqual(PersonalityTrait(value: 150).value, 100) }
    func testClampedToZero() { XCTAssertEqual(PersonalityTrait(value: -10).value, 0) }
    func testInRange() { XCTAssertEqual(PersonalityTrait(value: 42).value, 42) }
}

// ── EventBus tests ─────────────────────────────────────────────────────────

final class EventBusTests: XCTestCase {
    func testSingleSubscriber() async {
        let bus = EventBus()
        let task = Task {
            var received: [PetEvent] = []
            for await event in bus.stream.prefix(3) { received.append(event) }
            return received
        }
        bus.emit(.userClicked)
        bus.emit(.userClicked)
        bus.emit(.userClicked)
        bus.finish()
        XCTAssertEqual(await task.value.count, 3)
    }

    func testMultipleEmits() async {
        let bus = EventBus()
        let task = Task {
            var count = 0
            for await _ in bus.stream.prefix(10) { count += 1 }
            return count
        }
        for _ in 0..<10 { bus.emit(.userClicked) }
        bus.finish()
        XCTAssertEqual(await task.value, 10)
    }
}
