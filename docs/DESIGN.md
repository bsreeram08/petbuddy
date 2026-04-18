# PetBuddy — Design Document

Status: Draft v0.1
Target: macOS 13+ (Ventura and later)
License: MIT

---

## 1. Vision

PetBuddy is ambient. It sits on your screen quietly, occasionally doing something charming, and reacts when the world reaches out. It is not a notification center. It is not a productivity tool. It does not know who you are or what you do. It just reminds you that other people exist and occasionally think of you.

The product is a **pet factory**: a runtime into which anyone can drop a new species, a new behavior, or a new messaging integration. The core team ships one high-quality pet and a small set of integrations; the ecosystem does the rest.

### Guiding principles

1. **Privacy by construction.** No telemetry. No analytics. E2E encryption. The only network traffic is what the user's integrations require.
2. **Ambient, not demanding.** Every decision should reduce attention demand, never increase it. The pet should never interrupt — it only reacts.
3. **Pluggable from day one.** Pets, behaviors, and integrations are separate modules talking through stable interfaces. Adding a cat costs one new package.
4. **Zero infrastructure in v1.** No backend servers. P2P uses copy-paste invite codes.

---

## 2. System overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         PetBuddy App                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Overlay Window (NSPanel)                        │ │
│  │         ┌─────────────┐                                      │ │
│  │         │  Pet Sprite  │  ← AnimationRenderer                 │ │
│  │         └─────────────┘                                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              ▲                                    │
│                         PetEvent                                 │
│  ┌────────────────────────┴───────────────────────────────────┐ │
│  │                         EventBus                             │ │
│  └──────┬──────────┬───────────┬───────────┬──────────────────┘ │
│         │          │           │           │                       │
│    ┌────▼───┐ ┌───▼────┐ ┌───▼─────┐ ┌──▼───────────┐          │
│    │ Slack  │ │Telegram │ │  Local  │ │ P2P          │          │
│    │  Bot   │ │  Bot    │ │  Toys   │ │ Transport    │          │
│    └────────┘ └─────────┘ └─────────┘ └──────────────┘          │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Identity (Ed25519 keypair in Keychain)        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

Event-driven, single-process. Integrations emit normalized `PetEvent`s onto the `EventBus`. The `Pet` consumes events through its `BehaviorEngine` and renders via its `AnimationRenderer`. The renderer knows nothing about integrations.

---

## 3. Core abstractions

Four protocols. Everything else plugs into these.

```swift
// MARK: Pet

public protocol PetBlueprint {
    var id: String { get }
    var species: Species { get }
    var displayName: String { get }
    var renderer: RendererKind { get }   // .spritesheet | .lottie | .rive
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

// MARK: Events

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
    public let platform: Platform   // .slack, .telegram, .peerToPeer
    public let fromDisplay: String   // "Anika", "@sundar", etc.
    public let preview: String       // max 120 chars
    public let timestamp: Date
}

// MARK: Integrations

public protocol IntegrationAdapter: AnyObject, Sendable {
    static var identifier: String { get }   // "slack.bot", "telegram.bot"
    static var displayName: String { get }

    var events: AsyncStream<PetEvent> { get }
    var status: IntegrationStatus { get }

    func connect() async throws
    func disconnect() async
}

// MARK: Rendering

public protocol AnimationRenderer: AnyObject {
    associatedtype RendererView: NSView

    init(pack: PetPack) throws
    func makeView() -> RendererView
    func transition(to state: StateKey, animated: Bool)
    func trigger(_ event: String)
    var viewSize: CGSize { get }
}
```

`BehaviorEngine` is a concrete class in v1 (hardcoded Swift per species). In Phase 2 it becomes a protocol with a `JavaScriptCore` implementation for third-party scripting.

---

## 4. Pet pack format

A `.petpack` is a directory bundle. Drop it into `Pets/`, it loads.

```
YourPet.petpack/
├── manifest.json        ← schema v1 (see PETPACK_SPEC.md)
├── preview.png          ← 2×2 grid, shown in pet picker UI
├── assets/
│   ├── sheet.png        ← spritesheet renderer
│   ├── frames.json      ← frame atlas
│   └── sounds/          ← CC0 or original
│       └── *.wav
```

