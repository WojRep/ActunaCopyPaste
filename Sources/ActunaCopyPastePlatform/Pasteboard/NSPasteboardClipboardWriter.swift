import Foundation
import AppKit
import ActunaCopyPasteCore

/// Writes text to an `NSPasteboard` (write-only path for the password generator's
/// "land in the clipboard" flow). `@MainActor` because `NSPasteboard` is
/// main-thread API; satisfies the async `ClipboardWriterPort` requirement.
///
/// Auto-clear wipes the pasteboard after `seconds`, but only if nothing else has
/// written in the meantime (guarded by `changeCount`), so we never clobber newer
/// user content.
@MainActor
public final class NSPasteboardClipboardWriter: ClipboardWriterPort {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func write(_ text: String, autoClearAfter seconds: TimeInterval?) async throws {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        guard let seconds else { return }

        let token = pasteboard.changeCount
        let pb = pasteboard
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if pb.changeCount == token {
                pb.clearContents()
            }
        }
    }
}
