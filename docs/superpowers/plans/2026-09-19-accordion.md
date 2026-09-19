# Accordion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A window app where the MacBook lid is the bellows (lid speed = air) and the keyboard plays piano keys through Apple's built-in accordion.

**Architecture:** Two pure logic units (`Bellows`, `Keys`) with tests. A 60 Hz `Engine` reads the hinge, feeds `Bellows`, pushes pressure to `Sound` (MIDI expression on the built-in DLS accordion). SwiftUI window draws the accordion; an `NSView` catches key up/down.

**Tech Stack:** Swift 5, swiftc (Command Line Tools only, no Xcode), SwiftUI, AVFoundation (`AVAudioUnitSampler`), IOKit HID.

**Spec:** `docs/superpowers/specs/2026-09-19-accordion-design.md`

## Global Constraints

- macOS 14+, arm64, built with `swiftc -swift-version 5 -parse-as-library` (same as LidBlur).
- No Screen Recording or Input Monitoring permission. Window app, key events only while focused.
- Sound: `/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls`, GM program 21 (zero-based, Accordion). Pressure drives CC11.
- Keys: white `A S D F G H J K L ; '` (C4 to F5), black `W E T Y U O P`, `Z`/`X` octave shift limited to plus or minus 2.
- Hinge sensor reports whole degrees. Poll at 60 Hz.
- No git repo here. Do not commit unless the user asks.

## File Structure

```
~/Accordion/
  Sources/LidAngleSensor.swift   copy of ~/LidBlur/Sources/LidAngleSensor.swift
  Sources/Bellows.swift          pure: (angle, time) samples -> pressure 0...1
  Sources/Keys.swift             pure: character -> MIDI note, octave shift
  Sources/Sound.swift            AVAudioUnitSampler + built-in accordion
  Sources/Engine.swift           60 Hz loop, key handling, published UI state
  Sources/KeyCatcher.swift       NSView that turns key events into Engine calls
  Sources/AccordionView.swift    SwiftUI drawing: bellows, keys, meter, status
  Sources/AccordionApp.swift     @main, single window, app delegate
  Tests/LogicTests.swift         Bellows + Keys tests
  Info.plist, build.sh, test.sh
```

---

### Task 1: Bellows

**Files:**
- Create: `test.sh`, `Tests/LogicTests.swift`, `Sources/Bellows.swift`

**Interfaces:**
- Produces: `struct Bellows { init(); private(set) var pressure: Double; mutating func update(angle: Double, at time: Double) -> Double }` (`@discardableResult`).

Velocity is measured over a 0.1 s window (net angle change / elapsed time), not per sample. Per-sample speed reads 1-degree sensor jitter as 60 degrees per second of air. The spec said "smooth per-sample speed"; this replaces it and the spec is updated in Task 4.

- [ ] **Step 1: Write `test.sh` and the failing Bellows tests**

`test.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
OUT=$(mktemp -d)
swiftc -swift-version 5 -parse-as-library Sources/Bellows.swift Sources/Keys.swift Tests/LogicTests.swift -o "$OUT/tests"
"$OUT/tests"
```

`Tests/LogicTests.swift` (Keys tests are added in Task 2; `Keys.swift` is stubbed empty for now):

```swift
import Foundation

@main
struct LogicTests {
    static var failures = 0

    static func check(_ ok: Bool, _ name: String) {
        if ok { print("PASS \(name)") } else { print("FAIL \(name)"); failures += 1 }
    }

    /// Feeds a lid path at 60 Hz for `seconds`, rounding to whole degrees like the real sensor.
    /// `angle` gets the seconds since `start`. Returns the pressure after every sample.
    static func run(_ bellows: inout Bellows, start: Double, seconds: Double, angle: (Double) -> Double) -> [Double] {
        var out: [Double] = []
        for i in 1...Int(seconds * 60) {
            let t = Double(i) / 60
            out.append(bellows.update(angle: angle(t).rounded(), at: start + t))
        }
        return out
    }

    static func main() {
        var still = Bellows()
        let stillRun = run(&still, start: 0, seconds: 1) { _ in 90 }
        check(stillRun.allSatisfy { $0 == 0 }, "bellows: a still lid makes no air")

        var sweep = Bellows()
        let sweepRun = run(&sweep, start: 0, seconds: 1) { 30 + 90 * $0 }
        check(sweepRun.last! > 0.85, "bellows: 90 degrees per second is near full pressure")

        var slow = Bellows()
        let slowRun = run(&slow, start: 0, seconds: 2) { 30 + 45 * $0 }
        check(slowRun.last! > 0.2 && slowRun.last! < 0.8, "bellows: a slower lid gives less air")

        var closing = Bellows()
        let closingRun = run(&closing, start: 0, seconds: 1) { 120 - 90 * $0 }
        check(closingRun.last! > 0.85, "bellows: closing the lid makes air too")

        var jitter = Bellows()
        let jitterRun = run(&jitter, start: 0, seconds: 2) { 90 + (Int($0 * 60 + 0.5) % 2 == 0 ? 0 : 1) }
        check(jitterRun.max()! < 0.05, "bellows: one degree of sensor jitter stays silent")

        var flip = Bellows()
        _ = run(&flip, start: 0, seconds: 1) { 30 + 90 * $0 }
        let flipRun = run(&flip, start: 1, seconds: 0.3) { 120 - 90 * $0 }
        check(flipRun.min()! > 0.4, "bellows: reversing direction does not cut the air")

        var decay = Bellows()
        _ = run(&decay, start: 0, seconds: 1) { 30 + 90 * $0 }
        let decayRun = run(&decay, start: 1, seconds: 1) { _ in 120 }
        check(decayRun.last! < 0.05, "bellows: air dies out after a second of stillness")

        var gap = Bellows()
        _ = run(&gap, start: 0, seconds: 1) { 30 + 90 * $0 }
        check(gap.update(angle: 10, at: 5) < 0.1, "bellows: a long pause is not a huge lid swing")

        if failures > 0 { exit(1) }
    }
}
```

