import Foundation
import Observation
import AppKit
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

/// A single history row prepared for display. Pure value type: secrets carry only
/// their masked preview + context, never plaintext.
public struct ClipRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let displayText: String
    public let isSecret: Bool
    public let secretContext: String?
    public let pinned: Bool
    public let kind: ClipKind

    public init(id: UUID, displayText: String, isSecret: Bool, secretContext: String?, pinned: Bool, kind: ClipKind) {
        self.id = id
        self.displayText = displayText
        self.isSecret = isSecret
        self.secretContext = secretContext
        self.pinned = pinned
        self.kind = kind
    }

    /// Pure mapping from a domain item to a display row.
    public init(item: ClipItem) {
        self.id = item.id
        self.displayText = item.payload.displayText
        self.pinned = item.pinned
        self.kind = item.kind
        if case .secret(let secret) = item.payload {
            self.isSecret = true
            self.secretContext = secret.preview.context
        } else {
            self.isSecret = false
            self.secretContext = nil
        }
    }

    /// Pure batch mapping — the testable presentation seam.
    public static func rows(from items: [ClipItem]) -> [ClipRow] {
        items.map(ClipRow.init(item:))
    }
}

/// Presentation model bridging the SwiftUI views and the `ClipboardEngine` actor.
/// `@MainActor @Observable`: all UI state lives on the main actor; engine calls are
/// `async`. The pure mapping (`ClipRow`) is unit-tested; this glue is thin.
@MainActor
@Observable
public final class ClipboardViewModel {
    public private(set) var rows: [ClipRow] = []
    public var searchText: String = ""
    public private(set) var lastGenerated: GeneratedPassword?
    public private(set) var statusMessage: String?

    private let engine: ClipboardEngine

    public init(engine: ClipboardEngine) {
        self.engine = engine
    }

    /// Reloads `rows` from the engine, honoring the current search text.
    public func refresh() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = query.isEmpty ? await engine.snapshot() : await engine.search(query)
        rows = ClipRow.rows(from: items)
    }

    /// Whether the app can synthesize ⌘V (PostEvent / Accessibility access granted).
    public var autoPasteAvailable: Bool { SystemPaster.canAutoPaste }

    /// Pastes the item; returns `true` on success. On failure it sets a human-readable
    /// `statusMessage` and returns `false` so the panel can re-surface the reason (the
    /// paste path hides the panel first, so a silent failure would otherwise be invisible).
    @discardableResult
    public func paste(_ id: UUID) async -> Bool {
        // The AX secure-field adapter is deferred, so the focus is reported as
        // unknown; the vault then degrades secrets to a Touch ID gate (safe default).
        let target = FocusedFieldInfo(isSecureField: nil, appBundleID: nil)
        DebugLog.log("viewModel.paste begin id=\(id) autoPaste=\(autoPasteAvailable)", category: "paste")
        do {
            try await engine.paste(id, into: target)
            // engine.paste always puts the text on the clipboard; ⌘V is synthesized
            // only when Accessibility is granted (else copy-only — tell the user).
            statusMessage = autoPasteAvailable
                ? nil
                : L("Copied to clipboard — press ⌘V in the target field.")
            DebugLog.log("viewModel.paste done (clipboard now has the item)", category: "paste")
            return true
        } catch SecretsVaultError.cryptographyFailed {
            statusMessage = L("This secret can't be decrypted — it was created with an old key. Delete it and save a new one.")
            DebugLog.log("viewModel.paste ERROR: cryptographyFailed (rotated/lost KEK)", category: "paste")
            return false
        } catch SecretsVaultError.authenticationFailed {
            statusMessage = L("Authentication failed — try again.")
            DebugLog.log("viewModel.paste ERROR: authenticationFailed", category: "paste")
            return false
        } catch {
            statusMessage = "\(L("Failed to paste")): \(error)"
            DebugLog.log("viewModel.paste ERROR: \(error)", category: "paste")
            return false
        }
    }

    /// Prompts for / opens the Accessibility settings so the user can enable auto-paste.
    public func enableAutoPaste() {
        SystemPaster.promptForAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reveals a secret's plaintext (Touch ID enforced by the vault). Returns nil on failure.
    public func reveal(_ id: UUID) async -> String? {
        do {
            return try await engine.reveal(id)
        } catch {
            statusMessage = "\(L("Failed to reveal")): \(error)"
            return nil
        }
    }

    public func togglePin(_ row: ClipRow) async {
        do {
            if row.pinned { try await engine.unpin(row.id) } else { try await engine.pin(row.id) }
            await refresh()
        } catch {
            statusMessage = "\(L("Failed to change pin")): \(error)"
        }
    }

    public func remove(_ id: UUID) async {
        do {
            try await engine.remove(id)
            await refresh()
        } catch {
            statusMessage = "\(L("Failed to delete")): \(error)"
        }
    }

    public func clearUnpinned() async {
        do {
            try await engine.clearUnpinned()
            await refresh()
        } catch {
            statusMessage = "\(L("Failed to clear")): \(error)"
        }
    }

    /// Preview-generates a password (nothing stored yet).
    public func generate(_ mode: PasswordMode) async {
        do {
            lastGenerated = try await engine.generatePassword(mode)
            statusMessage = nil
        } catch {
            lastGenerated = nil
            statusMessage = "\(L("Generator error")): \(error)"
        }
    }

    /// One-shot for the panel's single button: generate a password from `mode`, store it
    /// as a secret in history, and write it to the clipboard (auto-clearing). No preview
    /// step — the generated value lands straight on the clipboard.
    public func generateAndUse(_ mode: PasswordMode) async {
        do {
            let generated = try await engine.generatePassword(mode)
            try await engine.useGeneratedPassword(generated)
            await refresh()
            statusMessage = L("Password in the clipboard (auto-clear).")
        } catch {
            statusMessage = "\(L("Failed to generate password")): \(error)"
        }
    }

    /// "Uses" the last generated password: stored as a secret + written to the clipboard.
    public func useGenerated() async {
        guard let generated = lastGenerated else { return }
        do {
            try await engine.useGeneratedPassword(generated)
            await refresh()
            statusMessage = L("Password in the clipboard (auto-clear).")
        } catch {
            statusMessage = "\(L("Failed to use password")): \(error)"
        }
    }
}
