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
