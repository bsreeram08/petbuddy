import Foundation

public enum PetPackError: Error, LocalizedError {
    case fileNotFound
    case invalidJSON
    case invalidSchema

    public var errorDescription: String? {
        switch self {
        case .fileNotFound: return "manifest.json not found"
        case .invalidJSON: return "manifest.json is not valid JSON"
        case .invalidSchema: return "manifest.json missing required fields"
        }
    }
}

public final class ManifestLoader {
    public init() {}

    public func load(from packURL: URL) throws -> LoadedPetPack {
        let manifestURL = packURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PetPackError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw PetPackError.invalidJSON
        }

        let manifest: ManifestJSON
        do {
            manifest = try JSONDecoder().decode(ManifestJSON.self, from: data)
        } catch {
            throw PetPackError.invalidJSON
        }

        guard let id = manifest.id,
              let speciesStr = manifest.species,
              let rendererStr = manifest.renderer,
              let states = manifest.states else {
            throw PetPackError.invalidSchema
        }

        var stateDescriptors: [StateKey: StateDescriptor] = [:]
        for (key, val) in states {
            stateDescriptors[StateKey(rawValue: key)] = StateDescriptor(
                frames: val.frames,
                fps: val.fps,
                loop: val.loop ?? true
            )
        }

        var sounds: [String: URL] = [:]
        if let soundsDict = manifest.sounds {
            for (key, relPath) in soundsDict {
                sounds[key] = packURL.appendingPathComponent(relPath)
            }
        }

        return LoadedPetPack(
            id: id,
            species: Species(rawValue: speciesStr) ?? .custom(speciesStr),
            displayName: manifest.displayName ?? id,
            renderer: RendererKind(rawValue: rendererStr) ?? .spritesheet,
            states: stateDescriptors,
            sounds: sounds,
            packURL: packURL
        )
    }
}

struct ManifestJSON: Codable {
    let id: String?
    let species: String?
    let displayName: String?
    let renderer: String?
    let states: [String: StateJSON]?
    let sounds: [String: String]?
}

struct StateJSON: Codable {
    let frames: [Int]
    let fps: Int
    let loop: Bool?
}

extension Species {
    fileprivate init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "puppy": self = .puppy
        case "cat": self = .cat
        case "rabbit": self = .rabbit
        default: self = .custom(rawValue)
        }
    }
}

public struct LoadedPetPack {
    public let id: String
    public let species: Species
    public let displayName: String
    public let renderer: RendererKind
    public let states: [StateKey: StateDescriptor]
    public let sounds: [String: URL]
    public let packURL: URL
}

public struct PetPackBlueprint: PetBlueprint {
    private let loaded: LoadedPetPack
    public init(loaded: LoadedPetPack) { self.loaded = loaded }
    public var id: String { loaded.id }
    public var species: Species { loaded.species }
    public var displayName: String { loaded.displayName }
    public var renderer: RendererKind { loaded.renderer }
    public var states: [StateKey: StateDescriptor] { loaded.states }
    public var sounds: [String: URL] { loaded.sounds }
}
