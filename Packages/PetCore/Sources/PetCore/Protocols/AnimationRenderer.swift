import Foundation
import AppKit

public protocol AnimationRenderer: AnyObject {
    associatedtype RendererView: NSView

    init(pack: any PetBlueprint) throws
    func makeView() -> RendererView
    func transition(to state: StateKey, animated: Bool)
    func trigger(_ event: String)
    var viewSize: CGSize { get }
}
