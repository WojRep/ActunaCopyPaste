import Foundation
import AppKit
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@MainActor
@Suite("NSPasteboard adapters")
struct NSPasteboardAdaptersTests {

    private func pasteboard(_ suffix: String) -> NSPasteboard {
        // Dedicated named pasteboards so tests never touch the user's general clipboard.
        let pb = NSPasteboard(name: NSPasteboard.Name("pl.actuna.test.\(suffix)"))
        pb.clearContents()
        return pb
    }

    @Test("Writer puts the string on the pasteboard")
    func writes() async throws {
        let pb = pasteboard("writer.basic")
        let writer = NSPasteboardClipboardWriter(pasteboard: pb)
        try await writer.write("hello-clip", autoClearAfter: nil)
        #expect(pb.string(forType: .string) == "hello-clip")
    }

    @Test("Writer auto-clears after the delay when nothing else wrote")
    func autoClears() async throws {
        let pb = pasteboard("writer.autoclear")
        let writer = NSPasteboardClipboardWriter(pasteboard: pb)
        try await writer.write("temp-secret", autoClearAfter: 0.05)
        #expect(pb.string(forType: .string) == "temp-secret")
        try await Task.sleep(nanoseconds: 250_000_000)
        #expect(pb.string(forType: .string) == nil)
    }

    @Test("Monitor captures plain text with no markers")
    func capturesText() {
        let pb = pasteboard("monitor.text")
        pb.setString("copied text", forType: .string)
        let captured = NSPasteboardMonitor.capture(from: pb)
        #expect(captured?.kind == .text)
        #expect(captured?.text == "copied text")
        #expect(captured?.markers.isEmpty == true)
    }

    @Test("Monitor honors the nspasteboard concealed marker")
    func capturesConcealedMarker() {
        let pb = pasteboard("monitor.concealed")
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        pb.declareTypes([.string, concealed], owner: nil)
        pb.setString("p@ssw0rd", forType: .string)
        pb.setData(Data(), forType: concealed)
        let captured = NSPasteboardMonitor.capture(from: pb)
        #expect(captured?.markers.contains(.concealed) == true)
    }

    @Test("Monitor reads source-app attribution")
    func capturesSourceApp() {
        let pb = pasteboard("monitor.source")
        let source = NSPasteboard.PasteboardType("org.nspasteboard.source")
        pb.declareTypes([.string, source], owner: nil)
        pb.setString("text", forType: .string)
        pb.setData(Data("com.apple.Safari".utf8), forType: source)
        #expect(NSPasteboardMonitor.capture(from: pb)?.sourceApp == "com.apple.Safari")
    }

    @Test("Monitor returns nil for an empty pasteboard")
    func emptyReturnsNil() {
        let pb = pasteboard("monitor.empty")
        #expect(NSPasteboardMonitor.capture(from: pb) == nil)
    }
}
