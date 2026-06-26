import Foundation
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

/// The composition root: wires the concrete native adapters into a `ClipboardEngine`.
/// `makeFull` assembles the shipping (Developer-ID) build; capabilities are expressed
/// via `CapabilitySet` so the trigger wiring stays testable.
public enum CompositionBuilder {

    /// Everything the app needs, assembled and ready to start.
    public struct Composition {
        public let engine: ClipboardEngine
        public let monitor: NSPasteboardMonitor
        public let capabilities: CapabilitySet
        /// Every "show the panel" source. With `gestureTrigger` enabled this adds the
        /// ⌃+right-click `GestureTrigger` alongside the Carbon hotkey; otherwise it is
        /// hotkey-only. Keeping the choice here makes `AppController` capability-agnostic.
        public let triggers: [any TriggerPort]
    }

    /// Pure mapping `CapabilitySet → trigger set` (no I/O), so the gating is unit-testable
    /// without building the whole engine. The trigger initializers only stash a chord; the
    /// OS work happens later in `start()`.
    @MainActor
    public static func makeTriggers(for capabilities: CapabilitySet) -> [any TriggerPort] {
        capabilities.gestureTrigger
            ? [CarbonHotKeyTrigger(), GestureTrigger()]
            : [CarbonHotKeyTrigger()]
    }

    @MainActor
    public static func makeFull() throws -> Composition { try make(capabilities: .full) }

    @MainActor
    private static func make(capabilities: CapabilitySet) throws -> Composition {
        // One SwiftData stack backs both history and the secrets vault.
        let (history, ciphertext) = try ActunaPersistence.makeStores(at: storeURL())

        // KEK: Secure Enclave when available, persisted in the Keychain so it
        // survives relaunch. Resilient: if the Keychain is unavailable (ad-hoc dev
        // build) the provisioner falls back to a session key so launch never blocks.
        let keyAgreement = try VaultKeyProvisioner(store: KeychainKeyStore())
            .make(preferSecureEnclave: true)
        let vault = EnvelopeVault(keyAgreement: keyAgreement, gate: LABiometricGate(), store: ciphertext)

        let engine = ClipboardEngine(
            capture: CaptureClipUseCase(classifier: SensitivityClassifier(), vault: vault, hashing: CryptoKitHashing()),
            generator: PasswordGenerator(randomness: SecureRandomness()),
            store: history,
            vault: vault,
            writer: NSPasteboardClipboardWriter(),
            paster: SystemPaster(restorePrevious: true),
            hashing: CryptoKitHashing(),
            autoClearSeconds: 30
        )

        return Composition(engine: engine, monitor: NSPasteboardMonitor(), capabilities: capabilities,
                           triggers: makeTriggers(for: capabilities))
    }

    /// `~/Library/Application Support/Actuna CopyPaste/store.sqlite` (inside the
    /// sandbox container for the mini build).
    private static func storeURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Actuna CopyPaste", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }
}
