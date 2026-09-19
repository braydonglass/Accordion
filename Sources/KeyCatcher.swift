import SwiftUI
import AppKit

/// Invisible view that takes keyboard focus and turns key events into Engine calls.
struct KeyCatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyView { KeyView() }
    func updateNSView(_ view: KeyView, context: Context) {}
}

final class KeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    /// Character each physical key started, looked up by key code on key up so a Shift press
    /// between down and up cannot leave a note stuck.
    private var pressed: [UInt16: Character] = [:]

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(self) }
    }

    override func keyDown(with event: NSEvent) {
        // Leave Cmd and Ctrl combos alone so Cmd-Q and Cmd-W keep working.
        if !event.modifierFlags.intersection([.command, .control]).isEmpty { return super.keyDown(with: event) }
        guard !event.isARepeat, let character = event.charactersIgnoringModifiers?.lowercased().first else { return }
        pressed[event.keyCode] = character
        Engine.shared.keyDown(character)
    }

    override func keyUp(with event: NSEvent) {
        guard let character = pressed.removeValue(forKey: event.keyCode) else { return }
        Engine.shared.keyUp(character)
    }

    override func resignFirstResponder() -> Bool {
        pressed.removeAll()
        Engine.shared.releaseAll()
        return super.resignFirstResponder()
    }
}
