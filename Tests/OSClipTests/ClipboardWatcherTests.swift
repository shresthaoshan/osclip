import AppKit
import Testing
@testable import OSClip

@MainActor
struct ClipboardWatcherTests {
    let pasteboard = NSPasteboard.withUniqueName()
    let store = HistoryStore(dir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), limit: 10)

    @Test func capturesTextImageAndFile() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.clearContents(); pasteboard.setString("hi", forType: .string); watcher.poll()
        pasteboard.clearContents(); pasteboard.writeObjects([NSImage(size: NSSize(width: 4, height: 4), flipped: false) { _ in true }]); watcher.poll()
        pasteboard.clearContents(); pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/x.txt") as NSURL]); watcher.poll()
        #expect(store.items.map(\.kind) == [.file, .image, .text])
        #expect(store.items[0].text == "/tmp/x.txt")
    }

    @Test func skipsConcealedItems() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        let item = NSPasteboardItem()
        item.setString("secret", forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.clearContents(); pasteboard.writeObjects([item]); watcher.poll()
        #expect(store.items.isEmpty)
    }

    @Test func copyRestoresContentAndIgnoresOwnWrite() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        pasteboard.clearContents(); pasteboard.setString("first", forType: .string); watcher.poll()
        pasteboard.clearContents(); pasteboard.setString("second", forType: .string); watcher.poll()
        watcher.copy(store.items[1])
        #expect(pasteboard.string(forType: .string) == "first")
        #expect(store.items.map(\.text) == ["first", "second"])
        let dates = store.items.map(\.date)
        watcher.poll()
        #expect(store.items.map(\.date) == dates)
    }
}
