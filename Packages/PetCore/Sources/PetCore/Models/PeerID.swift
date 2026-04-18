import Foundation

public struct PeerID: Hashable, Sendable {
    public let publicKey: Data
    public init(publicKey: Data) { self.publicKey = publicKey }
}
