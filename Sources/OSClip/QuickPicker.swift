import Carbon.HIToolbox
import SwiftUI

/// The ⌃⌘V list: opens at the mouse pointer, ↑/↓ select, typing searches, Enter copies, Esc closes.
@MainActor @Observable
final class QuickPicker: NSObject, NSWindowDelegate {
    var query = "" { didSet { selection = 0 } }
    var selection = 0
    var items: [ClipItem] { query.isEmpty ? Array(store.items.prefix(15)) : store.search(query) }

    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let watcher: ClipboardWatcher
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var monitor: Any?

    init(store: HistoryStore, watcher: ClipboardWatcher) {
        self.store = store
        self.watcher = watcher
    }

    func toggle() {
        panel == nil ? show() : close()
    }

    /// Returns true when the key is handled. Other keys go to the search field.
    func handle(keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if items.indices.contains(selection) { watcher.copy(items[selection]) }
            close()
        case kVK_Escape: close()
        default:
            guard let next = Selection.move(selection, keyCode: keyCode, count: items.count) else { return false }
            selection = next
        }
        return true
    }

    private func show() {
        query = ""
        let size = NSSize(width: 340, height: 380)
        let panel = KeyPanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: QuickPickerView(picker: self, store: store))

        let mouse = NSEvent.mouseLocation
        let frame = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: min(max(mouse.x, frame.minX), frame.maxX - size.width),
                                     y: min(max(mouse.y - size.height, frame.minY), frame.maxY - size.height)))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let code = event.keyCode
            return MainActor.assumeIsolated {
                // While an input method composes text, its keys belong to the text field.
                if (NSApp.keyWindow?.firstResponder as? NSTextInputClient)?.hasMarkedText() == true { return false }
                return self?.handle(keyCode: code) ?? false
            } ? nil : event
        }
    }

    private func close() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        let panel = self.panel
        self.panel = nil
        panel?.close()
    }

    /// A click outside the list closes it.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

/// Arrow-key movement shared by the picker and the history window.
enum Selection {
    /// The index after an arrow key, or nil when the key does not move. ←/→ move only in a grid (`columns` > 1).
    static func move(_ index: Int, keyCode: UInt16, count: Int, columns: Int = 1) -> Int? {
        let step: Int
        switch Int(keyCode) {
        case kVK_DownArrow: step = columns
        case kVK_UpArrow: step = -columns
        case kVK_RightArrow where columns > 1: step = 1
        case kVK_LeftArrow where columns > 1: step = -1
        default: return nil
        }
        return min(max(index + step, 0), max(count - 1, 0))
    }
}

/// A borderless panel that takes key input without activating the app, so the front app keeps focus for Cmd+V.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct QuickPickerView: View {
    @Bindable var picker: QuickPicker
    let store: HistoryStore
    @FocusState private var focused: Bool

    var body: some View {
        let items = picker.items
        VStack(spacing: 0) {
            TextField("Search history", text: $picker.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(10)
                .focused($focused)
            Divider()
            if items.isEmpty {
                ContentUnavailableView(picker.query.isEmpty ? "No History" : "No Results", systemImage: "doc.on.clipboard")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    ItemIcon(item: item, store: store, size: 28).frame(width: 28, height: 28)
                                    Text(item.title).lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(index == picker.selection ? Color.accentColor.opacity(0.3) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    picker.selection = index
                                    _ = picker.handle(keyCode: UInt16(kVK_Return))
                                }
                                .id(index)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: picker.selection) { proxy.scrollTo(picker.selection) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .onAppear { focused = true }
    }
}
