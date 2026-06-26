import ActunaCopyPasteCore

/// User-editable password-generation preferences, persisted between launches. A pure
/// `Codable` value type so the `PasswordMode` mapping (and JSON round-trip) is unit-
/// testable; `GeneratorSettingsModel` owns the persistence. The settings live behind
/// the panel's gear; the panel's single "Generuj i zapisz" button generates from `mode`.
public struct GeneratorPreferences: Codable, Equatable, Sendable {
    public var usePassphrase: Bool
    // Character policy
    public var length: Int
    public var useLowercase: Bool
    public var useUppercase: Bool
    public var useDigits: Bool
    public var useSymbols: Bool
    public var excludeAmbiguous: Bool
    // Passphrase policy
    public var wordCount: Int
    public var capitalize: Bool
    public var includeNumber: Bool

    public init(
        usePassphrase: Bool = false,
        length: Int = 20,
        useLowercase: Bool = true,
        useUppercase: Bool = true,
        useDigits: Bool = true,
        useSymbols: Bool = true,
        excludeAmbiguous: Bool = true,
        wordCount: Int = 5,
        capitalize: Bool = false,
        includeNumber: Bool = true
    ) {
        self.usePassphrase = usePassphrase
        self.length = length
        self.useLowercase = useLowercase
        self.useUppercase = useUppercase
        self.useDigits = useDigits
        self.useSymbols = useSymbols
        self.excludeAmbiguous = excludeAmbiguous
        self.wordCount = wordCount
        self.capitalize = capitalize
        self.includeNumber = includeNumber
    }

    public static let `default` = GeneratorPreferences()

    /// The `PasswordMode` these preferences describe (consumed by the generator).
    public var mode: PasswordMode {
        if usePassphrase {
            return .passphrase(PassphrasePolicy(
                wordCount: wordCount,
                separator: "-",
                capitalize: capitalize,
                includeNumber: includeNumber
            ))
        }
        return .characters(CharacterPolicy(
            length: length,
            useLowercase: useLowercase,
            useUppercase: useUppercase,
            useDigits: useDigits,
            useSymbols: useSymbols,
            excludeAmbiguous: excludeAmbiguous
        ))
    }
}
