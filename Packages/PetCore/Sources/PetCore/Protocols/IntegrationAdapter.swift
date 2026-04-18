import Foundation

public protocol IntegrationAdapter: AnyObject, Sendable {
    static var identifier: String { get }
    static var displayName: String { get }

    var events: AsyncStream<PetEvent> { get }
    var status: IntegrationStatus { get }

    func connect() async throws
    func disconnect() async
}
