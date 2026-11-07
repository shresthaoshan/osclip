import Foundation
import Testing
@testable import OSClip

@MainActor
struct HistoryStoreTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    func text(_ s: String) -> Payload { [["public.utf8-plain-text": Data(s.utf8)]] }
    func files() -> [String] { (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] }

    @Test func duplicateMovesToTop() {
        let store = HistoryStore(dir: dir, limit: 10)
        store.add(text("a"), kind: .text, text: "a")
        store.add(text("b"), kind: .text, text: "b")
        store.add(text("a"), kind: .text, text: "a")
        #expect(store.items.map(\.text) == ["a", "b"])
    }

    @Test func trimsToLimitAndDeletesFiles() {
        let store = HistoryStore(dir: dir, limit: 3)
        for s in ["a", "b", "c", "d"] { store.add(text(s), kind: .text, text: s) }
        #expect(store.items.map(\.text) == ["d", "c", "b"])
        store.limit = 1
        #expect(store.items.map(\.text) == ["d"])
        #expect(files().filter { $0.hasSuffix(".plist") }.count == 1)
    }

    @Test func persistsAcrossInstances() {
        let store = HistoryStore(dir: dir, limit: 10)
        store.add(text("hello"), kind: .text, text: "hello")
        let reloaded = HistoryStore(dir: dir, limit: 10)
        #expect(reloaded.items == store.items)
        #expect(reloaded.payload(for: reloaded.items[0]) == text("hello"))
    }

    @Test func searchIgnoresCase() {
        let store = HistoryStore(dir: dir, limit: 10)
        store.add(text("Hello World"), kind: .text, text: "Hello World")
        store.add(text("other"), kind: .text, text: "other")
        #expect(store.search("world").map(\.text) == ["Hello World"])
        #expect(store.search(" ").count == 2)
    }

    @Test func removeDeletesOneItemAndItsFile() {
        let store = HistoryStore(dir: dir, limit: 10)
        store.add(text("a"), kind: .text, text: "a")
        store.add(text("b"), kind: .text, text: "b")
        store.remove(store.items[0])
        #expect(store.items.map(\.text) == ["a"])
        #expect(files().filter { $0.hasSuffix(".plist") }.count == 1)
        #expect(HistoryStore(dir: dir, limit: 10).items.map(\.text) == ["a"])
    }

    @Test func clearRemovesEverything() {
        let store = HistoryStore(dir: dir, limit: 10)
        store.add(text("a"), kind: .text, text: "a")
        store.clear()
        #expect(store.items.isEmpty)
        #expect(files() == ["index.json"])
    }
}

@MainActor
struct HistoryStoreRegressionTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    @Test func hashKeepsItemBoundaries() {
        let key = "public.utf8-plain-text"
        let two: Payload = [[key: Data("A".utf8)], [key: Data("B".utf8)]]
        let one: Payload = [[key: Data("A\(key)B".utf8)]]
        #expect(HistoryStore.hash(two) != HistoryStore.hash(one))
    }

    @Test func corruptIndexIsKeptAsBackup() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("index.json"))
        let store = HistoryStore(dir: dir, limit: 10)
        #expect(store.items.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains { $0.hasPrefix("index-corrupt-") })
    }
}
