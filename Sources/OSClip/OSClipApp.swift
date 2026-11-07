import SwiftUI

@main
struct OSClipApp: App {
    @State private var store: HistoryStore
    private let watcher: ClipboardWatcher
    private let picker: QuickPicker

    init() {
        let limit = UserDefaults.standard.object(forKey: "limit") as? Int ?? HistoryStore.defaultLimit
        let store = HistoryStore(dir: .applicationSupportDirectory.appending(path: "osclip"), limit: limit)
        _store = State(initialValue: store)
        watcher = ClipboardWatcher(store: store)
        watcher.start()
        let picker = QuickPicker(store: store, watcher: watcher)
        self.picker = picker
        HotKey.register { picker.toggle() }
    }

    var body: some Scene {
        MenuBarExtra("OSClip", systemImage: "doc.on.clipboard") {
            MenuContent(store: store, watcher: watcher)
        }
        Window("OSClip", id: "main") {
            HistoryView(store: store, watcher: watcher)
        }
        Window("OSClip Settings", id: "settings") {
            SettingsView(store: store)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    let store: HistoryStore
    let watcher: ClipboardWatcher
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.items.isEmpty { Text("No history") }
        ForEach(store.items.prefix(15)) { item in
            Button { watcher.copy(item) } label: {
                Label { Text(item.title) } icon: { ItemIcon(item: item, store: store, size: 32) }
            }
        }
        Divider()
        if !HotKey.isRegistered { Text("⌃⌘V is in use by another app") }
        Button("Open…") { open("main") }.keyboardShortcut("o")
        Button("Settings…") { open("settings") }.keyboardShortcut(",")
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}

/// Image thumbnail, or a symbol for the item kind.
struct ItemIcon: View {
    let item: ClipItem
    let store: HistoryStore
    let size: CGFloat

    var body: some View {
        if let image = store.image(for: item, maxSide: size) {
            Image(nsImage: image)
        } else {
            Image(systemName: item.kind == .file ? "doc" : "text.alignleft")
        }
    }
}

extension ClipItem {
    /// One short line for menus and lists.
    var title: String {
        switch kind {
        case .image: return "Image"
        case .file: return text.split(separator: "\n").map { URL(fileURLWithPath: String($0)).lastPathComponent }.joined(separator: ", ")
        case .text:
            let line = text.split(whereSeparator: \.isNewline).first { !$0.allSatisfy(\.isWhitespace) } ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.count > 60 ? trimmed.prefix(60) + "…" : trimmed
        }
    }
}