`Sources/Keys.swift` stub so the compile reaches the Bellows error: `import Foundation`.

- [ ] **Step 2: Run to verify it fails**

Run: `~/Accordion/test.sh`
Expected: compile error `cannot find 'Bellows' in scope`.

- [ ] **Step 3: Write `Sources/Bellows.swift`**

```swift
import Foundation

/// Turns hinge angle samples into bellows air pressure, 0 to 1. Lid speed is the air, either direction.
struct Bellows {
    /// Degrees per second that give full pressure.
    static let fullSpeed = 90.0
    /// Speeds under this are sensor jitter, not a moving lid.
    static let deadzone = 15.0
    /// Speed is the net angle change over this many seconds.
    static let window = 0.1
    /// Shorter spans are not trusted: a one-degree step over 30 ms would read as 30 degrees per second.
    static let minSpan = 0.08
    static let attack = 0.03
    /// Long enough that the pause at a direction reversal does not cut the note.
    static let release = 0.15
    /// A pause longer than this drops the history instead of reading as one fast swing.
    static let gap = 0.5

    private(set) var pressure = 0.0
    private var samples: [(angle: Double, time: Double)] = []
    private var lastTime: Double?

    @discardableResult
    mutating func update(angle: Double, at time: Double) -> Double {
        let dt = lastTime.map { time - $0 } ?? 0
        if dt > Self.gap || dt < 0 { samples.removeAll() }
        lastTime = time
        samples.append((angle, time))
        samples.removeAll { time - $0.time > Self.window }

        var speed = 0.0
        if let first = samples.first, time - first.time >= Self.minSpan {
            speed = abs(angle - first.angle) / (time - first.time)
        }
        let level = min(max((speed - Self.deadzone) / (Self.fullSpeed - Self.deadzone), 0), 1)
        let target = pow(level, 0.7)

        let tau = target > pressure ? Self.attack : Self.release
        pressure += (target - pressure) * (1 - exp(-max(dt, 0) / tau))
        if pressure < 0.001 { pressure = 0 }
        return pressure
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `~/Accordion/test.sh`
Expected: eight `PASS bellows:` lines, exit 0. If a numeric threshold fails, look at the actual value before touching the test or the constants.

---

### Task 2: Keys

**Files:**
- Modify: `Sources/Keys.swift`, `Tests/LogicTests.swift`

**Interfaces:**
- Produces: `struct Keys { static let notes: [Character: Int]; private(set) var octave: Int; mutating func shift(for: Character) -> Bool; func note(for: Character) -> Int? }`

- [ ] **Step 1: Add failing tests** before `if failures > 0` in `main()`:

```swift
        var keys = Keys()
        check(keys.note(for: "a") == 60 && keys.note(for: "k") == 72 && keys.note(for: "'") == 77, "keys: white keys map C4 to F5")
        check(keys.note(for: "w") == 61 && keys.note(for: "p") == 75, "keys: black keys sit between the whites")
        check(Set(Keys.notes.values) == Set(60...77), "keys: 18 keys cover 18 consecutive semitones")
        check(keys.note(for: "q") == nil && keys.note(for: "1") == nil, "keys: other characters are silent")
        check(keys.shift(for: "x") && keys.note(for: "a") == 72, "keys: x goes up an octave")
        _ = keys.shift(for: "x"); _ = keys.shift(for: "x")
        check(keys.note(for: "a") == 84, "keys: octave shift stops at plus 2")
        for _ in 0..<6 { _ = keys.shift(for: "z") }
        check(keys.note(for: "a") == 36, "keys: octave shift stops at minus 2")
        check(!keys.shift(for: "a"), "keys: a note key is not an octave key")
