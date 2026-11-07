import AppKit
import CryptoKit
import ImageIO
import Observation

/// Raw pasteboard content: one `[type: data]` dictionary per pasteboard item.
typealias Payload = [[String: Data]]

struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, image, file }

    let id: UUID
    let kind: Kind
    /// Searchable text: the string, or the file paths, cut to `HistoryStore.textLimit`. Empty for images.
    let text: String
    let hash: String
    var date: Date
}

/// Keeps the history index in `index.json`, each payload in `<id>.plist`, and image thumbnails in `<id>.png`.
@MainActor @Observable
final class HistoryStore {
    static let defaultLimit = 200
    /// Characters kept in the index for titles and search. The payload keeps the full text.
    static let textLimit = 2000
    static let thumbnailPixels = 256

    private(set) var items: [ClipItem] = []
    var limit: Int { didSet { commit(removing: trim()) } }

    private let dir: URL
    @ObservationIgnored private var thumbnails: [UUID: NSImage] = [:]

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
        let item = ClipItem(id: UUID(), kind: kind, text: String(text.prefix(Self.textLimit)), hash: hash, date: .now)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(payload),
              (try? data.write(to: payloadURL(item.id), options: .atomic)) != nil else { return }
        if kind == .image { writeThumbnail(item, payload) }
        items.insert(item, at: 0)
        commit(removing: trim())
    }

    func payload(for item: ClipItem) -> Payload? {
        guard let data = try? Data(contentsOf: payloadURL(item.id)) else { return nil }
        return try? PropertyListDecoder().decode(Payload.self, from: data)
    }

    /// Thumbnail of the item, drawn at `maxSide` points on its longer side.
    func image(for item: ClipItem, maxSide: CGFloat) -> NSImage? {
        guard item.kind == .image else { return nil }
        if thumbnails[item.id] == nil {
            // Items saved before thumbnails existed get one on first use.
            if !FileManager.default.fileExists(atPath: thumbnailURL(item.id).path), let payload = payload(for: item) {
                writeThumbnail(item, payload)
            }
            thumbnails[item.id] = NSImage(contentsOf: thumbnailURL(item.id))
        }
        guard let copy = thumbnails[item.id]?.copy() as? NSImage, copy.size.width > 0, copy.size.height > 0 else { return nil }
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

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        commit(removing: [item])
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
            try? FileManager.default.removeItem(at: thumbnailURL(item.id))
            thumbnails[item.id] = nil
        }
    }

    /// Writes a small PNG of the first image in the payload. ImageIO scales without decoding the full image.
    private func writeThumbnail(_ item: ClipItem, _ payload: Payload) {
        let first = payload.first
        guard let data = first?[NSPasteboard.PasteboardType.png.rawValue] ?? first?[NSPasteboard.PasteboardType.tiff.rawValue],
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailPixels,
              ] as CFDictionary),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: thumbnailURL(item.id), options: .atomic)
    }

    @discardableResult
    private func save() -> Bool {
        (try? JSONEncoder().encode(items).write(to: indexURL, options: .atomic)) != nil
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    private func payloadURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).plist") }
    private func thumbnailURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).png") }

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
