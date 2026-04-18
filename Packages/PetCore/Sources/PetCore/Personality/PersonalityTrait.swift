import Foundation

public struct PersonalityTrait: Sendable, Codable {
    public var value: Int

    public init(value: Int) {
        self.value = max(0, min(100, value))
    }
}

public struct PersonalityProfile: Sendable, Codable {
    public var naughtiness: PersonalityTrait
    public var playfulness: PersonalityTrait
    public var independence: PersonalityTrait
    public var affection: PersonalityTrait
    public var energy: PersonalityTrait

    public init(
        naughtiness: Int = 50,
        playfulness: Int = 50,
        independence: Int = 50,
        affection: Int = 50,
        energy: Int = 50
    ) {
        self.naughtiness = PersonalityTrait(value: naughtiness)
        self.playfulness = PersonalityTrait(value: playfulness)
        self.independence = PersonalityTrait(value: independence)
        self.affection = PersonalityTrait(value: affection)
        self.energy = PersonalityTrait(value: energy)
    }
}
