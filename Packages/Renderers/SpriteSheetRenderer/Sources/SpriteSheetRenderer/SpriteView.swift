import AppKit
import CoreGraphics
import PetCore

/// NSView that renders pet animations via Timer-driven frame stepping.
/// No CVDisplayLink, no CAAnimation — purely main-thread Timer.
/// Thread-safe by design: all state mutations on main thread.
public final class SpriteView: NSView {
    private let imageLayer = CALayer()
    private var frameTimer: Timer?

    private let frameWidth: Int
    private let frameHeight: Int
    private let states: [StateKey: StateDescriptor]
    private let packURL: URL

    private var currentState: StateKey = .idle
    private var frameSequence: [Int] = []
    private var fps: Int = 6
    private var loop: Bool = true
    private var currentFrameIndex: Int = 0
    private var isAnimating: Bool = false

    public init(
        frameWidth: Int,
        frameHeight: Int,
        states: [StateKey: StateDescriptor],
        initialState: StateKey,
        packURL: URL
    ) {
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.states = states
        self.packURL = packURL
        super.init(frame: .zero)
        wantsLayer = true
        layer = imageLayer
        imageLayer.contentsGravity = .resize
        transition(to: initialState, animated: false)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight))
    }

    public func transition(to state: StateKey, animated: Bool = true) {
        guard let desc = states[state] else { return }
        currentState = state
        frameSequence = desc.frames
        fps = desc.fps
        loop = desc.loop
        currentFrameIndex = 0
        stopAnimation()
        showFrame(at: currentFrameIndex)
        if animated { startAnimation() }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startAnimation() }
        else { stopAnimation() }
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        let interval = 1.0 / Double(fps)
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(frameTimer!, forMode: .common)
    }

    private func stopAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
        isAnimating = false
    }

    private func tick() {
        currentFrameIndex += 1
        if currentFrameIndex >= frameSequence.count {
            if loop { currentFrameIndex = 0 }
            else {
                stopAnimation()
                currentFrameIndex = frameSequence.count - 1
                return
            }
        }
        showFrame(at: currentFrameIndex)
    }

    private func showFrame(at localIndex: Int) {
        guard localIndex < frameSequence.count else { return }
        guard let cgImage = extractFrame(frameSequence[localIndex]) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = cgImage
        CATransaction.commit()
    }

    private func extractFrame(_ globalIndex: Int) -> CGImage? {
        let sheetURL = packURL.appendingPathComponent("assets/sheet.png")
        guard let sheet = NSImage(contentsOf: sheetURL),
              let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let columns = Int(cgImage.width) / frameWidth
        let row = globalIndex / columns
        let col = globalIndex % columns

        let rect = CGRect(
            x: CGFloat(col * frameWidth),
            y: CGFloat(Int(cgImage.height) - (row + 1) * frameHeight),
            width: CGFloat(frameWidth),
            height: CGFloat(frameHeight)
        )
        return cgImage.cropping(to: rect)

    }
}
