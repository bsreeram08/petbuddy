import AppKit
import Combine
import Foundation
import SwiftUI

final class PetBuddyRuntime: ObservableObject {
    enum State: String, CaseIterable {
        case idle = "idle"
        case walk = "walk"
        case happy = "happy"
        case sleep = "sleep"
        case alert = "alert"
    }

    enum ThoughtStyle {
        case normal
        case happy
        case alert

        var bubbleColor: Color {
            switch self {
            case .normal: return .white
            case .happy: return Color(red: 0.93, green: 1.0, blue: 0.93)
            case .alert: return Color(red: 1.0, green: 0.96, blue: 0.9)
            }
        }
    }

    struct PetStateDescriptor {
        let frames: [Int]
        let fps: Int
        let loop: Bool
    }

    struct LoadedPetPack {
        let displayName: String
        let frameSize: CGSize
        let states: [State: PetStateDescriptor]
        let manifestURL: URL
        let packURL: URL
    }

    private struct Manifest: Decodable {
        let id: String?
        let displayName: String?
        let renderer: String?
        let states: [String: StateDefinition]?
    }

    private struct StateDefinition: Decodable {
        let frames: [Int]
        let fps: Int
        let loop: Bool?
    }

    private struct FramesMeta: Decodable {
        let frameWidth: Int
        let frameHeight: Int
    }

    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var state: State = .idle
    @Published private(set) var currentThoughtText: String? = nil
    @Published private(set) var thoughtStyle: ThoughtStyle = .normal
    @Published private(set) var isDND: Bool = false
    @Published private(set) var events: [String] = ["App launched"]
    @Published var petPosition: CGPoint = CGPoint(x: 120, y: 120)
    @Published var petImage: NSImage?
    @Published var isAnimating = true

    private(set) var pack: LoadedPetPack?
    private let sheetImage: NSImage
    private let arenaFrame = CGSize(width: 420, height: 260)

    private var stateFrames: [Int] = [0, 1, 2, 3]
    private var currentFPS: Int = 6
    private var loopFrames: Bool = true
    private var frameIndex: Int = 0

    private var frameTimer: Timer?
    private var walkTimer: Timer?
    private var stateTimer: Timer?
    private var misbehaviorTimer: Timer?

    private let walkSpeed: CGFloat = 120.0 // points/sec

    init() {
        do {
            let resolved = try Self.resolvePack()
            let loadedPack = try Self.loadPack(from: resolved)
            pack = loadedPack
            let sheetURL = resolved.appendingPathComponent("assets/sheet.png")
            let sheetData: Data
            do {
                sheetData = try Data(contentsOf: sheetURL)
            } catch {
                throw RuntimeError.invalidAsset(file: "sheet.png", path: sheetURL.path, underlying: error)
            }

            guard let sheet = NSImage(data: sheetData) else {
                throw RuntimeError.invalidImage(file: "sheet.png", path: sheetURL.path)
            }
            sheetImage = sheet

            configureStateTransition(to: .idle)
            petImage = frameImage(for: stateFrames.first ?? 0)
            petPosition = CGPoint(x: arenaFrame.width * 0.5, y: arenaFrame.height * 0.75)
            isReady = true
            startAnimationTimer()
            startMisbehaviorLoop()
            log("Loaded pack: \(loadedPack.displayName)")
        } catch {
            lastError = error.localizedDescription
            isReady = false
            sheetImage = NSImage()
            log("Failed to load pet pack: \(error)")
        }
    }

    deinit {
        stopAllTimers()
    }

    func setArenaSize(_ size: CGSize) {
        petPosition = CGPoint(x: min(max(petPosition.x, 0), max(0, size.width - 32)), y: min(max(petPosition.y, 0), max(0, size.height - 32)))
    }

    func clickPet() {
        guard !isDND else {
            log("Ignored click while DND is on")
            return
        }
        let reactions = ["*happy bark!", "*wiggle tail*", "*kisses*", "*wiggle wiggle*"]
        state = .happy
        thoughtStyle = .happy
        currentThoughtText = reactions.randomElement()
        configureStateTransition(to: .happy)
        scheduleStateReset(after: 2.0, to: .idle)
        petImage = frameImage(for: stateFrames[frameIndex])
        log("User clicked the pet")
    }

