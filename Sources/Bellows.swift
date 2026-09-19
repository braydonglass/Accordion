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
    /// Seconds for the air to die out (to 5 percent) once the lid stops. Also covers the pause at a
    /// direction reversal, so it does not cut the note.
    static let tail = 0.75
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

        // An exponential decay falls to 5 percent after three time constants.
        let tau = target > pressure ? Self.attack : Self.tail / 3
        pressure += (target - pressure) * (1 - exp(-max(dt, 0) / tau))
        if pressure < 0.001 { pressure = 0 }
        return pressure
    }
}
