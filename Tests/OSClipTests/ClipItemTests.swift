import Foundation
import Testing
@testable import OSClip

struct ClipItemTests {
    func item(_ kind: ClipItem.Kind, _ text: String) -> ClipItem {
        ClipItem(id: UUID(), kind: kind, text: text, hash: "", date: .now)
    }

    @Test func titles() {
        #expect(item(.text, "\n  \n  first line \nsecond").title == "first line")
        #expect(item(.text, String(repeating: "x", count: 70)).title == String(repeating: "x", count: 60) + "…")
        #expect(item(.file, "/a/b.txt\n/c/d.png").title == "b.txt, d.png")
        #expect(item(.image, "").title == "Image")
    }
}
