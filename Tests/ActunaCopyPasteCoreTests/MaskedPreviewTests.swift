import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("MaskedPreview")
struct MaskedPreviewTests {

    @Test("Long secret shows edges and caps bullets")
    func longSecret() {
        // 24 characters: "abcdefghijklmnopqrstuvwx"
        let preview = MaskedPreview.make(from: "abcdefghijklmnopqrstuvwx", visibleEdge: 2, context: "API key")
        #expect(preview.visiblePrefix == "ab")
        #expect(preview.visibleSuffix == "wx")
        #expect(preview.hiddenCount == 20)
        #expect(preview.masked == "ab\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}wx")
        #expect(preview.context == "API key")
    }

    @Test("Short secret (<= 4 chars) is fully masked")
    func shortSecret() {
        let preview = MaskedPreview.make(from: "abcd", context: "")
        #expect(preview.visiblePrefix.isEmpty)
        #expect(preview.visibleSuffix.isEmpty)
        #expect(preview.hiddenCount == 4)
        #expect(preview.masked == "\u{2022}\u{2022}\u{2022}\u{2022}")
    }

    @Test("Six-char secret reveals one char per side")
    func sixChars() {
        let preview = MaskedPreview.make(from: "abcdef", visibleEdge: 2, context: "")
        #expect(preview.visiblePrefix == "a")
        #expect(preview.visibleSuffix == "f")
        #expect(preview.hiddenCount == 4)
        #expect(preview.masked == "a\u{2022}\u{2022}\u{2022}\u{2022}f")
    }

    @Test("Always hides at least four characters")
    func minimumHidden() {
        for length in 5...12 {
            let plaintext = String((0..<length).map { _ in Character("x") })
            let preview = MaskedPreview.make(from: plaintext, visibleEdge: 2, context: "")
            #expect(preview.hiddenCount >= 4)
        }
    }
}
