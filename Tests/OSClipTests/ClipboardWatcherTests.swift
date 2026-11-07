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

    @Test func textWithPictureIsTextAndImagesKeepPNGOnly() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        let tiff = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { _ in NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 4, height: 4).fill(); return true }.tiffRepresentation!
        let cells = NSPasteboardItem()
        cells.setString("A1\tB1", forType: .string)
        cells.setData(tiff, forType: .tiff)
        pasteboard.clearContents(); pasteboard.writeObjects([cells]); watcher.poll()
        #expect(store.items[0].kind == .text)
        #expect(store.items[0].text == "A1\tB1")

        pasteboard.clearContents(); pasteboard.setData(tiff, forType: .tiff); watcher.poll()
        #expect(store.items[0].kind == .image)
        let entry = store.payload(for: store.items[0])?.first
        #expect(entry?[NSPasteboard.PasteboardType.png.rawValue] != nil)
        #expect(entry?[NSPasteboard.PasteboardType.tiff.rawValue] == nil)

        watcher.copy(store.items[0])
        #expect(pasteboard.data(forType: .tiff) != nil)
    }

    @Test func multiImageTiffKeepsLargestAsPNG() {
        let watcher = ClipboardWatcher(pasteboard: pasteboard, store: store)
        let reps = [16, 32].map {
            NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: $0, pixelsHigh: $0, bitsPerSample: 8, samplesPerPixel: 4,
                             hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        }
        pasteboard.clearContents(); pasteboard.setData(NSBitmapImageRep.tiffRepresentationOfImageReps(in: reps, using: .none, factor: 0)!, forType: .tiff)
        watcher.poll()
        let png = store.payload(for: store.items[0])?.first?[NSPasteboard.PasteboardType.png.rawValue]
        #expect(NSBitmapImageRep(data: png ?? Data())?.pixelsWide == 32)
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
