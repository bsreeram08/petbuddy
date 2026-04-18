# PetBuddy — Project Plan

Companion to: [DESIGN.md](DESIGN.md)
Assumed team: 1–2 engineers + 1 artist (part-time)
MVP target: ~10 weeks

---

## 1. MVP scope

Ships when all eight of these work end-to-end:

- [ ] Launch app → puppy appears, wandering idly
- [ ] Click pet → animation + thought bubble + sound
- [ ] Drag a toy → pet walks to it, plays happy
- [ ] Slack bot configured → pet reacts to bot messages
- [ ] Telegram bot configured → pet reacts to bot messages
- [ ] Generate P2P invite → paste on another Mac → direct connection
- [ ] Send toy over P2P → friend's pet walks to that screen region
- [ ] Quit and relaunch → pet returns with same identity

**Out of scope (enforced to prevent creep):** multiple pets, Lottie/Rive, second species, CloudKit, JS scripting, third-party plugins, iOS, auto-update.

---

## 2. Phase overview

| Phase | Version | Focus | Duration |
|-------|---------|-------|----------|
| 1 | v0.1 MVP | Foundation + one pet + bots + P2P | ~10 weeks |
| 2 | v0.2 | Signaling relay, persistent friendships, cat | ~8 weeks |
| 3 | v0.3 | Lottie renderer, semantic positioning, DND | ~6 weeks |
| 4 | v0.4 | Rive renderer, CloudKit sync, iOS companion | ~10 weeks |
| 5 | v0.5 | JS behavior scripting, pet pack installer | ~8 weeks |

This plan covers Phase 1 only.

---

## 3. Week-by-week

If the DoD for a week isn't met, do not start the next week. Later weeks depend on earlier foundations.

### Week 1 — Project skeleton

**Spike A runs this week** (half a day). Everything else below.

- SPM project structure matching DESIGN.md §10
- `PetCore` package: `PetEvent`, `IncomingMessage`, `LogicalPosition`, `ScreenRegion` defined and tested
- `EventBus` as `AsyncStream` multiplexer — all adapters and the pet subscribe here
- `Package.swift` with all planned packages listed (not all implemented yet)
- GitHub Actions CI: `swift test` on all packages
- MIT license, this plan, contributing guide

**Spike A — WebRTC copy-paste viability** (do this first):
```
- Create RTCPeerConnection, gather ICE candidates
- Measure: does a complete round finish in <5s on a typical home network?
- Encode offer as PETBUDDY-v1:... code — is it <5 KB?
- Open a data channel between two local processes
- Report: pass or fail
```
If fail → delay Phase 1 P2P track, build a tiny signaling relay instead.

**DoD:** `swift test` passes. CI green. Spike A pass/fail logged. Repo is private.

### Week 2 — Overlay window + menu bar

**Spike B runs this week** (half a day).

