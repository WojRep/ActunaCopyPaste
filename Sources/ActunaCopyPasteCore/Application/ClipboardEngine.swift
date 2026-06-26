import Foundation

/// Application service that orchestrates the whole clipboard hexagon: ingest from
/// the pasteboard monitor, persist, query/search, pin, paste, reveal, and the
/// password generator → secure-clipboard flow. An `actor` guards the mutable
/// `ClipboardHistory`; all collaborators are injected ports, so the engine is
/// fully testable headlessly.
public actor ClipboardEngine {
    private var history: ClipboardHistory
    private let capture: CaptureClipUseCase
    private let generator: PasswordGenerator
    private let store: HistoryStorePort
    private let vault: SecretsVaultPort
    private let writer: ClipboardWriterPort
    private let paster: PastePort
    private let hashing: ContentHashing
    private let autoClearSeconds: TimeInterval?
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    public init(
        history: ClipboardHistory = ClipboardHistory(),
        capture: CaptureClipUseCase,
        generator: PasswordGenerator,
        store: HistoryStorePort,
        vault: SecretsVaultPort,
        writer: ClipboardWriterPort,
        paster: PastePort,
        hashing: ContentHashing,
        autoClearSeconds: TimeInterval? = 30,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.history = history
        self.capture = capture
        self.generator = generator
        self.store = store
        self.vault = vault
        self.writer = writer
        self.paster = paster
        self.hashing = hashing
        self.autoClearSeconds = autoClearSeconds
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Lifecycle

    /// Loads persisted items into the in-memory aggregate at startup.
    public func bootstrap() async throws {
        let persisted = try await store.load()
        for item in persisted { history.add(item) }
    }

    // MARK: - Queries

    public func snapshot() -> [ClipItem] { history.items }
    public func search(_ query: String) -> [ClipItem] { history.search(query) }

    // MARK: - Capture

    /// Ingests new pasteboard content; sensitive content is encrypted via the vault.
    @discardableResult
    public func ingest(_ content: CapturedContent) async throws -> ClipItem? {
        guard let item = try await capture.capture(content, id: makeID(), now: now()) else { return nil }
        history.add(item)
        try await store.upsert(item)
        return item
    }

    // MARK: - Curation

    public func pin(_ id: UUID) async throws { try await setPinned(id, true) }
    public func unpin(_ id: UUID) async throws { try await setPinned(id, false) }

    public func remove(_ id: UUID) async throws {
        if let item = history.item(withID: id), case .secret(let secret) = item.payload {
            try? await vault.purge(secret.ciphertext)
        }
        history.remove(id)
        try await store.remove(id: id)
    }

    public func clearUnpinned() async throws {
        for item in history.items where !item.pinned {
            if case .secret(let secret) = item.payload {
                try? await vault.purge(secret.ciphertext)
            }
        }
        history.clearUnpinned()
        try await store.replaceAll(history.items)
    }

    // MARK: - Secrets

    /// Reveals a secret's plaintext for on-screen display (vault enforces Touch ID).
    public func reveal(_ id: UUID) async throws -> String {
        guard let item = history.item(withID: id), case .secret(let secret) = item.payload else {
            throw SecretsVaultError.notFound
        }
        return try await vault.reveal(secret.ciphertext)
    }

    /// Pastes an item into the focused app. Secret plaintext never leaves the
    /// engine — it goes straight to the paste port. Pasting a secret into a
    /// non-secure field degrades to Touch ID (enforced by the vault).
    public func paste(_ id: UUID, into target: FocusedFieldInfo) async throws {
        guard let item = history.item(withID: id) else { throw SecretsVaultError.notFound }
        let text: String
        let isSecret: Bool
        switch item.payload {
        case .plain(let value):
            text = value; isSecret = false
        case .resource(let reference, _):
            text = reference; isSecret = false
        case .secret(let secret):
            text = try await vault.decryptForPaste(secret.ciphertext, target: target)
            isSecret = true
        }
        try await paster.paste(text: text, autoClearAfter: isSecret ? autoClearSeconds : nil)
    }

    // MARK: - Password generator

    /// Generates a password (preview step — nothing is stored yet).
    public func generatePassword(_ mode: PasswordMode) throws -> GeneratedPassword {
        try generator.generate(mode)
    }

    /// "Uses" a generated password: encrypts it as a secret, adds it to history,
    /// and writes it to the system clipboard (auto-clearing) so the user can paste.
    @discardableResult
    public func useGeneratedPassword(_ generated: GeneratedPassword) async throws -> ClipItem {
        let context = "\(generated.value.count) chars · generated password"
        let secret = try await vault.store(plaintext: generated.value, context: context, reason: nil)
        let item = ClipItem(
            id: makeID(),
            kind: .text,
            createdAt: now(),
            sourceApp: "Actuna CopyPaste",
            sensitivity: .concealedByMarker,
            payload: .secret(secret),
            contentHash: hashing.hash(generated.value)
        )
        history.add(item)
        try await store.upsert(item)
        try await writer.write(generated.value, autoClearAfter: autoClearSeconds)
        return item
    }

    // MARK: - Private

    private func setPinned(_ id: UUID, _ pinned: Bool) async throws {
        if pinned { history.pin(id) } else { history.unpin(id) }
        if let item = history.item(withID: id) {
            try await store.upsert(item)
        }
    }
}
