import AppKit
import Foundation

@MainActor
public final class Pet: ObservableObject {
    public let blueprint: any PetBlueprint
    public let renderer: any AnimationRenderer
    public let behavior: BehaviorEngine

    @Published public var position: CGPoint
    @Published public var currentState: StateKey
    @Published public var thoughtBubble: ThoughtBubble?

    public init(
        blueprint: any PetBlueprint,
        renderer: any AnimationRenderer,
        profile: PersonalityProfile,
        initialPosition: CGPoint,
        timerProvider: (any TimerProvider)? = nil
    ) {
        self.blueprint = blueprint
        self.renderer = renderer
        self.behavior = BehaviorEngine(profile: profile, timerProvider: timerProvider)
        self.position = initialPosition
        self.currentState = .idle
    }

    public func handle(_ event: PetEvent) {
        switch event {
        case .userClicked:
            behavior.onUserClick()
        case .incomingMessage(let msg):
            behavior.onIncomingMessage(msg)
        case .toyPlaced(let kind, _):
            // position resolved by app layer; just trigger walk
            behavior.onToyDropped(kind: kind, at: position)
        case .dndStateChanged(let isDND):
            behavior.onDNDStateChanged(isDND: isDND)
        default:
            break
        }
        syncFromEngine()
    }

    public func onArrived() {
        behavior.onArrivedAtTarget()
        syncFromEngine()
    }

    private func syncFromEngine() {
        currentState = behavior.currentState
        thoughtBubble = behavior.thoughtBubble
    }
}