- NSPanel subclass: `.nonactivatingPanel`, `.borderless`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`, transparent
- Full-screen panel with `NSView.hitTest` returning `nil` everywhere except the pet sprite
- NSStatusItem with paw icon: menu with pet status, open Settings, pause, quit
- Settings window shell: General / Integrations / Friends / About tabs (empty)
- Boot-on-login toggle (General tab)
- Do a dummy notarization to catch issues early

**Spike B — NSPanel click-through**: Build a throwaway app with one colored rectangle on a transparent full-screen panel. Verify: desktop clicks pass through; only the rectangle catches clicks.

**DoD:** App lives in menu bar. Transparent overlay panel present. Desktop clicks reach the desktop. Settings opens. Spike B result logged.

### Week 3 — Sprite-sheet renderer

- `AnimationRenderer` protocol finalized
- `SpriteSheetRenderer`: CADisplayLink-driven frame stepping over NSImageView
- PetPack loader: load `.petpack`, validate manifest against `petpack-schema.v1.json`
- Load `Pets/Goldie.petpack/` — confirm all 16 frames render
- Pet draggable within overlay panel
- State machine: idle ↔ walk

**DoD:** Puppy on screen. Idle animation playing. Clicking starts a walk. Drag repositions the pet.

### Week 4 — Behaviors + toys

- Toy tray HUD (show/hide with hotkey, default ⌘⇧T)
- Pet pathfinding: lerp toward target, face direction of movement
- `BehaviorEngine`: event dispatch table keyed by `(currentState, event) → newState`
- Trigger "happy" when pet reaches a toy
- Idle wandering: random walks every 30–90 seconds
- Sound effects: bark on click, happy sound on toy pickup
- Thought bubble: appears above pet with sender name on `incomingMessage`

**DoD:** Pet wanders on its own. Drag a toy → pet walks to it → plays happy. Click → bark + thought bubble.

### Week 5 — Slack bot

- `IntegrationAdapter` protocol finalized
- `SlackBotAdapter`: Socket Mode WebSocket, token from Keychain
- `integrations/slack/manifest.yaml` committed
- Settings → Integrations → Slack: token fields, Connect button, status light
- Parse `message.im`, `message.channels`, `app_mention` → emit `PetEvent.incomingMessage`

**Spike C — Socket Mode reconnection**: Force-disconnect the WebSocket. Verify the adapter reconnects automatically within 5s and resumes receiving events.

**DoD:** Paste tokens → Connect → green light. Message the bot from Slack → pet shows a thought bubble. Spike C pass/fail logged.

### Week 6 — Telegram bot

- `TelegramBotAdapter`: long-polling loop, offset tracking, Keychain token
- Settings → Integrations → Telegram card (mirrors Slack UX)
- Pet reacts to messages to the bot
- README: @BotFather setup instructions

**DoD:** Create a Telegram bot → paste token → Connect → green light. Message the bot → pet reacts. Same quality as Slack.

### Week 7 — Identity + P2P transport foundation

- Ed25519 keypair generated on first launch via `CryptoKit.Curve25519.Signing.PrivateKey` → stored in Keychain under `com.petbuddy.identity`
- Identity package: expose `pubkey`, `sign(data:)`, `deriveSharedSecret(peer:)` APIs
- Integrate `stasel/WebRTC`
- `P2PTransport`: RTCPeerConnection, data channel, offer/answer
- Invite codec: JSON → zstd → base64url → `PETBUDDY-v1:...`
- Unit tests: roundtrip encode/decode, malformed input rejection
- STUN: `stun.l.google.com:19302`. No TURN.

**DoD:** Two processes exchange invite codes. Data channel opens. Logs confirm ICE candidates gathered and connection established.

### Week 8 — P2P pairing UI + peer messages

- Settings → Friends: "Invite a Friend" generates + displays code with copy button
- "Add from Invite": paste field, parses and validates `PETBUDDY-v1:...`
- X25519 + HKDF → shared session key stored in Keychain
- ChaChaPoly sealed boxes over all data channel messages
- Ping/pong keepalive every 30s
- Remote toy → pet walks to `LogicalPosition.region`
- Remote nudge → thought bubble with peer's message

**DoD:** Complete the paste dance with a friend. Send a toy → their pet walks to `.botRight`. Packet inspection confirms ciphertext.

### Week 9 — Polish

- Settings: icons, error states, copy throughout
- Loading states: spinner while connecting, error banners with retry
- Disconnect: friend offline → pet shows sad thought bubble + retry logic
- 8-hour soak test: app running with Slack + Telegram + P2P traffic
- Homebrew cask scaffold
- CONTRIBUTING.md, PETPACK_SPEC.md, code of conduct
- First notarization run (real, not dummy this time)

**DoD:** Notarized .dmg. Soak test passes. No P0 bugs known.

### Week 10 — Beta release

- Tag `v0.1.0-beta`
- GitHub release with .dmg + installation instructions
- README with screenshots/GIFs
- Share with ~10 friendly beta testers
- Triage 48 hours of feedback
- Tag `v0.1.0` after critical fixes

**DoD:** A non-technical person on a fresh Mac installs from the README alone, sets up a Telegram bot, and gets their pet to react — without asking for help.

---

## 4. Risks + spikes

| Risk | Mitigation | Phase |
|------|-----------|-------|
| WebRTC copy-paste codes too large or too slow | Spike A in Week 1 | Week 1 |
| NSPanel click-through doesn't work | Spike B in Week 2 | Week 2 |
| Slack Socket Mode drops and doesn't reconnect | Spike C in Week 5 | Week 5 |
| Notarization surprises | Dummy run in Week 1, real in Week 9 | W1 + W9 |
| Pet art quality | Source original art in Week 3, not Week 10 | Week 3 |
| macOS version churn | Test on 13, 14, 15 in Week 9 | Week 9 |

---

## 5. Post-MVP roadmap (Phase 2+)

| Weeks | Focus |
|-------|-------|
| 11–14 | Signaling relay server (Hummingbird/Fly.io, ~150 LOC). Friendships persist across restarts. Offline queue with TTL. Still E2E; relay never sees payloads. |
| 15–18 | Second species (cat). Treats distinct from toys. Close friends vs. friends. |
| 19–24 | LottieRenderer. Semantic positioning (`.nearDock`, `.awayFromFocusedWindow`) via Accessibility API. |
| 25+ | RiveRenderer. CloudKit identity sync. iOS companion (read-only pet viewer). |

---

## 6. Decision log

- _2026-04-18_ — MVP: Telegram bot + Slack bot + P2P copy-paste, SpriteSheetRenderer only. Lottie/Rive deferred to Phase 2/3.
- _2026-04-18_ — Bot-only integrations. No user-client access (TDLib, Slack user tokens).
- _2026-04-18_ — MIT open source, Developer ID + Homebrew. Mac App Store not pursued.
