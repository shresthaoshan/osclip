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
    var limit: Int { didSet { trim(); save() } }

    private let dir: URL
    // ponytail: full-size decoded images stay in memory; store real thumbnails if memory grows.
    @ObservationIgnored private var images: [UUID: NSImage] = [:]

    init(dir: URL, limit: Int) {
        self.dir = dir
        self.limit = limit
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL) {
            items = (try? JSONDecoder().decode([ClipItem].self, from: data)) ?? []
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
        trim()
        save()
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
        items.forEach(deleteFiles)
        items = []
        save()
    }

    private func trim() {
        guard items.count > limit else { return }
        items[limit...].forEach(deleteFiles)
        items.removeSubrange(limit...)
    }

    private func deleteFiles(_ item: ClipItem) {
        try? FileManager.default.removeItem(at: payloadURL(item.id))
        images[item.id] = nil
    }

    private func save() {
        try? JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    private func payloadURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).plist") }

    static func hash(_ payload: Payload) -> String {
        var hasher = SHA256()
        for item in payload {
            for key in item.keys.sorted() {
                hasher.update(data: Data(key.utf8))
                hasher.update(data: item[key]!)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
