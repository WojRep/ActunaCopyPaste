import Foundation

/// Optional features, toggled per build. The shipping (Developer-ID) build enables
/// everything via `.full`; the struct stays so the wiring and tests can express a
/// build with the gesture tap disabled (e.g. a future sandboxed variant).
public struct CapabilitySet: Sendable, Equatable {
    /// Modifier+right-click gesture trigger (needs a CGEventTap / Accessibility).
    public var gestureTrigger: Bool
    /// Detecting whether the focused field is a secure/password field (Accessibility).
    public var secureFieldDetection: Bool
    /// End-to-end cross-device sync.
    public var sync: Bool

    public init(gestureTrigger: Bool, secureFieldDetection: Bool, sync: Bool) {
        self.gestureTrigger = gestureTrigger
        self.secureFieldDetection = secureFieldDetection
        self.sync = sync
    }

    /// The shipping Developer-ID build: everything available.
    public static let full = CapabilitySet(gestureTrigger: true, secureFieldDetection: true, sync: true)
}

/// Description of the currently focused UI element in the frontmost app.
public struct FocusedFieldInfo: Sendable, Equatable {
    /// `true`/`false` if positively determined; `nil` when unknown (sandboxed
    /// build, or apps that don't expose `AXSecureTextField`, e.g. some web/Electron).
    public let isSecureField: Bool?
    public let appBundleID: String?

    public init(isSecureField: Bool?, appBundleID: String?) {
        self.isSecureField = isSecureField
        self.appBundleID = appBundleID
    }
}

/// How a secret may be used.
public enum SecretAccess: Sendable, Equatable {
    /// Reveal plaintext on screen — always requires biometric authentication.
    case reveal
    /// Paste into the focused field without displaying — allowed without reveal
    /// only when the target is known to be a secure field.
    case pasteWithoutReveal
}

public enum SecretsVaultError: Error, Equatable {
    case authenticationFailed
    case authenticationUnavailable
    case notFound
    case cryptographyFailed
}

/// Encrypts/decrypts secrets and gates plaintext access behind policy + biometrics.
/// Production adapter: Secure Enclave key wrapping a CryptoKit AES-GCM data key.
public protocol SecretsVaultPort: Sendable {
    /// Encrypts `plaintext`, returning a reference and a non-reversible preview.
    func store(plaintext: String, context: String, reason: SecretReason?) async throws -> Secret
    /// Reveals plaintext for on-screen display (always requires Touch ID).
    func reveal(_ ref: CiphertextRef) async throws -> String
    /// Decrypts for pasting without displaying. Policy: a positively-detected
    /// secure (password) field pastes with no prompt; any other / unknown target
    /// degrades to a biometric (Touch ID) gate before returning the plaintext.
    func decryptForPaste(_ ref: CiphertextRef, target: FocusedFieldInfo) async throws -> String
    /// Permanently removes the ciphertext.
    func purge(_ ref: CiphertextRef) async throws
}

/// Persists and reloads the clipboard history (production: SwiftData ModelContainer).
public protocol HistoryStorePort: Sendable {
    func load() async throws -> [ClipItem]
    func upsert(_ item: ClipItem) async throws
    func remove(id: UUID) async throws
    func replaceAll(_ items: [ClipItem]) async throws
}

/// Writes a clip to the system pasteboard and pastes it into the focused app
/// (write + synthesize ⌘V).
public protocol PastePort: Sendable {
    func paste(text: String, autoClearAfter seconds: TimeInterval?) async throws
}

/// Writes text to the system pasteboard WITHOUT synthesizing a paste — used when
/// a generated password should just "land in the clipboard" for the user to paste
/// wherever they like. `autoClearAfter` wipes the pasteboard after N seconds.
public protocol ClipboardWriterPort: Sendable {
    func write(_ text: String, autoClearAfter seconds: TimeInterval?) async throws
}

/// Reports the currently focused field (full build only; mini returns unknown).
public protocol FocusedFieldPort: Sendable {
    func currentField() -> FocusedFieldInfo
}

/// What invoked the history panel.
public enum TriggerSource: Sendable, Equatable {
    case hotKey
    case mouseGesture
}

/// Source of "show the panel" events (global hotkey and/or mouse gesture).
/// Methods are `async` because production adapters are run-loop / main-actor bound.
public protocol TriggerPort: Sendable {
    func start(onTrigger: @escaping @Sendable (TriggerSource) -> Void) async
    func stop() async
}

/// Observes the system pasteboard for new content (production: changeCount poll
/// + `detect*` classification, honoring nspasteboard markers).
public protocol PasteboardMonitorPort: Sendable {
    func start(onCapture: @escaping @Sendable (CapturedContent) -> Void) async
    func stop() async
}

/// Raw captured content handed from the monitor adapter to the domain.
public struct CapturedContent: Sendable, Equatable {
    public let kind: ClipKind
    public let text: String?
    public let resourceReference: String?
    public let label: String?
    public let sourceApp: String?
    public let markers: Set<PasteboardMarker>

    public init(
        kind: ClipKind,
        text: String?,
        resourceReference: String?,
        label: String?,
        sourceApp: String?,
        markers: Set<PasteboardMarker>
    ) {
        self.kind = kind
        self.text = text
        self.resourceReference = resourceReference
        self.label = label
        self.sourceApp = sourceApp
        self.markers = markers
    }
}
