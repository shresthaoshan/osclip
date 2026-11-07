import AppKit
import CryptoKit
import Observation

/// Raw pasteboard content: one `[type: data]` dictionary per pasteboard item.
typealias Payload = [[String: Data]]

struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, image, file }

    let id: UUID
    let kind: Kind
    /// Searchable text: the string, or the file paths. Empty for images.
    let text: String
    let hash: String
    var date: Date
}

/// Keeps the history index in `index.json` and each payload in `<id>.plist`.
@MainActor @Observable
final class HistoryStore {
    static let defaultLimit = 200

    private(set) var items: [ClipItem] = []
    var limit: Int { didSet { commit(removing: trim()) } }

    private let dir: URL
    // ponytail: full-size decoded images stay in memory; store real thumbnails if memory grows.
    @ObservationIgnored private var images: [UUID: NSImage] = [:]

    init(dir: URL, limit: Int) {
        self.dir = dir
        self.limit = limit
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            items = try JSONDecoder().decode([ClipItem].self, from: data)
        } catch {
            // Keep the unreadable index for recovery instead of overwriting it on the next save.
            try? FileManager.default.moveItem(at: indexURL, to: dir.appendingPathComponent("index-corrupt-\(Int(Date().timeIntervalSince1970)).json"))
        }
    }

    func add(_ payload: Payload, kind: ClipItem.Kind, text: String) {
        let hash = Self.hash(payload)
        if let existing = items.first(where: { $0.hash == hash }) {
            touch(existing)
            return
        }
        let item = ClipItem(id: UUID(), kind: kind, text: text, hash: hash, date: .now)
        guard let data = try? PropertyListEncoder().encode(payload),
              (try? data.write(to: payloadURL(item.id), options: .atomic)) != nil else { return }
        items.insert(item, at: 0)
        commit(removing: trim())
    }

    func payload(for item: ClipItem) -> Payload? {
        guard let data = try? Data(contentsOf: payloadURL(item.id)) else { return nil }
        return try? PropertyListDecoder().decode(Payload.self, from: data)
    }

    /// Image of the item, drawn at `maxSide` points on its longer side.
    func image(for item: ClipItem, maxSide: CGFloat) -> NSImage? {
        guard item.kind == .image else { return nil }
        if images[item.id] == nil {
            let first = payload(for: item)?.first
            guard let data = first?[NSPasteboard.PasteboardType.png.rawValue]
                ?? first?[NSPasteboard.PasteboardType.tiff.rawValue],
                  let image = NSImage(data: data) else { return nil }
            images[item.id] = image
        }
        guard let copy = images[item.id]?.copy() as? NSImage, copy.size.width > 0, copy.size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(copy.size.width, copy.size.height))
        copy.size = NSSize(width: copy.size.width * scale, height: copy.size.height * scale)
        return copy
    }

    /// Moves the item to the top.
    func touch(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var moved = items.remove(at: index)
        moved.date = .now
        items.insert(moved, at: 0)
        save()
    }

    func search(_ query: String) -> [ClipItem] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? items : items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    func clear() {
        let removed = items
        items = []
        commit(removing: removed)
    }

    /// Drops items over the limit and returns them.
    private func trim() -> [ClipItem] {
        guard items.count > limit else { return [] }
        defer { items.removeSubrange(limit...) }
        return Array(items[limit...])
    }

    /// Saves the index, then deletes the payloads of removed items. A failed save keeps the files.
    private func commit(removing removed: [ClipItem] = []) {
        guard save() else { return }
        for item in removed {
            try? FileManager.default.removeItem(at: payloadURL(item.id))
            images[item.id] = nil
        }
    }

    @discardableResult
    private func save() -> Bool {
        (try? JSONEncoder().encode(items).write(to: indexURL, options: .atomic)) != nil
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    private func payloadURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).plist") }

    static func hash(_ payload: Payload) -> String {
        // Length prefixes keep item and entry boundaries, so different payloads never share an input.
        var hasher = SHA256()
        func length(_ n: Int) { withUnsafeBytes(of: UInt64(n).littleEndian) { hasher.update(bufferPointer: $0) } }
        length(payload.count)
        for item in payload {
            length(item.count)
            for (key, data) in item.sorted(by: { $0.key < $1.key }) {
                length(key.utf8.count); hasher.update(data: Data(key.utf8))
                length(data.count); hasher.update(data: data)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
