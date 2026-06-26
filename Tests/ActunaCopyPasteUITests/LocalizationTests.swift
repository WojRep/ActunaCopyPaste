import Testing
import Foundation
@testable import ActunaCopyPasteUI

/// Verifies the four shipped localizations (en/pl/de/es) resolve from the module's
/// resource bundle and that no key is missing in a non-base language (a missing key
/// would silently fall back to English at runtime).
@Suite("Localization")
struct LocalizationTests {
    private func lproj(_ lang: String) throws -> Bundle {
        let path = try #require(uiBundle.path(forResource: lang, ofType: "lproj"),
                                "missing \(lang).lproj in the module bundle")
        return try #require(Bundle(path: path))
    }

    @Test("'Clear' is translated per language")
    func clearTranslations() throws {
        let expected = ["en": "Clear", "pl": "Wyczyść", "de": "Löschen", "es": "Borrar"]
        for (lang, value) in expected {
            let resolved = try lproj(lang).localizedString(forKey: "Clear", value: "∅", table: nil)
            #expect(resolved == value, "Clear[\(lang)] resolved to '\(resolved)'")
        }
    }

    @Test("pl/de/es define every key the English base defines")
    func noMissingKeys() throws {
        let en = try lproj("en")
        // The base table's keys: read en.lproj's Localizable.strings as the source of truth.
        let enURL = try #require(en.url(forResource: "Localizable", withExtension: "strings"))
        let baseKeys = try #require(NSDictionary(contentsOf: enURL) as? [String: String]).keys
        #expect(baseKeys.count >= 35) // sanity: the table is populated

        for lang in ["pl", "de", "es"] {
            let bundle = try lproj(lang)
            for key in baseKeys {
                let resolved = bundle.localizedString(forKey: key, value: "∅MISSING∅", table: nil)
                #expect(resolved != "∅MISSING∅", "\(lang) is missing key: \(key)")
            }
        }
    }

    @Test("L() resolves through the module bundle without crashing")
    func helperResolves() {
        #expect(!L("Quit").isEmpty)
        #expect(!L("Generate and save password").isEmpty)
    }
}
