# PetBuddy — Design Document

Status: Draft v0.1
Target platform: macOS 13+ (Ventura and later)
License: MIT (planned)
Distribution: Open source, direct download with Developer ID signing

---

## 1. Vision

PetBuddy is a desktop pet that lives on your screen as a reminder that people love you. When a friend messages you, your pet reacts. When a friend sends you a toy or treat, your pet walks to wherever they placed it. It is social, ambient, and explicitly not a productivity tool, notification center, or data collector.

The product is a pet factory: a runtime into which anyone can drop a new species (puppy, cat, rabbit, axolotl), a new behavior, or a new messaging integration. The core team ships a high-quality default pet and a small set of integrations; the ecosystem does the rest.

### Guiding principles
1. Privacy by construction, not by promise. No telemetry. No analytics. Messaging payloads are end-to-end encrypted. The only network traffic is what the user's integrations require.
2. Charming over functional. Every animation, sound, and interaction should feel warm. If a design decision is between "useful" and "delightful," pick delightful.
3. Pluggable from day one. Even in the MVP, pets, behaviors, and integrations are separate modules talking through stable interfaces. Adding a cat should not require changing puppy code.
4. Zero infrastructure in v1. The MVP has no backend servers. P2P uses copy-paste invite codes.

## 2. Non-goals

- Cross-platform support in v1 (macOS only)
- iOS/iPadOS companion app in v1 (designed for, shipped later)
- Productivity features (task management, reminders, calendar)
- Group chat with more than two pets
- Monetization of any kind

## 3. System overview

```
┌───────────────────────────────────────────────────────────────┐
│                        PetBuddy App                            │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Overlay Window (NSPanel)                   │  │
│  │        ╭─────────────╮                                   │  │
│  │        │  🐶  Pet    │  ← AnimationRenderer              │  │
│  │        ╰─────────────╯                                   │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              ▲                                 │
│                              │ PetEvent                        │
│  ┌───────────────────────────┴────────────────────────────┐   │
│  │                      EventBus                           │   │
│  └────┬──────────┬──────────┬──────────┬──────────────────┘   │
│       │          │          │          │                        │
│  ┌────▼────┐ ┌──▼────┐ ┌──▼─────┐ ┌──▼──────────┐             │
│  │ Slack   │ │Telegram│ │ Local  │ │ P2P         │             │
│  │ Bot     │ │ Bot    │ │ Toys   │ │ Transport   │             │
│  └─────────┘ └────────┘ └────────┘ └─────────────┘             │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Identity (Ed25519 keypair in Keychain)           │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

Event-driven, single-process. Integrations and the P2P transport emit normalized `PetEvent`s onto the `EventBus. The Pet consumes events through its `BehaviorEngine` and renders via its `AnimationRenderer`.

## 4. Core abstractions

Four protocols define the system. Everything else plugs into these.

```swift
// MARK: - Pet

/// Blueprint loaded from a pet pack on disk.
public protocol PetBlueprint {
    var id: String { get }                  // "com.petbuddy.puppy.golden"
    var species: Species { get }            // .puppy, .cat, .rabbit, .custom(String)
    var displayName: String { get }         // "Goldie"
    var renderer: RendererKind { get }       // .rive | .lottie | .spriteSheet
    var states: [StateKey: StateDescriptor] { get }
    var sounds: [SoundKey: URL] { get }

    func makeBehaviorEngine() -> BehaviorEngine
}

@MainActor
public final class Pet: ObservableObject {
    public let blueprint: PetBlueprint
    public let renderer: any AnimationRenderer
    public let behavior: BehaviorEngine

    @Published public var position: CGPoint
    @Published public var currentState: StateKey
    @Published public var thoughtBubble: ThoughtBubble?

    public func handle(_ event: PetEvent) {
        behavior.dispatch(event, pet: self)
    }
}

// MARK: - Events

public enum PetEvent: Sendable {
    case incomingMessage(IncomingMessage)
    case toyPlaced(ToyPlacement)
    case treatReceived(Treat)
    case userClicked(CGPoint)
    case friendConnected(PeerID)
    case friendDisconnected(PeerID)
    case idleTick
}

public struct IncomingMessage: Sendable, Codable {
    public let platform: Platform              // .slack, .telegram, .peerToPeer
    public let fromDisplay: String             // "Anika", "@sundar", etc.
    public let preview: String                 // short text, max 120 chars
    public let timestamp: Date
}

// MARK: - Integrations

public protocol IntegrationAdapter: AnyObject, Sendable {
    static var identifier: String { get }      // "slack.bot", "telegram.bot"
    static var displayName: String { get }

    var events: AsyncStream<PetEvent> { get }
    var status: IntegrationStatus { get }

    func connect() async throws
    func disconnect() async
}

// MARK: - Rendering

public protocol AnimationRenderer: AnyObject {
    associatedtype RendererView: NSView

    init(pack: PetPack) throws
    func makeView() -> RendererView
    func transition(to state: StateKey, animated: Bool)
    func trigger(_ event: String)
    var viewSize: CGSize { get }
}
```

