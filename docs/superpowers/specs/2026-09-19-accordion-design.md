# Accordion: design

A Mac app that plays like an accordion. The laptop lid is the bellows. The keyboard is the piano keys.

## Behavior

- Moving the lid, opening or closing, pushes air. Faster movement is louder. A lid held still is silent, even with keys down.
- Keys play notes. A note sounds only while its key is held and the bellows are moving.
- The window shows an accordion whose bellows fold with the real lid angle. Pressed keys light up.

## Decisions

| Question | Choice |
|---|---|
| Bellows control | Lid speed = air pressure |
| Key layout | GarageBand style |
| Sound | Apple's built-in GM accordion (`gs_instruments.dls`), pressure drives MIDI expression (CC11) |
| App form | Window app, needs focus for key up/down, no permissions |
| Fallback sound | Hand-synthesized detuned reeds, only if the built-in accordion sounds bad |

## Units

1. `LidAngleSensor`: hinge degrees. Copied unchanged from `~/LidBlur/Sources/LidAngleSensor.swift`.
2. `Bellows`: pure logic. Takes `(angle, time)` samples, outputs pressure 0 to 1.
3. `Keys`: pure logic. Maps key characters to MIDI notes, tracks octave shift.
4. `Sound`: wraps `AVAudioUnitSampler` loaded with the built-in DLS accordion. Methods: `noteOn`, `noteOff`, `setPressure`, `allNotesOff`.
5. `Engine`: polls the sensor at 60 Hz, feeds `Bellows`, pushes pressure to `Sound`, publishes angle and pressure to the UI.
6. `AccordionView` (SwiftUI): draws bellows, keys, and a status line.

## Bellows math

- Speed = net angle change over the last 0.1 s, divided by the elapsed time. Per-sample speed reads 1-degree sensor jitter as 60 degrees per second of air, so it is not used. Spans shorter than 0.08 s are ignored for the same reason.
- Deadzone: speed under 15 degrees per second counts as 0.
- Pressure target = `clamp((speed - 15) / (90 - 15))` raised to 0.7 so quiet playing has more range. 90 degrees per second is full pressure.
- Pressure eases toward the target: attack time constant 30 ms. The tail is 0.75 s to 5 percent (time constant 0.25 s), which also covers the zero-speed moment when the lid reverses direction.
- A gap of more than 0.5 s between samples drops the history.
- MIDI expression (CC11) = `round(pressure * 127)`. Sent only when the value changes.

## Tried and dropped: balloon reserve

A reserve that lid air filled and held notes drained (5 s per full balloon) was built and playtested. The user said it felt like bagpipes. It was removed. Instead the air has a short tail: after the lid stops it dies out over 0.75 s (`Bellows.tail`). The 150 ms release it replaced sounded like no tail at all.

## Keys

- White keys, C4 up: `A S D F G H J K L ; '` (C4 to F5).
- Black keys: `W E T Y U O P` (C#4 D#4 F#4 G#4 A#4 C#5 D#5).
- `Z` shifts down one octave, `X` up one, limited to plus or minus 2.
- Key repeat is ignored. Key combos with Cmd are ignored so Cmd-Q and Cmd-W keep working.
- Note-on velocity is fixed at 100. Loudness comes only from the bellows.
- When the window loses focus, all notes are released.

## Errors and edges

- No hinge sensor: window shows "No lid sensor found" and the keys stay silent.
- Wake from sleep: recreate the sensor, as LidBlur does.
- Built-in DLS missing or fails to load: window shows the error. No silent fallback.
- Mac keyboards limit how many keys register at once. Chords past that limit drop notes. This is a hardware limit, not handled.

## Testing

- `test.sh` compiles `Bellows.swift`, `Keys.swift` and `Tests/LogicTests.swift` and runs them, same pattern as LidBlur.
- `Bellows` tests: steady angle gives 0; constant sweep of 90 degrees per second gives about 1; alternating plus or minus 1 degree stays 0; a direction reversal does not drop pressure to 0 within 50 ms; pressure decays to under 0.05 after 1 second of stillness.
- `Keys` tests: every listed character maps to the right MIDI note; octave shift clamps; unlisted characters map to nothing.
- Sound and lid hardware are checked by hand: run the app, sweep the lid, press keys.

## Build

`build.sh` (`swiftc`, ad-hoc signed, same as LidBlur) makes `build/Accordion.app`. `--install` copies it to `~/Applications`. No Screen Recording or Input Monitoring grant needed.
