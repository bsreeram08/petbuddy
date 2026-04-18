# PetPack Specification v1

## Overview

A `.petpack` is a directory bundle that contains everything PetBuddy needs to render and animate a single pet: sprite sheets or vector files, sound effects, and a JSON manifest. Drop it into the app's `Pets/` directory and it loads — no rebuild required.

## Directory structure

```
YourPet.petpack/
├── manifest.json        # Required — pet metadata and animation definition
├── preview.png         # Recommended — 2×2 grid preview for the pet picker UI
└── assets/             # Required subdir — all art lives here
    ├── sheet.png       # Required for spritesheet renderer
    ├── frames.json     # Required for spritesheet renderer
    ├── *.riv           # Required for rive renderer
    └── *.json          # Required for lottie renderer (one file per state)
sounds/                 # Optional
├── bark.wav
└── whine.wav
```

## manifest.json schema

```jsonc
{
  "schemaVersion": 1,        // integer, must be 1 for this spec

  // Identity
  "id": "com.yoursite.puppy.rover",   // reverse-DNS, unique globally
  "species": "puppy",        // "puppy" | "cat" | "rabbit" | "axolotl" | "custom:<string>"
  "displayName": "Rover",    // shown in UI
  "author": "Your Name",
  "license": "CC-BY-4.0",    // SPDX expression

  // Renderer selection
  "renderer": "spritesheet",  // "spritesheet" | "lottie" | "rive"

  // Animation states
  "states": {
    "idle": {
      "frames": [0, 1, 2, 3],   // frame indices into the sheet (spritesheet)
      "fps": 6,                 // playback rate
      "loop": true              // loop or play-once
    },
    "walk": {
      "frames": [4, 5, 6, 7],
      "fps": 12,
      "loop": true
    },
    // ...any number of named states
  },

  // Sounds (optional, relative paths from pack root)
  "sounds": {
    "bark":  "sounds/bark.wav",
    "whine": "sounds/whine.wav"
  },

  // Personality (used by BehaviorEngine)
  "personality": {
    "baseState":    "idle",
    "walkSpeed":    80,          // pixels per second
    "reactRange":   400,         // pixels — distance at which pet reacts to events
    "friendlinessToStrangers": 0.7   // 0.0–1.0
  }
}
```

## Renderer-specific notes

### spritesheet

Requires `assets/sheet.png` (single image) and `assets/frames.json`.

`frames.json`:
```json
{
  "frameWidth": 32,
  "frameHeight": 32,
  "columns": 4,
  "rows": 4
}
```

Frames are numbered left-to-right, top-to-bottom, starting at 0.

### lottie

Requires one `.json` file per state in `assets/`. Path is relative to `assets/`.

### rive

Requires a single `.riv` file in `assets/`. State transitions use Rive's state machine `fit` and `align` inputs.

## Validation

Run locally before submitting:

```bash
swift run petpack-validate Pets/YourPet.petpack
```

This validates:
- `manifest.json` conforms to `petpack-schema.v1.json`
- Required asset files exist
- All referenced frame indices are within the sheet bounds
- Frame size × grid dimensions match the PNG dimensions
