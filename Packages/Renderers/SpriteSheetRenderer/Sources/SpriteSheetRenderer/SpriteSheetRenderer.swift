import Foundation
import AppKit
import PetCore

public final class SpriteSheetRenderer: AnimationRenderer {
    public typealias RendererView = SpriteView

    private let pack: any PetBlueprint
    private let frameWidth: Int
    private let frameHeight: Int

    public var viewSize: CGSize {
        CGSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight))
    }

    public init(pack: any PetBlueprint) throws {
        self.pack = pack

        let framesURL = pack.packURL.appendingPathComponent("assets/frames.json")
        guard let framesData = try? Data(contentsOf: framesURL),
              let framesJSON = try? JSONDecoder().decode(FramesJSON.self, from: framesData) else {
            throw SpriteSheetError.framesManifestMissing
        }

        self.frameWidth = framesJSON.frameWidth
        self.frameHeight = framesJSON.frameHeight
    }

    public func makeView() -> SpriteView {
        SpriteView(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            states: pack.states,
            initialState: StateKey.idle,
            packURL: pack.packURL
        )
    }

    public func transition(to state: StateKey, animated: Bool = true) {
        // View handles animation timing; no-op at renderer level
    }

    public func trigger(_ event: String) {}

    public enum SpriteSheetError: Error, LocalizedError {
        case sheetNotFound
        case framesManifestMissing
        public var errorDescription: String? {
            switch self {
            case .sheetNotFound: return "spritesheet.png not found"
            case .framesManifestMissing: return "frames.json not found"
            }
        }
    }
}

private struct FramesJSON: Codable {
    let frameWidth: Int
    let frameHeight: Int
}