Note: `BehaviorEngine` is a concrete class in v1 (hardcoded Swift behaviors per species). In v2 it becomes a protocol with a `JavaScriptCoreBehaviorEngine` implementation for third-party scripting. Designing it as a class today, extractable to a protocol later, is cheap.

## 5. Pet pack format

A pet pack is a directory ending in `.petpack`. It contains a `manifest.json` and asset files. The manifest declares which renderer to use; the renderer loads its native assets.

```
Goldie.petpack/
├── manifest.json
├── assets/
│   ├── goldie.riv              (if renderer = rive)
│   ├── idle.json               (if renderer = lottie)
│   ├── sheet.png               (if renderer = spritesheet)
│   └── frames.json
├── sounds/
│   ├── bark.wav
│   └── whine.wav
└── preview.png                 (for UI picker)
```

### Manifest schema (v1)

```json
{
  "schemaVersion": 1,
  "id": "com.petbuddy.puppy.golden",
  "species": "puppy",
  "displayName": "Goldie",
  "author": "Anthropic Open Source",
  "license": "CC-BY-4.0",
  "renderer": "spritesheet",

  "states": {
    "idle":  { "frames": [0,1,2,3],    "fps": 6,  "loop": true  },
    "walk":  { "frames": [4,5,6,7],    "fps": 12, "loop": true  },
    "happy": { "frames": [8,9,10,11],  "fps": 10, "loop": false },
    "sleep": { "frames": [12,13],      "fps": 2,  "loop": true  },
    "alert": { "frames": [14,15],      "fps": 8,  "loop": false }
  },

  "sounds": {
    "bark":  "sounds/bark.wav",
    "whine": "sounds/whine.wav"
  },

  "personality": {
    "baseState":   "idle",
    "walkSpeed":   80,
    "reactRange":  400,
    "friendlinessToStrangers": 0.7
  }
}
```

Renderer-specific fields live under states but vary by renderer:

- `"renderer": "rive"` — states maps state name → `{ "input": "state", "value": "idle" }` (Rive state machine inputs)
- `"renderer": "lottie"` — states maps state name → `{ "file": "idle.json", "loop": true, "speed": 1.0 }`
- `"renderer": "spritesheet"` — as shown above

A JSON Schema file will be published alongside the code (`petpack-schema.v1.json`) so contributors can validate packs locally.

## 6. Animation renderer architecture

Three concrete renderers ship, all conforming to `AnimationRenderer`:

