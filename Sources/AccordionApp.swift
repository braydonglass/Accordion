import SwiftUI

@main
struct AccordionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Accordion", id: "main") {
            AccordionView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Engine.shared.start()
        NSApp.activate()
    }

    /// Key ups go to the other app once focus leaves, so stop every note.
    func applicationDidResignActive(_ notification: Notification) {
        Engine.shared.releaseAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