    func receiveMessage(from sender: String, text: String, platform: String) {
        guard !isDND else {
            log("Ignored message while DND is on")
            return
        }
        state = .alert
        thoughtStyle = .alert
        let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = preview.isEmpty ? "hello" : String(preview.prefix(80))
        currentThoughtText = "\(platform.capitalized) from \(sender): \(clipped)"
        configureStateTransition(to: .alert)
        scheduleStateReset(after: 3.0, to: .idle)
        petImage = frameImage(for: stateFrames[frameIndex])
        log("Incoming message from \(sender) via \(platform)")
    }

    func placeToy(at point: CGPoint, in area: CGSize) {
        guard !isDND else {
            log("Ignored toy drop while DND is on")
            return
        }
        let target = CGPoint(
            x: min(max(point.x, 20), max(20, area.width - 20)),
            y: min(max(point.y, 20), max(20, area.height - 20))
        )

        state = .walk
        thoughtStyle = .normal
        currentThoughtText = nil
        configureStateTransition(to: .walk)
        walk(to: target)
        log("Toy dropped at x:\(Int(target.x)), y:\(Int(target.y))")
    }

    func toggleDND() {
        isDND.toggle()
        if isDND {
            state = .sleep
            thoughtStyle = .normal
            currentThoughtText = nil
            stopWalk()
            configureStateTransition(to: .sleep)
            log("DND enabled")
        } else {
            state = .idle
            configureStateTransition(to: .idle)
            scheduleStateReset(after: 0.1, to: .idle)
            log("DND disabled")
        }
        petImage = frameImage(for: stateFrames[frameIndex])
    }

    func reset() {
        stopWalk()
        isDND = false
        state = .idle
        currentThoughtText = nil
        configureStateTransition(to: .idle)
        if pack != nil {
            petPosition = CGPoint(x: arenaFrame.width * 0.5, y: arenaFrame.height * 0.7)
        }
        petImage = frameImage(for: stateFrames[frameIndex])
        events.removeAll(keepingCapacity: true)
        events.append("Reset")
        if events.count > 12 { events.removeFirst(events.count - 12) }
        scheduleStateReset(after: 0.1, to: .idle)
    }

    var currentFrameSize: CGSize {
        if let cfg = pack?.frameSize {
            return cfg
        }
        return CGSize(width: 32, height: 32)
    }

    private func configureStateTransition(to newState: State) {
        state = newState
        stateTimer?.invalidate()
        let descriptor = pack?.states[newState] ?? Self.fallbackDescriptors[newState]!
        stateFrames = descriptor.frames
        currentFPS = max(descriptor.fps, 1)
        loopFrames = descriptor.loop
        frameIndex = 0

        if isAnimating {
            startAnimationTimer()
        } else {
            frameTimer?.invalidate()
        }
    }