| Renderer | Backend | Pet pack asset | Best for |
|----------|---------|----------------|----------|
| SpriteSheetRenderer | CAAnimation over NSImageView | sheet.png + frame ranges | Pixel-art pets, low contributor barrier |
| LottieRenderer | [airbnb/lottie-ios](https://github.com/airbnb/lottie-ios) | one .json per state | Vector pets from After Effects |
| RiveRenderer | [rive-app/rive-ios](https://github.com/rive-app/rive-ios) | single .riv file | Reactive pets with complex state machines |

### v1 ships with
SpriteSheetRenderer fully implemented. LottieRenderer and RiveRenderer stubbed behind the protocol but not wired (they're a ~1-week each task post-MVP). The default puppy is a sprite-sheet pet using free assets from [Kenney.nl](https://kenney.nl) as a starting point, with original art commissioned later.

### Why this split works

The renderer doesn't know about integrations or events. It has exactly one job: show the pet in the right state at the right position. State transitions come from the BehaviorEngine. This means adding Rive in v0.5 is a drop-in that zero other code depends on.

## 7. Integration adapters

### 7.1 Slack Bot Adapter

Uses Slack Socket Mode — a WebSocket from Slack's servers to the user's Mac, no inbound webhook needed.

User setup (documented in README):
1. Go to api.slack.com/apps → Create New App → From manifest
2. Paste `integrations/slack/manifest.yaml` from the PetBuddy repo
3. Install to workspace → grab bot token (`xoxb-...`) and app token (`xapp-...`)
4. Paste both into PetBuddy → Settings → Integrations → Slack
5. Invite the bot (`/invite @petbuddy`) to any channel where you want your pet to react

Manifest declares scopes:
- chat:write, im:history, channels:history, app_mentions:read

Runtime:

```swift
public final class SlackBotAdapter: IntegrationAdapter {
    public static let identifier = "slack.bot"

    private let appToken: String
    private let botToken: String
    private var socket: WebSocketTask?

    public func connect() async throws {
        let url = try await openSocketModeURL()    // apps.connections.open
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        Task { await readLoop() }
    }

    private func readLoop() async {
        // Decode envelope, ack with envelope_id, translate payload → PetEvent
    }
}
```

Subscribed events: `message.im` (DMs to bot), `message.channels` (in channels the bot is in), `app_mention`.

### 7.2 Telegram Bot Adapter

Uses Telegram Bot API long polling.

User setup:
1. Message @BotFather on Telegram → `/newbot` → get token
2. Paste token into PetBuddy → Settings → Integrations → Telegram
3. Message the bot or add it to groups where your pet should react

Runtime:

```swift
public final class TelegramBotAdapter: IntegrationAdapter {
    public static let identifier = "telegram.bot"

    private let token: String
    private var offset: Int = 0
    private var pollingTask: Task<Void, Never>?

    public func connect() async throws {
        pollingTask = Task { await pollLoop() }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            let updates = try? await getUpdates(offset: offset, timeout: 30)
            for update in updates ?? [] {
                offset = max(offset, update.updateId + 1)
                if let msg = update.message {
                    emit(.incomingMessage(IncomingMessage(
                        platform: .telegram,
                        fromDisplay: msg.from?.displayName ?? "someone",
                        preview: msg.text?.prefix(120).description ?? "",
                        timestamp: Date(timeIntervalSince1970: TimeInterval(msg.date))
                    )))
                }
            }
        }
    }
}
```

### Why bot-only (not user client)

The "bot-only" decision means: the pet reacts to messages sent to the user's bot, not to the user's personal DMs. This is a deliberate scope and privacy choice:

- Privacy: the app never holds user credentials for Telegram/Slack — only bot tokens the user explicitly created
- Simplicity: no TDLib, no Slack user-token OAuth dance, no MTProto
- Social framing: friends opt in by messaging your bot. The pet represents a *channel* your friends can reach you through, not a surveillance layer over your life
- Limitation: this won't make the pet react to your normal incoming Slack/Telegram DMs. Accepted tradeoff for v1

User-client mode (`TelegramUserClientAdapter` via TDLib) is a plausible v2 feature, gated behind a "power user" flag.

## 8. P2P transport

Pet-to-pet messaging uses WebRTC data channels with copy-paste signaling — zero servers.

Swift package: [`stasel/WebRTC`](https://github.com/stasel/WebRTC) (prebuilt WebRTC.xcframework).

### 8.1 Invite code format

An invite encodes everything needed to establish a connection:

```
PETBUDDY-v1:<base64url(zstd(json_payload))>
```

Where json_payload is:

```json
{
  "kind": "offer",
  "from": {
    "pubkey": "ed25519:a1b2c3...",
    "nickname": "Alice",
    "petId": "com.petbuddy.puppy.golden"
  },
  "sdp": "v=0\r\no=- 123 456 IN IP4 0.0.0.0\r\n...",
  "ice": [
    "candidate:1 1 UDP 2122260223 192.168.1.5 54321 typ host",
    "candidate:2 1 UDP 1686052607 203.0.113.7 54321 typ srflx ..."
  ],
  "createdAt": 1713456789,
  "ttlSeconds": 3600
}
```

The answer uses `"kind": "answer"` with the same shape. Invites typically encode to ~2–4 KB → 3–5 KB base64 → shareable as a long string. Clunky but functional.

### 8.2 Handshake flow

```
Alice                                                       Bob
  │                                                          │
  │  1. Create RTCPeerConnection, create data channel        │
  │  2. Create SDP offer, start ICE gathering               │
  │  3. Wait 2s or until ICE complete                       │
  │  4. Bundle offer + pubkey + ICE → invite code           │
  │─────────────── send via iMessage / etc ─────────────────▶│
  │                                                          │
  │                                 5. Paste invite code     │
  │                                 6. Set remote description│
  │                                 7. Create answer, ICE   │
  │                                 8. Bundle → answer code   │
  │◀────────────── send back via any channel ────────────────│
  │                                                          │
  │  9. Paste answer, set remote description                 │
  │ 10. WebRTC completes connection                          │
  │ 11. Data channel open                                    │
  │                                                          │
  │────────── encrypted app-level messages ─────────────────▶│
  │◀──────────────────── (toys, treats) ─────────────────────│
```

Known limitations of copy-paste signaling:

- Both peers must be online simultaneously for the handshake
- Reconnection after disconnect requires a new handshake (same pair)
- NAT traversal may fail without TURN; ~20–30% of connections across strict NATs will fail
- Public STUN only for now (e.g., `stun.l.google.com:19302`). No TURN in v1

These limitations are the price of zero infrastructure. v0.2 upgrade path is a tiny signaling relay that caches pubkey-addressed offers for later retrieval.

### 8.3 Message protocol

Once the data channel is open, peers exchange framed JSON messages. All messages are encrypted using Curve25519.KeyAgreement → ChaChaPoly sealed boxes with each friendship's session key.

```swift
public enum PeerMessage: Codable, Sendable {
    case ping
    case pong
    case nudge(text: String)                   // renders as thought bubble
    case toy(kind: ToyKind, position: LogicalPosition)
    case treat(kind: TreatKind, position: LogicalPosition)
    case petState(state: StateKey)              // optional: show friend's pet mood
}

public enum LogicalPosition: Codable, Sendable {
    case region(ScreenRegion)                  // v1: 9 cells
    case normalized(x: Double, y: Double)       // v2
    case anchor(SemanticAnchor)                // v3
}

public enum ScreenRegion: String, Codable, Sendable {
    case topLeft, topCenter, topRight
    case midLeft, center,    midRight
    case botLeft, botCenter, botRight
}
```

Coordinate translation is the receiver's responsibility. `LogicalPosition.resolve(on: NSScreen)` returns pixel coordinates appropriate to the local screen.

## 9. Identity & security

### Keypair
On first launch, PetBuddy generates an Ed25519 signing keypair via `CryptoKit.Curve25519.Signing.PrivateKey`. The private key is stored in the macOS Keychain under access group `com.petbuddy.identity`, accessible only by this app. The public key is the user's stable identifier across devices (once CloudKit sync lands in v2).

### Friendship keys

When two users complete a copy-paste handshake, they derive a shared symmetric key via X25519 key agreement between their Ed25519 keys (converted to Curve25519). This key is stored in the Keychain keyed by peer pubkey. All PeerMessage payloads are encrypted with this key using ChaChaPoly.seal before being written to the WebRTC data channel.

### What's trusted with what

| Component | Stores | Sees |
|-----------|--------|------|
| PetBuddy app | User's private key, friend pubkeys, friendship session keys, integration tokens | Everything (it's the user's own app) |
| Slack / Telegram | Integration bot tokens | Messages sent to the bot (by design of the API) |
| WebRTC relay/STUN | — | IP address pairs (STUN only; no content) |
| Friend's PetBuddy | Our pubkey, shared session key | Payloads we explicitly send |

No PetBuddy-operated server exists in v1.

## 10. UI surfaces

Three surfaces, kept deliberately minimal:

1. **Overlay window** — NSPanel with `.nonactivatingPanel`, `.borderless`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`, sized to the active screen. Hit-testing is opt-in per subview: the pet sprite catches clicks and drag events; everywhere else passes through to the app behind (`NSView.hitTest` returns `nil`).

2. **Menu bar item** — NSStatusItem with a paw-print icon. Menu contains: pet status, open settings, pause/resume pet, quit.

3. **Settings window** — Standard SwiftUI Settings scene. Tabs:
   - General — pet picker, boot on login, sounds on/off
   - Integrations — Slack, Telegram cards with token fields and status lights
   - Friends — list of paired peers, "Invite a Friend" (generates code), "Add from Invite" (paste field)
   - About — version, credits, link to repo

## 11. Directory layout

```
PetBuddy/
├── Package.swift                   (SPM manifest for libs)
├── PetBuddy.xcodeproj/
├── App/                            (SwiftUI app target)
│   ├── PetBuddyApp.swift
│   ├── OverlayWindow/
│   ├── Settings/
│   └── MenuBar/
├── Packages/
│   ├── PetCore/                    (protocols, models, EventBus)
│   │   ├── Sources/PetCore/
│   │   └── Tests/PetCoreTests/
│   ├── PetPack/                    (manifest loader, schema validation)
│   ├── Renderers/
│   │   ├── SpriteSheetRenderer/
│   │   ├── LottieRenderer/         (stub in v1)
│   │   └── RiveRenderer/           (stub in v1)
│   ├── Integrations/
│   │   ├── SlackBot/
│   │   └── TelegramBot/
│   ├── P2PTransport/               (WebRTC + invite codec)
│   └── Identity/                  (Keychain, keypairs)
├── Pets/
│   └── Goldie.petpack/            (default puppy — shipped with app)
├── integrations/
│   └── slack/manifest.yaml         (user-installable Slack app manifest)
├── docs/
│   ├── DESIGN.md                   (this file)
│   ├── PROJECT_PLAN.md
│   ├── CONTRIBUTING.md
│   ├── PETPACK_SPEC.md
│   └── petpack-schema.v1.json
└── README.md
```

Each package has its own tests and is buildable in isolation. This matters for the "factory" story — a pet renderer contributor should be able to open `Renderers/LottieRenderer/` and work without touching app code.

## 12. Decision log

| # | Decision | Alternatives considered | Reason |
|---|----------|-------------------------|--------|
| 1 | SwiftUI / AppKit hybrid, native Swift | Electron, Tauri, Unity | Best macOS feel, acceptable plugin story via JavaScriptCore later |
| 2 | Open-source, direct distribution | Mac App Store | Sandbox too restrictive for overlay window and P2P; contributor-friendly |
| 3 | Bot-only integrations for v1 | User-client access (TDLib, Slack user tokens) | Privacy, simplicity, smaller attack surface |
| 4 | Copy-paste P2P invite codes | Relay server, Nostr | Zero infra; upgrade path is clean |
| 5 | Multi-renderer via AnimationRenderer protocol | Single renderer (pick one) | OSS contributors have different tools; cost is one protocol |
| 6 | Ed25519 identity in Keychain | No identity in v1 | Pairs for free with later CloudKit sync + E2E encryption |
| 7 | WebRTC data channels | QUIC, raw TCP, libp2p | Best hole-punching support, mature, good Swift wrapper |
| 8 | Region-grid coordinates (9 cells) | Pixel coordinates, normalized | Resolution-agnostic, simple; upgrade path is additive |

## 13. Open questions

- How does a paired friendship persist across restarts when the only signaling is copy-paste? Likely answer: cache the last known ICE candidates on both sides and attempt direct reconnect at startup. If that fails, prompt for re-invite. Needs a spike in week 7.
- What happens when the overlay window intersects fullscreen apps? `.fullScreenAuxiliary` should cover most cases but games and video players may hide it. Acceptable for v1; document as known.
- Accessibility — screen readers on a pet? The sprite is decorative; thought bubbles should be readable via VoiceOver. Add in v0.9.
- How are pets paused during focus modes / Do Not Disturb? Respect NSUserNotificationCenter DND state; pet goes to sleep. v0.9.
- Pet pack signing — do we require signed packs for the built-in installer in v1? Leaning no for MVP (unsigned packs with a warning), yes for v1.0.

## Appendix A — How to contribute a pet

1. Fork the repo. Copy `Pets/Goldie.petpack/` to `Pets/YourPet.petpack/`.
2. Edit `manifest.json`:
   - Change `id` to a unique reverse-DNS string you control
   - Set species, displayName, author, license
   - Pick a renderer (`"spritesheet"`, `"lottie"`, or `"rive"`)
3. Replace the assets in `assets/` with your art.
4. Run `swift run petpack-validate Pets/YourPet.petpack` (ships as a CLI tool in v1).
5. Open a PR. The default puppy, cat, and rabbit live in the main repo; third-party pets should link to their own repos from PETS.md.

## Appendix B — Swift package dependencies (planned)

| Package | Purpose | License |
|---------|---------|---------|
| stasel/WebRTC | WebRTC bindings | BSD-3 |
| airbnb/lottie-ios | Lottie renderer | Apache-2 |
| rive-app/rive-ios | Rive renderer | MIT |
| apple/swift-crypto | Curve25519 / ChaChaPoly | Apache-2 |
| facile-it/zstd-swift or similar | Invite code compression | BSD |
| apple/swift-argument-parser | CLI tools | Apache-2 |

No analytics, no telemetry, no networking packages beyond the above.
