import Carbon.HIToolbox
import SwiftUI

struct HistoryView: View {
    let store: HistoryStore
    let watcher: ClipboardWatcher
    @State private var query = ""
    @AppStorage("grid") private var grid = false
    @State private var confirmDeleteAll = false
    @State private var selection = 0
    @State private var searching = true
    @State private var width: CGFloat = 640
    @State private var monitor: Any?
    @State private var window: NSWindow?
    @Environment(\.dismissWindow) private var dismissWindow

    private var columns: Int { grid ? max(1, Int((width - 32) / 158)) : 1 }

    var body: some View {
        let items = store.search(query)
        ScrollViewReader { proxy in
            Group {
                if items.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "No History" : "No Results", systemImage: "doc.on.clipboard")
                } else if grid {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                button(item) { cell(item, selected: index == selection) }
                            }
                        }
                        .padding()
                    }
                } else {
                    List(Array(items.enumerated()), id: \.element.id) { index, item in
                        button(item) { row(item) }
                            .listRowBackground(index == selection ? Color.accentColor.opacity(0.25) : nil)
                    }
                }
            }
            .onChange(of: selection) {
                if items.indices.contains(selection) { proxy.scrollTo(items[selection].id) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(WindowReader { window = $0 })
        .onChange(of: query) { selection = 0 }
        // Any delete (keyboard, context menu, a smaller limit) can leave the selection past the end.
        .onChange(of: items.count) { selection = min(selection, max(items.count - 1, 0)) }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object as? NSWindow === window { searching = true }
        }
        .onAppear {
            searching = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let code = event.keyCode, flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                let target = event.window.map(ObjectIdentifier.init)
                return MainActor.assumeIsolated {
                    // Keys for other windows (Settings, the ⌃⌘V picker) and input method composition pass through.
                    guard let window, target == ObjectIdentifier(window),
                          (window.firstResponder as? NSTextInputClient)?.hasMarkedText() != true else { return false }
                    return handle(keyCode: code, flags: NSEvent.ModifierFlags(rawValue: flags))
                } ? nil : event
            }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        .searchable(text: $query, isPresented: $searching)
        .toolbar {
            Picker("Layout", selection: $grid) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "square.grid.2x2").tag(true)
            }
            .pickerStyle(.segmented)
            Button("Delete All…", systemImage: "trash", role: .destructive) { confirmDeleteAll = true }
                .foregroundStyle(.red)
                .disabled(store.items.isEmpty)
        }
        .confirmationDialog("Delete all history?", isPresented: $confirmDeleteAll) {
            Button("Delete All", role: .destructive) { store.clear() }
        } message: {
            Text("This cannot be undone.")
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    /// Enter copies, ⌘⌫ with an empty search deletes, Esc clears the search and then closes, arrows move.
    private func handle(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let items = store.search(query)
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if items.indices.contains(selection) { pick(items[selection]) }
        case kVK_Escape:
            if query.isEmpty { dismissWindow(id: "main") } else { query = "" }
        case kVK_Delete where flags.contains(.command) && query.isEmpty:
            if items.indices.contains(selection) { store.remove(items[selection]) }
        default:
            // Modified arrows, and ←/→ while there is search text, edit the search field.
            let horizontal = keyCode == kVK_LeftArrow || keyCode == kVK_RightArrow
            guard flags.subtracting([.numericPad, .function]).isEmpty, !(horizontal && !query.isEmpty),
                  let next = Selection.move(selection, keyCode: keyCode, count: items.count, columns: columns) else { return false }
            selection = next
        }
        return true
    }

    /// Copies the item and hides the app, so focus returns to the previous app for Cmd+V.
    private func pick(_ item: ClipItem) {
        watcher.copy(item)
        NSApp.hide(nil)
    }

    private func button(_ item: ClipItem, @ViewBuilder label: () -> some View) -> some View {
        Button {
            pick(item)
        } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) { store.remove(item) }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack {
            ItemIcon(item: item, store: store, size: 40).frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                Text(item.title).lineLimit(1)
                Text(item.date, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func cell(_ item: ClipItem, selected: Bool) -> some View {
        Group {
            if item.kind == .image {
                ItemIcon(item: item, store: store, size: 130)
            } else {
                Text(item.kind == .file ? item.title : item.text)
                    .font(.caption)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(8)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: selected ? 2 : 0))
    }
}

/// Reports the NSWindow that hosts the view, each time the view moves to a window.
private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView { WindowView(onWindow: onWindow) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class WindowView: NSView {
        let onWindow: (NSWindow?) -> Void
        init(onWindow: @escaping (NSWindow?) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() { onWindow(window) }
    }
}