    private func startAnimationTimer() {
        frameTimer?.invalidate()
        guard isAnimating, !stateFrames.isEmpty else { return }

        let interval = 1.0 / Double(currentFPS)
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tickAnimation()
        }
    }

    private func tickAnimation() {
        guard !stateFrames.isEmpty else { return }
        frameIndex += 1
        if frameIndex >= stateFrames.count {
            if loopFrames {
                frameIndex = 0
            } else {
                frameIndex = stateFrames.count - 1
                frameTimer?.invalidate()
            }
        }
        petImage = frameImage(for: stateFrames[frameIndex])
    }

    private func walk(to target: CGPoint) {
        stopWalk()
        let stepInterval = 1.0 / 60.0

        walkTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            guard let self else { return }

            let dx = target.x - self.petPosition.x
            let dy = target.y - self.petPosition.y
            let distance = hypot(dx, dy)
            if distance < 1.5 {
                self.petPosition = target
                self.stopWalk()
                self.state = .happy
                self.thoughtStyle = .happy
                self.currentThoughtText = "found it!"
                self.configureStateTransition(to: .happy)
                self.scheduleStateReset(after: 2.0, to: .idle)
                self.petImage = self.frameImage(for: self.stateFrames[self.frameIndex])
                self.log("Arrived at toy")
                return
            }

            let step = self.walkSpeed * CGFloat(stepInterval)
            let ratio = min(step / distance, 1)
            self.petPosition = CGPoint(x: self.petPosition.x + dx * ratio, y: self.petPosition.y + dy * ratio)
            self.configureStateTransition(to: .walk)
        }
    }

    private func stopWalk() {
        walkTimer?.invalidate()
        walkTimer = nil
    }

    private func scheduleStateReset(after seconds: TimeInterval, to nextState: State) {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.isDND {
                self.configureStateTransition(to: .sleep)
            } else {
                self.currentThoughtText = nil
                self.configureStateTransition(to: nextState)
            }
            self.petImage = self.frameImage(for: self.stateFrames[self.frameIndex])
        }
    }

    private func startMisbehaviorLoop() {
        misbehaviorTimer?.invalidate()
        misbehaviorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, !self.isDND, self.state == .idle else { return }
            self.triggerMisbehavior()
        }
    }

    private func triggerMisbehavior() {
        let roll = Int.random(in: 0...100)
        let reaction: String
        switch roll {
        case 0..<20:
            reaction = "..."
        case 20..<45:
            reaction = "*bumped the desk*"
        case 45..<75:
            reaction = "*chomp chomp*"
        default:
            reaction = "*peeks from behind!"
        }

        if reaction == "..." {
            currentThoughtText = "..."
        } else {
            currentThoughtText = reaction
        }
        thoughtStyle = .normal
        configureStateTransition(to: .idle)
        petImage = frameImage(for: stateFrames[frameIndex])
        log("Misbehavior: \(reaction)")
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentThoughtText = nil
        }
    }

    private func stopAllTimers() {
        frameTimer?.invalidate()
        walkTimer?.invalidate()
        stateTimer?.invalidate()
        misbehaviorTimer?.invalidate()
        frameTimer = nil
        walkTimer = nil
        stateTimer = nil
        misbehaviorTimer = nil
    }

    private func log(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        events.insert("[\(time)] \(message)", at: 0)
        if events.count > 12 {
            events.removeLast()
        }
    }

    private func frameImage(for globalIndex: Int) -> NSImage? {
        guard let cgImage = sheetImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let frameWidth = Int(currentFrameSize.width)
        let frameHeight = Int(currentFrameSize.height)
        guard frameWidth > 0, frameHeight > 0 else { return nil }

        let columns = Int(cgImage.width) / frameWidth
        guard columns > 0 else { return nil }

        let row = globalIndex / columns
        let col = globalIndex % columns
        let x = CGFloat(col * frameWidth)
        let y = CGFloat(Int(cgImage.height) - (row + 1) * frameHeight)

        guard y >= 0 else { return nil }
        let rect = CGRect(x: x, y: y, width: CGFloat(frameWidth), height: CGFloat(frameHeight))
        guard let frame = cgImage.cropping(to: rect) else { return nil }
        return NSImage(cgImage: frame, size: NSSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight)))
    }

    private static func resolvePack() throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)

        let roots: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.deletingLastPathComponent(),
            sourceURL.deletingLastPathComponent(),
            sourceURL.deletingLastPathComponent().deletingLastPathComponent(),
            sourceURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
            sourceURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        ].compactMap { $0 }

        let relativeCandidates = [
            "Goldie.petpack",
            "Pets/Goldie.petpack",
            "../Pets/Goldie.petpack",
            "../petbuddy/Pets/Goldie.petpack",
            "petbuddy/Pets/Goldie.petpack",
            "../../Pets/Goldie.petpack",
            "../../../Pets/Goldie.petpack"
        ]

        var checked: [String] = []
        for root in roots {
            for candidatePath in relativeCandidates {
                let candidate = root.appendingPathComponent(candidatePath).standardized
                checked.append(candidate.path)

                if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("manifest.json").path) {
                    return candidate
                }
            }
        }

        // final fallback: walk up from source file location (useful for command-line/test invocation)
        var current = sourceURL.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = current.appendingPathComponent("Pets/Goldie.petpack").standardized
            checked.append(candidate.path)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("manifest.json").path) {
                return candidate
            }
            current = current.deletingLastPathComponent()
        }

        throw RuntimeError.missingAsset("Goldie.petpack", searched: checked)
    }

    private static func loadPack(from url: URL) throws -> LoadedPetPack {
        let manifestURL = url.appendingPathComponent("manifest.json")
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw RuntimeError.invalidAsset(file: "manifest.json", path: manifestURL.path, underlying: error)
        }

        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard let rawStates = manifest.states else {
            throw RuntimeError.invalidManifest("Missing states")
        }

        let frameMetaURL = url.appendingPathComponent("assets/frames.json")
        let metaData: Data
        do {
            metaData = try Data(contentsOf: frameMetaURL)
        } catch {
            throw RuntimeError.invalidAsset(file: "frames.json", path: frameMetaURL.path, underlying: error)
        }

        let meta = try JSONDecoder().decode(FramesMeta.self, from: metaData)

        var decodedStates: [State: PetStateDescriptor] = [:]
        for (rawState, definition) in rawStates {
            if let state = State(rawValue: rawState) {
                decodedStates[state] = PetStateDescriptor(
                    frames: definition.frames,
                    fps: definition.fps,
                    loop: definition.loop ?? true
                )
            }
        }

        guard !decodedStates.isEmpty else {
            throw RuntimeError.invalidManifest("No valid states")
        }

        return LoadedPetPack(
            displayName: manifest.displayName ?? (manifest.id ?? "Goldie"),
            frameSize: CGSize(width: CGFloat(meta.frameWidth), height: CGFloat(meta.frameHeight)),
            states: decodedStates,
            manifestURL: manifestURL,
            packURL: url
        )
    }

    private static let fallbackDescriptors: [State: PetStateDescriptor] = [
        .idle: .init(frames: [0, 1, 2, 3], fps: 6, loop: true),
        .walk: .init(frames: [4, 5, 6, 7], fps: 12, loop: true),
        .happy: .init(frames: [8, 9, 10, 11], fps: 10, loop: false),
        .sleep: .init(frames: [12, 13], fps: 2, loop: true),
        .alert: .init(frames: [14, 15], fps: 8, loop: false),
    ]

    enum RuntimeError: LocalizedError {
        case missingAsset(String, searched: [String] = [])
        case invalidAsset(file: String, path: String, underlying: Error)
        case invalidImage(file: String, path: String)
        case invalidManifest(String)

        var errorDescription: String? {
            switch self {
            case .missingAsset(let asset, let searched):
                if searched.isEmpty {
                    return "Missing required asset: \(asset)"
                }
                let sample = checkedSamples(searched)
                return "Could not locate \(asset). Checked: \(sample)"
            case .invalidAsset(let file, let path, let underlying):
                return "Failed to load \(file) at \(path): \(underlying.localizedDescription)"
            case .invalidImage(let file, let path):
                return "Invalid image data for \(file) at \(path)"
            case .invalidManifest(let reason):
                return "Invalid pet manifest: \(reason)"
            }
        }
    }

    private static func checkedSamples(_ paths: [String], maxCount: Int = 6) -> String {
        return paths.suffix(maxCount).joined(separator: ", ")
    }
}

// MARK: - Display helpers

struct StateChip: View {
    let state: PetBuddyRuntime.State

    var body: some View {
        Text(state.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(stateColor, in: Capsule())
            .foregroundStyle(.white)
    }

    private var stateColor: Color {
        switch state {
        case .idle: return .green
        case .walk: return .blue
        case .happy: return .orange
        case .sleep: return .purple
        case .alert: return .red
        }
    }
}

// MARK: - SwiftUI + NSImage helper

private extension Image {
    init?(cgImage: CGImage) {
        self.init(decorative: cgImage, scale: 1.0)
    }
}

