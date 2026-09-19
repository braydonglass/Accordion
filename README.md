# Accordion

A Mac app that plays like an accordion. Your laptop lid is the bellows, and your keyboard is the piano keys.

Open and close the lid to push air. Hold keys to play notes. Move the lid faster for louder sound, and stop moving it and the sound fades out over about three quarters of a second, the way a real reed does. Opening and closing both make air.

## Requirements

- A MacBook with a lid angle sensor. It's tested on a 14-inch MacBook Pro (M1 Pro) running macOS 26. Other Macs are untested. If the app can't find the sensor, the window says "No lid sensor found" and stays silent.
- macOS 14 or later, Apple silicon.
- Xcode Command Line Tools (`xcode-select --install`). You don't need full Xcode.

The app needs no permissions. It reads the hinge through IOKit and plays sound through Apple's built-in General MIDI accordion, so there's nothing to download.

## Build and run

```
./build.sh          # builds build/Accordion.app
open build/Accordion.app
./build.sh --install    # also copies it to ~/Applications
```

## How to play

Click the window so it has keyboard focus, then move the lid and press keys.

| Keys | Note |
|---|---|
| `A S D F G H J K L ; '` | White keys, C4 up to F5 |
| `W E T Y U O P` | Black keys |
| `Z` / `X` | Octave down / up (up to two either way) |

Notes only sound while the lid is moving, so it takes some practice to keep the air steady. The bar in the window shows how much air you're pushing, and the bellows drawing follows the real lid angle. Switching to another app stops every note.

## Tuning

The feel comes from a few constants at the top of `Sources/Bellows.swift`:

- `fullSpeed` (90): lid speed in degrees per second that gives full volume.
- `deadzone` (15): speeds below this count as still, which hides the sensor's one-degree flicker.
- `tail` (0.75): seconds for the air to die out after the lid stops.

The sensor reports whole degrees only, so the app measures speed over a tenth of a second instead of sample by sample.

## Tests

```
./test.sh
```

This checks the air math and the key layout. Sound and the lid itself need a real Mac and a person to check.

## Layout

- `Sources/Bellows.swift`: turns lid angle samples into air pressure.
- `Sources/Keys.swift`: maps typed keys to notes.
- `Sources/LidAngleSensor.swift`: reads the hinge angle.
- `Sources/Sound.swift`, `Sources/Engine.swift`: play the notes and run the 60 Hz loop.
- `Sources/AccordionView.swift`, `Sources/KeyCatcher.swift`, `Sources/AccordionApp.swift`: the window and key handling.
- `make-icon.swift`: draws the app icon.
- `docs/superpowers/`: the design spec and build plan.
