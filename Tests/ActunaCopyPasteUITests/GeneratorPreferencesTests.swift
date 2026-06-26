import Testing
import Foundation
@testable import ActunaCopyPasteUI
import ActunaCopyPasteCore

@Suite("GeneratorPreferences")
struct GeneratorPreferencesTests {
    @Test("Default preferences map to a character mode with sane policy")
    func defaultMode() {
        guard case .characters(let policy) = GeneratorPreferences.default.mode else {
            Issue.record("expected character mode")
            return
        }
        #expect(policy.length == 20)
        #expect(policy.useLowercase && policy.useUppercase && policy.useDigits && policy.useSymbols)
        #expect(policy.excludeAmbiguous)
    }

    @Test("Passphrase preferences map to a passphrase mode")
    func passphraseMode() {
        var prefs = GeneratorPreferences.default
        prefs.usePassphrase = true
        prefs.wordCount = 6
        prefs.capitalize = true
        prefs.includeNumber = false
        guard case .passphrase(let policy) = prefs.mode else {
            Issue.record("expected passphrase mode")
            return
        }
        #expect(policy.wordCount == 6)
        #expect(policy.capitalize)
        #expect(!policy.includeNumber)
        #expect(policy.separator == "-")
    }

    @Test("Character toggles propagate into the policy")
    func characterToggles() {
        var prefs = GeneratorPreferences.default
        prefs.length = 32
        prefs.useSymbols = false
        prefs.excludeAmbiguous = false
        guard case .characters(let policy) = prefs.mode else {
            Issue.record("expected character mode")
            return
        }
        #expect(policy.length == 32)
        #expect(!policy.useSymbols)
        #expect(!policy.excludeAmbiguous)
    }

    @Test("Codable round-trips losslessly")
    func codableRoundTrip() throws {
        var prefs = GeneratorPreferences.default
        prefs.usePassphrase = true
        prefs.wordCount = 7
        prefs.length = 48
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(GeneratorPreferences.self, from: data)
        #expect(decoded == prefs)
    }
}

@MainActor
@Suite("GeneratorSettingsModel persistence")
struct GeneratorSettingsModelTests {
    private func makeDefaults() -> UserDefaults {
        // An isolated, in-memory suite so the test never touches the real app defaults.
        let suite = "test.generator.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("Loads defaults when nothing is stored")
    func loadsDefault() {
        let model = GeneratorSettingsModel(defaults: makeDefaults(), key: "k")
        #expect(model.preferences == .default)
    }

    @Test("Persists changes and reloads them in a fresh model")
    func persistsAndReloads() {
        let defaults = makeDefaults()
        let model = GeneratorSettingsModel(defaults: defaults, key: "k")
        model.preferences.usePassphrase = true
        model.preferences.wordCount = 8

        let reloaded = GeneratorSettingsModel(defaults: defaults, key: "k")
        #expect(reloaded.preferences.usePassphrase)
        #expect(reloaded.preferences.wordCount == 8)
        if case .passphrase(let policy) = reloaded.mode {
            #expect(policy.wordCount == 8)
        } else {
            Issue.record("expected passphrase mode after reload")
        }
    }
}
