import Foundation
import AppKit
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("SystemPaster")
struct SystemPasterTests {

    @Test("Copies to the pasteboard even without auto-paste (Accessibility) access")
    @MainActor
    func copyOnlyDegrade() async throws {
        // In the test process PostEvent access is not granted, so paste() takes the
        // copy-only path: the text lands on the pasteboard, no ⌘V is synthesized.
        let pb = NSPasteboard(name: NSPasteboard.Name("pl.actuna.copypaste.test.paster"))
        pb.clearContents()
        let paster = SystemPaster(pasteboard: pb, restorePrevious: false)

        try await paster.paste(text: "copied-value", autoClearAfter: nil)

        #expect(pb.string(forType: .string) == "copied-value")
    }
}
