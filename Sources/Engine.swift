import AppKit

/// Runs the loop: read the hinge, turn lid speed into pressure, feed the sound, publish state for the view.
final class Engine: ObservableObject {
    static let shared = Engine()

    /// Latest hinge reading in degrees. Nil when the Mac has no lid sensor.
    @Published private(set) var angle: Double?
    @Published private(set) var pressure = 0.0
    @Published private(set) var octave = 0
    /// Physical keys held down right now, for lighting them in the view.
    @Published private(set) var held: Set<Character> = []
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
        held.insert(character)
        sound?.noteOn(note)
    }

    func keyUp(_ character: Character) {
        guard let note = sounding.removeValue(forKey: character) else { return }
        held.remove(character)
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
