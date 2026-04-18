# PetBuddy

*A small creature that lives on your desktop and reminds you people love you.*

PetBuddy puts a pixel-rendered pet on your screen. When a friend messages your Slack bot or Telegram bot, the pet reacts. When a close friend sends you a toy over a direct encrypted peer-to-peer link, the pet walks to wherever they placed it. No accounts, no telemetry, no data collection.

**Status: Pre-alpha.** The architecture is fully designed. The Swift skeleton, the pet pack format, the animation assets, and this documentation exist. The Swift code for the app itself starts at Week 1.

## Start here

Read in this order. Takes ~45 minutes.

1. **[DESIGN.md](docs/DESIGN.md)** — architecture, protocols, data flow, why each decision was made
2. **[PROJECT_PLAN.md](docs/PROJECT_PLAN.md)** — 10-week MVP plan, week-by-week, with a Definition of Done for each week
3. **[PETPACK_SPEC.md](docs/PETPACK_SPEC.md)** — the `.petpack` format for adding new pets
4. Then drop into whichever supporting doc is relevant to what you're building first

## What this repo has

```
PetBuddy/
├── Pets/
│   └── Goldie.petpack/          ← 16-frame pixel art puppy, 5 animation states
├── Packages/
│   └── PetCore/                  ← Swift package skeleton (protocols + EventBus)
├── docs/
│   ├── DESIGN.md                ← architecture doc
│   ├── PROJECT_PLAN.md          ← 10-week build plan
│   ├── PETPACK_SPEC.md          ← pet pack format spec
│   ├── petpack-schema.v1.json   ← JSON Schema for validation
│   └── CONTRIBUTING.md
└── integrations/
    └── slack/manifest.yaml       ← Slack app manifest
```

## MVP scope (v0.1)

Three integration tracks, one pet, one renderer. Ships in ~10 weeks.

- [ ] App launches → puppy appears on screen, wandering idly
- [ ] Click the pet → thought bubble + sound
- [ ] Drag a toy onto the screen → pet walks to it, plays happy
- [ ] Slack bot → pet reacts to messages
- [ ] Telegram bot → pet reacts to messages
- [ ] P2P invite code → direct encrypted connection with a friend
- [ ] Send a toy over P2P → friend's pet walks to that screen region
- [ ] Quit and relaunch → pet returns with same identity

Explicitly out of scope for v0.1: multiple simultaneous pets, Lottie or Rive renderers, second species, CloudKit sync, JavaScriptCore scripting, third-party plugins, iOS companion, auto-update.

## Core decisions

| Decision | Chosen | Why |
|----------|--------|-----|
| Platform | macOS only, Swift native | Best OS-level feel; iOS companion in Phase 2 |
| Distribution | MIT open source, Developer ID + Homebrew | Sandbox too restrictive for overlay panel |
| Art style | Pixel art spritesheet (32×32) | Kenney assets for MVP; upgrade path to voxel or Lottie |
| Integrations | Bot-only | No user credentials; no OAuth; smaller attack surface |
| P2P | WebRTC data channels, copy-paste invite codes | Zero infra; NAT hole-punching; relay upgrade in Phase 2 |
| Identity | Ed25519 keypair in Keychain | Free pairing with future CloudKit sync |
| Renderer model | One protocol, one live implementation | Lottie/Rive are additive; no puppy code changes to add them |

## Quick start

```bash
git clone https://github.com/bsreeram08/petbuddy.git
cd petbuddy
swift test
```

**Requirements:** macOS 13+, Xcode 15.2+, Swift 5.9+

## Contributing

The one thing to internalize before a PR: **PetBuddy is ambient, not a notification center.** Every decision should reduce the attention the app demands, never increase it.

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
