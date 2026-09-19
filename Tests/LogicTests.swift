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
        check(decayRun[9] > 0.5, "bellows: air is still strong 0.15 s after the lid stops")
        check(decayRun[18] > 0.2, "bellows: air is still audible 0.3 s after the lid stops")
        check(decayRun[45] < 0.08, "bellows: air is gone by about 0.75 s after the lid stops")

        var gap = Bellows()
        _ = run(&gap, start: 0, seconds: 1) { 30 + 90 * $0 }
        check(gap.update(angle: 10, at: 5) < 0.1, "bellows: a long pause is not a huge lid swing")

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

        if failures > 0 { exit(1) }
    }
}