```

- [ ] **Step 2: Run** `~/Accordion/test.sh`. Expected: compile error `value of type 'Keys' has no member 'note'` (stub is empty).

- [ ] **Step 3: Write `Sources/Keys.swift`**

```swift
import Foundation

/// Maps typed characters to MIDI notes, GarageBand style, with an octave shift on Z and X.
struct Keys {
    static let notes: [Character: Int] = [
        "a": 60, "w": 61, "s": 62, "e": 63, "d": 64, "f": 65, "t": 66, "g": 67,
        "y": 68, "h": 69, "u": 70, "j": 71, "k": 72, "o": 73, "l": 74, "p": 75,
        ";": 76, "'": 77,
    ]
    static let maxShift = 2

    private(set) var octave = 0

    /// Handles Z and X. Returns false for any other character.
    mutating func shift(for character: Character) -> Bool {
        switch character {
        case "z": octave = max(octave - 1, -Self.maxShift)
        case "x": octave = min(octave + 1, Self.maxShift)
        default: return false
        }
        return true
    }

    func note(for character: Character) -> Int? {
        Self.notes[character].map { $0 + octave * 12 }
    }
}
```

- [ ] **Step 4: Run** `~/Accordion/test.sh`. Expected: 16 `PASS` lines, exit 0.

---

### Task 3: Sensor, sound, engine

**Files:**
- Create: `Sources/LidAngleSensor.swift` (copy), `Sources/Sound.swift`, `Sources/Engine.swift`

**Interfaces:**
- Consumes: `Bellows.update(angle:at:)`, `Keys.shift(for:)`, `Keys.note(for:)`, `Keys.octave`, `LidAngleSensor()` / `.readAngle() -> Double?`.
- Produces:
  - `Sound`: `init() throws`, `noteOn(_ note: Int)`, `noteOff(_ note: Int)`, `setPressure(_ p: Double)`, `allNotesOff()`.
  - `Engine.shared` (`ObservableObject`): `@Published angle: Double?`, `pressure: Double`, `octave: Int`, `held: Set<Character>` (physical keys down, for lighting the view), `soundError: String?`; `start()`, `keyDown(_ character: Character)`, `keyUp(_ character: Character)`, `releaseAll()`.

- [ ] **Step 1:** `cp ~/LidBlur/Sources/LidAngleSensor.swift ~/Accordion/Sources/`

- [ ] **Step 2: Write `Sources/Sound.swift`**

```swift
import AVFoundation