### Manifest (v1)

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
    "bark":  "sounds/bark.wav"
  },
  "personality": {
    "baseState":    "idle",
    "walkSpeed":    80,
    "reactRange":   400
  }
}
```

---

## 5. Renderer architecture

| Renderer | Backend | Asset | Ships in |
|----------|---------|-------|----------|
| SpriteSheetRenderer | CAAnimation + NSImageView | sheet.png + frames.json | v0.1 |
| LottieRenderer | airbnb/lottie-ios | one .json per state | Phase 2 |
| RiveRenderer | rive-app/rive-ios | single .riv file | Phase 3 |

SpriteSheetRenderer is the only live implementation in MVP. Lottie and Rive are stubbed behind the protocol — adding them costs one new package, changes nothing else.

Frame stepping: `CADisplayLink` drives a frame index counter. At each step, the correct sub-rect of `sheet.png` is extracted and set on the `NSImageView.image`.

---

## 6. Integration adapters

### 6.1 Slack — Socket Mode

1. Create a Slack app from `integrations/slack/manifest.yaml`
2. Install to workspace → copy bot token (`xoxb-...`) and app token (`xapp-...`)
3. Paste into PetBuddy → Settings → Integrations → Slack
4. Invite `@petbuddy` to any channel

Scopes: `chat:write`, `im:history`, `channels:history`, `app_mentions:read`

Events: `message.im`, `message.channels`, `app_mention`

Socket Mode reconnects automatically on disconnect (see Spike C in PROJECT_PLAN.md).

### 6.2 Telegram — Long polling

1. Message @BotFather → `/newbot` → copy token
2. Paste into PetBuddy → Settings → Integrations → Telegram

Long-polls `getUpdates` with a 30s timeout. Offset tracking prevents double-delivery.

### Why bot-only

Bot tokens are explicitly created by the user. The app never holds Telegram account credentials or Slack user OAuth tokens. The pet reacts to messages sent *to the bot* — not to the user's personal DMs. Friends opt in; the pet is a channel, not a surveillance layer.

---

## 7. P2P transport

WebRTC data channels. Zero servers. Copy-paste invite codes.

Swift package: [`stasel/WebRTC`](https://github.com/stasel/WebRTC)

### Invite code format

```
PETBUDDY-v1:<base64url(zstd(json_payload))>
```

```json
{
  "kind": "offer",
  "from": {
    "pubkey": "ed25519:...",
    "nickname": "Alice",
    "petId": "com.petbuddy.puppy.golden"
  },
  "sdp": "v=0\r\no=- ...",
  "ice": ["candidate:1 1 UDP 2122260223 ..."],
  "createdAt": 1713456789,
  "ttlSeconds": 3600
}
```

Invite codes compress to ~2–5 KB. This is the spike to verify in Week 1.

### Handshake

```
Alice                                                    Bob
  │  1. Create RTCPeerConnection, data channel           │
  │  2. Create SDP offer, gather ICE                     │
  │  3. Wait 2s (or ICE complete)                        │
  │  4. Bundle → PETBUDDY-v1:... invite code            │
  │─────────────────── share via any channel ───────────▶ │
  │                                                       │
  │                              5. Paste invite          │
  │                              6. Set remote desc       │
  │                              7. Create answer         │
  │                              8. Answer code back      │
  │◀──────────────────────── same channel ────────────────│
  │  9. Paste answer, set remote desc                     │
  │ 10. WebRTC connection established                     │
  │ 11. Data channel open                               │
  │──────────── encrypted peer messages ─────────────────▶ │
```

Known limitations: both peers must be online simultaneously. NAT traversal fails for ~20% of strict NATs. Reconnection requires a new invite. Phase 2 adds a signaling relay.

### Message protocol

All messages encrypted with ChaChaPoly using a session key derived via X25519 + HKDF from the handshake.

```swift
public enum PeerMessage: Codable, Sendable {
    case ping
    case pong
    case nudge(text: String)                 // thought bubble
    case toy(kind: ToyKind, position: LogicalPosition)
    case treat(kind: TreatKind, position: LogicalPosition)
    case petState(state: StateKey)           // show friend's pet mood
}

public enum LogicalPosition: Codable, Sendable {
    case region(ScreenRegion)     // v1: 9-cell grid
    case normalized(x: Double, y: Double)  // v2
    case anchor(SemanticAnchor)   // v3
}

