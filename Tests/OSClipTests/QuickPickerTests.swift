import AppKit
import Carbon.HIToolbox
import Testing
@testable import OSClip

@MainActor
struct QuickPickerTests {
    let pasteboard = NSPasteboard.withUniqueName()
    let store = HistoryStore(dir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), limit: 50)

    func key(_ picker: QuickPicker, _ code: Int) { _ = picker.handle(keyCode: UInt16(code)) }

    @Test func navigateSearchAndCopy() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        for i in 0..<20 {
            store.add([["public.utf8-plain-text": Data("item \(i)".utf8)]], kind: .text, text: "item \(i)")
        }
        let picker = QuickPicker(store: store, watcher: watcher)
        #expect(picker.items.count == 15)

        key(picker, kVK_UpArrow)
        #expect(picker.selection == 0)
        for _ in 0..<30 { key(picker, kVK_DownArrow) }
        #expect(picker.selection == 14)

        picker.query = "item 1"  // item 1 and item 10–19, across the whole history
        #expect(picker.selection == 0)
        #expect(picker.items.count == 11)
        key(picker, kVK_DownArrow)
        key(picker, kVK_Return)
        #expect(pasteboard.string(forType: .string) == "item 18")
        #expect(picker.handle(keyCode: UInt16(kVK_ANSI_A)) == false)
    }

    @Test func gridMovement() {
        func move(_ i: Int, _ key: Int) -> Int? { Selection.move(i, keyCode: UInt16(key), count: 10, columns: 4) }
        #expect(move(0, kVK_DownArrow) == 4)
        #expect(move(8, kVK_DownArrow) == 9)
        #expect(move(5, kVK_UpArrow) == 1)
        #expect(move(1, kVK_UpArrow) == 0)
        #expect(move(3, kVK_RightArrow) == 4)
        #expect(move(0, kVK_LeftArrow) == 0)
        #expect(Selection.move(3, keyCode: UInt16(kVK_LeftArrow), count: 10) == nil)
        #expect(move(0, kVK_ANSI_A) == nil)
    }
}
