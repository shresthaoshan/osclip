import SwiftUI

@main
struct OSClipApp: App {
    var body: some Scene {
        MenuBarExtra("OSClip", systemImage: "doc.on.clipboard") {
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
