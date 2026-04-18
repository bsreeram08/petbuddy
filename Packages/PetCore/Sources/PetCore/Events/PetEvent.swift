import Foundation

public enum PetEvent: Sendable {
    case incomingMessage(IncomingMessage)
    case toyPlaced(kind: ToyKind, position: LogicalPosition)
    case treatReceived(kind: TreatKind, position: LogicalPosition)
    case userClicked
    case friendConnected(PeerID)
    case friendDisconnected(PeerID)
    case idleTick
    case dndStateChanged(isDND: Bool)
    case misbehaviorTriggered(MisbehaviorEvent)
}

public enum MisbehaviorEvent: Sendable {
    case ignore
    case knock
    case chew
    case hide
}
