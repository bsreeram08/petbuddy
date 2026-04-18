# PetBuddy — Project Plan

Companion to: DESIGN.md
Assumed team size: 1–2 engineers + 1 artist (part-time)
MVP target: ~10 weeks of focused work

---

## 1. MVP scope (v0.1)

Ships when the following all work end-to-end:

- [ ] Launch app → sprite-sheet puppy appears on screen, wandering idly
- [ ] Click the pet → it reacts (small animation + thought bubble)
- [ ] Drag a toy onto the screen → pet walks to it
- [ ] Set up a Slack bot → messages to the bot make the pet react
- [ ] Set up a Telegram bot → messages to the bot make the pet react
- [ ] Generate a P2P invite code → friend pastes it → direct connection
- [ ] Send a toy to your friend over P2P → their pet walks to that screen region
- [ ] Quit app → pet disappears; relaunch → pet returns with same identity

Explicitly out of scope for MVP (listed so the teammate doesn't scope-creep):

- Multiple simultaneous pets
- Rive or Lottie renderer (stubs only)
- Cat, rabbit, or any second species
- CloudKit identity sync
- JavaScriptCore behavior scripting
- Third-party integration plugins
- Signed pet pack installer
- iOS companion
- Auto-update

## 2. Phase overview

| Phase | Version | Focus | Duration |
|-------|---------|-------|----------|
| 1 | v0.1 (MVP) | Foundation + one pet + bots + P2P copy-paste | ~10 weeks |
| 2 | v0.2 | Signaling relay, persistent friendships, cat species | ~8 weeks |
| 3 | v0.3 | Lottie renderer, semantic positioning, DND integration | ~6 weeks |
| 4 | v0.4 | Rive renderer, CloudKit sync, iOS companion beta | ~10 weeks |
| 5 | v0.5 | JavaScriptCore behavior scripting, pet pack installer | ~8 weeks |

Phases 2+ are rough. This doc mostly concerns Phase 1.

## 3. Week-by-week (Phase 1)

Each week has a concrete Definition of Done. If the DoD isn't met, don't start the next week's work — the later weeks depend on earlier foundations.

### Week 1 — Project skeleton

- Xcode project, SPM sub-packages per DESIGN.md §11
- PetCore package with `PetEvent`, `IncomingMessage`, `LogicalPosition` defined and tested
- `EventBus` implemented as an `AsyncStream` multiplexer
- CI set up (GitHub Actions running `swift test` on all packages)
- MIT license, README stub, CONTRIBUTING stub

**DoD:** `swift test` passes on all packages. CI is green. Repo is public.

### Week 2 — Overlay window & menu bar

- NSPanel subclass with correct style mask, collection behavior, hit-testing
- Transparent full-screen panel that lets clicks through except on the pet
- Menu bar NSStatusItem with paw icon, pause/quit/settings menu
- Settings window shell (tabs: General / Integrations / Friends / About — all empty for now)
- Boot-on-login toggle (General tab)

**DoD:** App launches to menu bar. Overlay panel is present and transparent. Clicks on the desktop reach the desktop. Settings opens via menu.

### Week 3 — Sprite-sheet renderer

- `AnimationRenderer` protocol finalized
- `SpriteSheetRenderer` implementation (`CAAnimation`-based frame stepping)
- PetPack loader with JSON schema validation
- Test pet pack from Kenney.nl assets (free pixel-art puppy — or use Goldie.petpack)
- Draggable sprite inside the overlay panel
- State transitions: idle → walk → idle

**DoD:** The puppy appears on screen, plays idle, walks when clicked, returns to idle. Pet can be dragged by the user.

### Week 4 — Local toys and behaviors

- Toy drag-and-drop from a small "toy tray" HUD (show/hide with hotkey)
- Pet pathfinding: simple lerp toward target, face direction
- "Happy" state triggered when pet reaches a toy
- Idle wandering behavior (random short walks)
- Sound effects hooked up (bark on click, happy sound on toy)
- `BehaviorEngine` class gets its shape — event dispatch table per state

**DoD:** Drag a toy from the tray to a location. Pet walks to it, plays happy, picks it up. Pet occasionally wanders on its own.

### Week 5 — Slack bot integration

- `IntegrationAdapter` protocol finalized
- `SlackBotAdapter` implementing Socket Mode
- Token storage in Keychain
- Slack manifest file committed to `integrations/slack/manifest.yaml`
- Settings → Integrations → Slack card with token fields, "Connect" button, status light
- Pet reacts to `message.im` and `app_mention` events with a thought bubble showing the sender's name

**DoD:** User can paste both tokens, click Connect, see green light, send a message to the bot from Slack, and watch the pet display a thought bubble.

### Week 6 — Telegram bot integration

- `TelegramBotAdapter` with long-polling loop
- Token storage in Keychain (same pattern as Slack)
- Settings → Integrations → Telegram card
- Pet reacts to messages to the bot
- README section explaining bot creation via @BotFather

**DoD:** User creates a bot, pastes token, connects, sends message to the bot, pet reacts. Same UX quality as Slack.

### Week 7 — Identity & P2P transport foundation

- Curve25519.Signing.PrivateKey generated on first launch, stored in Keychain
- Identity package exposing pubkey + signing APIs
- Integrate stasel/WebRTC package
- `P2PTransport` class: creates RTCPeerConnection, opens data channel, performs offer/answer
- Encode/decode invite codes: JSON → zstd → base64url → `PETBUDDY-v1:...` string
- Unit tests for the codec (roundtrip + malformed input)
- Public STUN configured; no TURN yet

**DoD:** Two instances of the app (run locally with different Keychain access groups, or on two Macs) can exchange invite codes and establish a WebRTC data channel. Logs show the channel opening.

### Week 8 — P2P pairing UI and peer messages

- Settings → Friends tab with "Invite a Friend" and "Add from Invite" actions
- Invite generation sheet: shows the code, copy button, QR code
- Answer paste sheet
- After pairing, derive shared session key (X25519 + HKDF)
- `PeerMessage` codec over the data channel with ChaChaPoly sealing
- Ping/pong for keepalive
- Remote-toy and remote-nudge messages delivered to the pet

**DoD:** Two users complete the paste dance. One clicks "Send Toy" targeting `.bottomRight`. The other user's pet walks to the bottom-right of their screen. Messages are encrypted end-to-end (verified by packet inspection).

### Week 9 — Polish pass

- Settings polish (icons, copy, error states)
- Loading and error states throughout
- Handling disconnect/reconnect (friend offline → sad thought bubble, retry logic)
- Crash-free session test: leave app running for 8 hours with ambient integration traffic
- Homebrew cask scaffolding
- Notarization via GitHub Actions
- CONTRIBUTING.md, PETPACK_SPEC.md, code of conduct

**DoD:** Release candidate build is notarized, installable via Homebrew tap, passes an 8-hour soak test with Slack/Telegram/P2P traffic flowing, and has no known P0 bugs.

### Week 10 — Beta release and launch prep

- Publish v0.1.0-beta GitHub release with notarized .dmg
- README with screenshots/GIFs
- Landing page (static HTML, free host — GitHub Pages)
- Share with ~10 friendly beta testers
- Triage first 48 hours of feedback
- Tag v0.1.0 after critical fixes

**DoD:** A non-technical beta tester on a fresh Mac can install the app, create a Telegram bot, and see their pet react to a friend's message — all from the README alone, without asking for help.

## 4. Risks and spikes

Three areas are genuinely uncertain and should be spiked in the first two weeks to de-risk the rest of the plan. A spike = a quick prototype outside the main codebase that proves the hard part works.

### Spike A — WebRTC handshake over copy-paste (week 1)

Most of Phase 1 assumes copy-paste WebRTC is viable. If ICE gathering takes 30 seconds or the resulting invite codes are 20 KB, the UX story collapses. Spend half a day proving:

- A complete ICE gathering round finishes in <5 seconds on a typical home network
- Invite codes compress to <5 KB
- A data channel actually opens between two separate processes

If this spike fails, fall back to a tiny signaling relay before starting week 7.

### Spike B — NSPanel click pass-through (week 2)

Getting a full-screen overlay panel to pass clicks through everywhere except on the pet sprite is famously finicky. Prove the approach with a throwaway panel + one colored rectangle before building the real window. Reference implementations exist (see the DockDoor and Bezel projects for prior art).

### Spike C — Slack Socket Mode reconnection (week 5)

Socket Mode connections are dropped by Slack every ~4 hours. The adapter must transparently reconnect. Prove the reconnect loop works across a forced disconnect before wiring it into production code.

### Other risks

- **Notarization friction** — first notarization run always has surprises. Do a dummy notarization in week 1 to find issues early, not week 9.
- **Pet art quality** — Kenney.nl assets get us to MVP but the pet needs charm for launch. Start sourcing original art in week 3; don't wait for week 10.
- **macOS version churn** — target macOS 13+ for now; test on 14 and 15 in week 9.

## 5. Post-MVP roadmap (Phase 2+)

Captured here so the teammate knows what the architecture is bracing for:

- **Week 11–14:** signaling relay server (~150 LOC Swift Hummingbird, deployed to Fly.io). Friendships persist across restarts. Offline message queue with TTL. Still E2E encrypted; server never sees payloads.
- **Week 15–18:** second pet species (cat), forcing the factory abstraction to prove itself. Close friends vs. friends distinction. Treats (distinct from toys).
- **Week 19–24:** LottieRenderer implementation. Semantic positioning (`.nearDock`, `.awayFromFocusedWindow`) via Accessibility APIs.
- **Week 25+:** RiveRenderer, CloudKit identity sync, iOS companion (read-only pet viewer on iPhone that shows your Mac pet's status).

## 6. Getting started (for your teammate)

```bash
git clone https://github.com/<org>/petbuddy.git
cd petbuddy
open PetBuddy.xcodeproj

# Run tests from the command line
swift test

# Validate the default pet pack
swift run petpack-validate Pets/Goldie.petpack
```

**Environment requirements:**
- macOS 13 Ventura or later
- Xcode 15.2+
- Swift 5.9+
- (Optional) Homebrew for cask testing

First issue to pick up as a warm-up: set up the `PetCore` package and write tests for `EventBus`. This touches the spine of the system and is a clean way to meet the codebase.

## 7. Decision log (running)

As decisions get made during the build, append here (don't edit history):

- _2026-04-18_ — MVP defined as Telegram bot + Slack bot + P2P copy-paste, sprite-sheet renderer only. Lottie and Rive deferred to Phase 3/4.
- _2026-04-18_ — Bot-only integration model chosen over user-client access (TDLib, Slack user tokens) for privacy and simplicity.
- _2026-04-18_ — Open-source MIT, direct distribution via Developer ID + Homebrew. Mac App Store not pursued for v1.
