import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import ActunaCopyPasteCore

public enum PasteError: Error, Equatable {
    case postEventAccessDenied
    case eventCreationFailed
}

/// Pastes into the frontmost app: writes to the pasteboard, then synthesizes ⌘V
/// via CoreGraphics. Always pastes (never per-character) so terminals' bracketed-
/// paste protection applies to multi-line content.
///
/// Requires PostEvent access (`CGRequestPostEventAccess`). NOT unit-tested: calling
/// `paste` injects a real ⌘V into whatever app is focused, so it is verified
/// manually / in the app target only.
@MainActor
public final class SystemPaster: PastePort {
    private let pasteboard: NSPasteboard
    private let restorePrevious: Bool

    public init(pasteboard: NSPasteboard = .general, restorePrevious: Bool = false) {
        self.pasteboard = pasteboard
        self.restorePrevious = restorePrevious
    }

    /// Whether synthetic ⌘V is currently permitted (PostEvent / Accessibility access).
    public static var canAutoPaste: Bool { CGPreflightPostEventAccess() }

    /// Whether the process is trusted for Accessibility — required to install an ACTIVE
    /// `CGEventTap` (the ⌃+right-click gesture). No prompt; pure probe.
    public static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Requests PostEvent permission (shows the system prompt if undetermined).
    @discardableResult
    public static func requestAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    /// Actively asks the user for the Accessibility permission that synthetic ⌘V
    /// needs: registers for PostEvent access AND shows the classic system dialog
    /// ("…would like to control this computer…", with an Open System Settings button).
    /// Returns whether access is already granted.
    @discardableResult
    public static func promptForAccess() -> Bool {
        let postEvent = CGRequestPostEventAccess()
        // Literal key avoids referencing the (Swift 6 non-concurrency-safe) global
        // `kAXTrustedCheckOptionPrompt`; its value is the stable string below.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        return postEvent || trusted
    }

    /// Puts `text` on the pasteboard and, IF PostEvent access is granted, synthesizes
    /// ⌘V into the focused app. When access is NOT granted it degrades to "copy only"
    /// (the text stays on the clipboard for a manual ⌘V) instead of failing — so the
    /// app is useful before the user enables Accessibility.
    public func paste(text: String, autoClearAfter seconds: TimeInterval?) async throws {
        let didAutoPaste = CGPreflightPostEventAccess()
        // Only stash the previous clipboard when we will auto-paste; in copy-only mode
        // the text must stay so the user can paste it manually.
        let previous = (restorePrevious && didAutoPaste) ? pasteboard.string(forType: .string) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        DebugLog.log("SystemPaster.paste textLen=\(text.count) didAutoPaste=\(didAutoPaste)", category: "paste")

        if didAutoPaste {
            try synthesizeCommandV()
            DebugLog.log("SystemPaster synthesized ⌘V", category: "paste")
        } else {
            DebugLog.log("SystemPaster copy-only (no PostEvent access) — user must press ⌘V", category: "paste")
        }

        if let previous {
            // Restore after a short delay so the target app reads our content first.
            let pb = pasteboard
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                pb.clearContents()
                pb.setString(previous, forType: .string)
            }
        } else if let seconds {
            // Auto-clear secrets after N seconds (also applies in copy-only mode,
            // giving the user time to paste before the secret is wiped).
            let token = pasteboard.changeCount
            let pb = pasteboard
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if pb.changeCount == token { pb.clearContents() }
            }
        }
    }

    private func synthesizeCommandV() throws {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09 // 'v'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            throw PasteError.eventCreationFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
