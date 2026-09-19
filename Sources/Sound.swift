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
