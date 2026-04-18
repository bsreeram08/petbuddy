import XCTest
@testable import PetPack

final class PetPackTests: XCTestCase {
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadValidManifest() throws {
        let manifest = """
        {
          "id": "com.test.puppy",
          "species": "puppy",
          "displayName": "TestPup",
          "renderer": "spritesheet",
          "states": {
            "idle": { "frames": [0,1,2,3], "fps": 6, "loop": true },
            "walk": { "frames": [4,5,6,7], "fps": 12, "loop": true }
          }
        }
        """
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)

        let loader = ManifestLoader()
        let pack = try loader.load(from: tempDir)

        XCTAssertEqual(pack.id, "com.test.puppy")
        XCTAssertEqual(pack.displayName, "TestPup")
        XCTAssertEqual(pack.renderer, .spritesheet)
        XCTAssertEqual(pack.states[.idle]?.fps, 6)
        XCTAssertEqual(pack.states[.walk]?.frames, [4,5,6,7])
    }

    func testMissingManifestThrows() {
        let loader = ManifestLoader()
        XCTAssertThrowsError(try loader.load(from: tempDir)) { error in
            XCTAssertEqual(error as? PetPackError, .fileNotFound)
        }
    }

    func testInvalidJSONThrows() throws {
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try "not json {{{".write(to: manifestURL, atomically: true, encoding: .utf8)
        let loader = ManifestLoader()
        XCTAssertThrowsError(try loader.load(from: tempDir)) { error in
            XCTAssertEqual(error as? PetPackError, .invalidJSON)
        }
    }

    func testMissingRequiredFieldThrows() throws {
        let manifest = """{ "id": "com.test.puppy", "species": "puppy" }"""
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        let loader = ManifestLoader()
        XCTAssertThrowsError(try loader.load(from: tempDir)) { error in
            XCTAssertEqual(error as? PetPackError, .invalidSchema)
        }
    }
}