public enum ScreenRegion: String, Codable, Sendable {
    case topLeft, topCenter, topRight
    case midLeft, center, midRight
    case botLeft, botCenter, botRight
}
```

---

## 8. Identity & security

- On first launch: `CryptoKit.Curve25519.Signing.PrivateKey` generated, stored in macOS Keychain under `com.petbuddy.identity`
- Public key = user's stable identifier across sessions
- Friendship session keys derived via X25519 + HKDF at handshake time, stored in Keychain keyed by peer pubkey
- All P2P payloads encrypted with ChaChaPoly before going over the wire

| Component | Stores | Sees |
|-----------|--------|------|
| PetBuddy app | All keys, all tokens | Everything |
| Slack / Telegram | Bot tokens only | Messages to the bot |
| STUN server | — | IP address pairs (STUN only) |
| Friend's PetBuddy | Our pubkey + session key | Only what we send |

No PetBuddy-operated server exists in v0.1.

---

## 9. UI surfaces

Three surfaces. Deliberately minimal.

**1. Overlay window (NSPanel)**
`.nonactivatingPanel`, `.borderless`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`. Full-screen, transparent. Hit-testing: pet sprite catches clicks; `NSView.hitTest` returns `nil` everywhere else → clicks pass through to the app behind.

**2. Menu bar (NSStatusItem)**
Paw icon. Menu: pet status, open Settings, pause/resume pet, quit.

**3. Settings window (SwiftUI)**
- General: pet picker, boot on login, sounds
- Integrations: Slack + Telegram cards with token fields, Connect button, status light
- Friends: paired peers list, Invite a Friend (generates code), Add from Invite (paste field)
- About: version, credits, repo link

---

## 10. Directory layout

```
PetBuddy/
├── Package.swift
├── PetBuddy.xcodeproj/
├── App/
│   ├── PetBuddyApp.swift
│   ├── OverlayWindow/
│   ├── Settings/
│   └── MenuBar/
├── Packages/
│   ├── PetCore/                  ← protocols, models, EventBus
│   ├── PetPack/                  ← manifest loader + schema validation
│   ├── Renderers/
│   │   ├── SpriteSheetRenderer/
│   │   ├── LottieRenderer/       (stub)
│   │   └── RiveRenderer/          (stub)
│   ├── Integrations/
│   │   ├── SlackBot/
│   │   └── TelegramBot/
│   ├── P2PTransport/             ← WebRTC + invite codec
│   └── Identity/                ← Keychain, keypairs
├── Pets/
│   └── Goldie.petpack/          ← default pet (shipped)
├── integrations/
│   └── slack/manifest.yaml
└── docs/
    ├── DESIGN.md
    ├── PROJECT_PLAN.md
    ├── PETPACK_SPEC.md
    ├── petpack-schema.v1.json
    └── CONTRIBUTING.md
```

Each package builds and tests in isolation.

---

## 11. Decision log

| # | Decision | Alternatives | Reason |
|---|----------|--------------|--------|
| 1 | SwiftUI/AppKit hybrid native | Electron, Tauri, Unity | Best macOS feel; JS plugin story in Phase 2 |
| 2 | MIT open source, Developer ID + Homebrew | Mac App Store | Sandbox too restrictive for overlay + P2P |
| 3 | Bot-only integrations | TDLib, Slack user tokens | No user credentials; simpler; smaller surface |
| 4 | Copy-paste P2P invite codes | Relay server, Nostr | Zero infra; upgrade path is clean |
| 5 | Multi-renderer via protocol | Single renderer | Lottie/Rive additive; cost is one protocol |
| 6 | Ed25519 keypair in Keychain | No identity | Free pairing with CloudKit sync later |
| 7 | WebRTC data channels | QUIC, TCP, libp2p | Best NAT hole-punching; mature Swift wrapper |
| 8 | 9-cell region grid | Pixel or normalized coords | Resolution-agnostic; simple; upgrade additive |
| 9 | SpriteSheetRenderer v1 | Kenney voxel | Pixel art is faster to ship; swap later |

---

## 12. Open questions

| Question | Current answer | Phase |
|----------|---------------|-------|
| How does P2P reconnect after restart? | Cache last ICE candidates; retry on launch; fall back to new invite | Week 7 spike |
| Overlay vs fullscreen apps? | `.fullScreenAuxiliary` covers most; games may hide it | Acceptable for v0.1 |
| Accessibility for thought bubbles? | VoiceOver should read them; add accessibility labels in Phase 3 | Phase 3 |
| Pet pauses during DND? | Respect `NSUserNotificationCenter` DND state; pet goes to sleep | Phase 3 |
| Pet pack signing? | Unsigned with warning for MVP; signed for v1.0 | Phase 1 |
