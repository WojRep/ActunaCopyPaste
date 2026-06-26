import Foundation
import Observation
import ActunaCopyPasteCore

/// Observable holder for `GeneratorPreferences` that persists every change to
/// `UserDefaults` (JSON). The settings window edits it; the panel's generate button
/// reads `mode`. Thin glue — the pure mapping/round-trip lives in `GeneratorPreferences`.
@MainActor
@Observable
public final class GeneratorSettingsModel {
    public var preferences: GeneratorPreferences {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "generator.preferences.v1") {
        self.defaults = defaults
        self.key = key
        // didSet does not fire for assignments in init, so loading never re-persists.
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GeneratorPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = .default
        }
    }

    /// The `PasswordMode` the saved preferences describe.
    public var mode: PasswordMode { preferences.mode }

    private func persist() {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: key)
        }
    }
}