/// Plays the built-in General MIDI accordion. Bellows pressure rides on MIDI expression (CC11),
/// so held notes fade out when the lid stops.
final class Sound {
    private static let bank = URL(fileURLWithPath:
        "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    /// General MIDI program 22, zero-based 21, is the accordion.
    private static let program: UInt8 = 21
    private static let velocity: UInt8 = 100

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var expression = -1
    private var sounding: [Int: Int] = [:]

    init() throws {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try sampler.loadSoundBankInstrument(
            at: Self.bank, program: Self.program,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        try engine.start()
        setPressure(0)
    }

    func noteOn(_ note: Int) {
        sounding[note, default: 0] += 1
        sampler.startNote(UInt8(note), withVelocity: Self.velocity, onChannel: 0)
    }

    func noteOff(_ note: Int) {
        guard let count = sounding[note] else { return }
        sounding[note] = count > 1 ? count - 1 : nil
        sampler.stopNote(UInt8(note), onChannel: 0)
    }

    func setPressure(_ pressure: Double) {
        let value = Int((min(max(pressure, 0), 1) * 127).rounded())
        guard value != expression else { return }
        expression = value
        sampler.sendController(11, withValue: UInt8(value), onChannel: 0)
    }

    func allNotesOff() {
        for note in sounding.keys { sampler.stopNote(UInt8(note), onChannel: 0) }
        sounding.removeAll()
    }
}
```

- [ ] **Step 3: Write `Sources/Engine.swift`**

```swift
import AppKit

/// Runs the loop: read the hinge, turn lid speed into pressure, feed the sound, publish state for the view.
final class Engine: ObservableObject {
    static let shared = Engine()

    /// Latest hinge reading in degrees. Nil when the Mac has no lid sensor.
    @Published private(set) var angle: Double?
    @Published private(set) var pressure = 0.0
    @Published private(set) var octave = 0
    /// MIDI notes sounding right now, after the octave shift.
    @Published private(set) var held: Set<Int> = []
    @Published private(set) var soundError: String?

    private var bellows = Bellows()
    private var keys = Keys()
    private var sensor: LidAngleSensor?
    private var sound: Sound?
    /// Note each physical key started, so a key up stops the right note even after an octave shift.
    private var sounding: [Character: Int] = [:]
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var missedReads = 0

    private init() {}

    func start() {
        guard timer == nil else { return }
        sensor = LidAngleSensor()
        do { sound = try Sound() } catch { soundError = "Sound failed: \(error.localizedDescription)" }

        // The HID device can go stale across sleep.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.sensor = LidAngleSensor() }

        let loop = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps the loop running while a menu or window drag is tracking events.
        RunLoop.main.add(loop, forMode: .common)
        timer = loop
    }

    func keyDown(_ character: Character) {
        if keys.shift(for: character) {
            octave = keys.octave
            return
        }
        guard sounding[character] == nil, let note = keys.note(for: character) else { return }
        sounding[character] = note
        held.insert(note)
        sound?.noteOn(note)
    }

    func keyUp(_ character: Character) {
        guard let note = sounding.removeValue(forKey: character) else { return }
        held.remove(note)
        sound?.noteOff(note)
    }

    func releaseAll() {
        sounding.removeAll()
        held.removeAll()
        sound?.allNotesOff()
    }

    private func tick() {
        readSensor()
        guard let angle else { return }
        let next = bellows.update(angle: angle, at: CACurrentMediaTime())
        sound?.setPressure(next)
        // Skip tiny changes so the view is not redrawn for nothing.
        if abs(next - pressure) > 0.004 || (next == 0 && pressure != 0) { pressure = next }
    }

    private func readSensor() {
        if let reading = sensor?.readAngle() {
            missedReads = 0
            if angle != reading { angle = reading }
        } else {
            missedReads += 1
        }
        // No sensor, or reads keep failing: look for it again about every two seconds.
        if missedReads >= 120 {
            missedReads = 0
            sensor = LidAngleSensor()
        }
    }
}
```

- [ ] **Step 4: Smoke test the pieces on the real Mac.** Write `$SCRATCH/smoke.swift` (scratchpad dir) that reads `LidAngleSensor().readAngle()` and prints it, and builds `Sound()`, plays note 60 for 1 s with pressure 1.0. Compile with `swiftc -parse-as-library` plus `Sources/LidAngleSensor.swift Sources/Sound.swift`.
Expected: a printed angle between 0 and 180, no thrown error from `Sound()`. (Audible check is the user's.)

---

### Task 4: Window, build, spec touch-up

**Files:**
- Create: `Sources/KeyCatcher.swift`, `Sources/AccordionView.swift`, `Sources/AccordionApp.swift`, `Info.plist`, `build.sh`
- Modify: `docs/superpowers/specs/2026-09-19-accordion-design.md` (Bellows math section)

**Interfaces:**
- Consumes: `Engine.shared` published state and `keyDown`/`keyUp`/`releaseAll`; `Keys.notes`.

- [ ] **Step 1: Write `Sources/KeyCatcher.swift`**, an invisible `NSViewRepresentable` that grabs first responder and forwards key events. Key up looks the character up by key code so a Shift press between down and up cannot leave a note stuck. Events with Command or Control are passed on so Cmd-Q and Cmd-W keep working. Repeats are dropped.
- [ ] **Step 2: Write `Sources/AccordionView.swift`**: `Canvas` accordion (fixed left body, bellows as zigzag pleats whose width follows `angle / 135`, right body that moves with it), a pressure meter, an 11-white-plus-7-black key row lit from `held` (note = `Keys.notes[char]! + octave * 12`), key letters on each key, octave label, and a status line (`soundError`, else "No lid sensor found" when `angle == nil`, else the hint "Move the lid to blow. Z/X = octave").
- [ ] **Step 3: Write `Sources/AccordionApp.swift`**: `@main` App with a single `Window`, delegate starts `Engine.shared`, releases all notes on `applicationDidResignActive`, quits when the window closes.
- [ ] **Step 4: Write `Info.plist`** (copy of LidBlur's with name `Accordion`, id `com.braydonglass.accordion`, no `LSUIElement`) and `build.sh` (LidBlur's script with `Accordion` names, codesign requirement `identifier "com.braydonglass.accordion"`).
- [ ] **Step 5: Build.** Run `~/Accordion/build.sh`. Expected: `built build/Accordion.app`, no compile errors.
- [ ] **Step 6: Launch smoke test.** `open build/Accordion.app`, wait 3 s, confirm the process is alive (`pgrep Accordion`) and take a screenshot of the window.
- [ ] **Step 7: Update the spec's Bellows math** to the windowed-velocity version (Task 1 note).
- [ ] **Step 8: Run** `~/Accordion/test.sh` once more. Expected: all `PASS`.
