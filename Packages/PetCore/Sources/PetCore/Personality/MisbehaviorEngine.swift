import Foundation

public actor MisbehaviorEngine {
    private let profile: PersonalityProfile
    private var lastEventTime: Date?
    private let minIntervalSeconds: TimeInterval = 300
    private let maxProbability: Double = 0.3

    public init(profile: PersonalityProfile) {
        self.profile = profile
    }

    public func shouldMisbehave(now: Date) -> MisbehaviorEvent? {
        let naughtiness = profile.naughtiness.value
        guard naughtiness > 60 else { return nil }
        if let last = lastEventTime, now.timeIntervalSince(last) < minIntervalSeconds {
            return nil
        }

        let probability = Double(naughtiness - 60) / 40.0 * maxProbability
        guard Double.random(in: 0...1) < probability else { return nil }

        lastEventTime = now

        let roll = Int.random(in: 0...3)
        switch roll {
        case 0: return .ignore
        case 1: return .knock
        case 2: return .chew
        default: return .hide
        }
    }
}
