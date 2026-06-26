import Foundation

/// Which generation strategy to use.
public enum PasswordMode: Sendable, Equatable {
    case characters(CharacterPolicy)
    case passphrase(PassphrasePolicy)
}

/// Rules for random-character passwords.
public struct CharacterPolicy: Sendable, Equatable {
    public var length: Int
    public var useLowercase: Bool
    public var useUppercase: Bool
    public var useDigits: Bool
    public var useSymbols: Bool
    /// Remove visually ambiguous characters (I, l, 1, O, 0, o).
    public var excludeAmbiguous: Bool

    public init(
        length: Int = 20,
        useLowercase: Bool = true,
        useUppercase: Bool = true,
        useDigits: Bool = true,
        useSymbols: Bool = true,
        excludeAmbiguous: Bool = true
    ) {
        self.length = length
        self.useLowercase = useLowercase
        self.useUppercase = useUppercase
        self.useDigits = useDigits
        self.useSymbols = useSymbols
        self.excludeAmbiguous = excludeAmbiguous
    }

    static let ambiguous: Set<Character> = ["I", "l", "1", "O", "0", "o"]

    /// The enabled character classes, each already filtered for ambiguity.
    var classes: [[Character]] {
        var result: [[Character]] = []
        func add(_ chars: String) {
            var arr = Array(chars)
            if excludeAmbiguous { arr.removeAll { CharacterPolicy.ambiguous.contains($0) } }
            if !arr.isEmpty { result.append(arr) }
        }
        if useLowercase { add("abcdefghijklmnopqrstuvwxyz") }
        if useUppercase { add("ABCDEFGHIJKLMNOPQRSTUVWXYZ") }
        if useDigits { add("0123456789") }
        if useSymbols { add("!@#$%^&*()-_=+[]{};:,.?/") }
        return result
    }
}

/// Rules for word-based passphrases (diceware-style).
public struct PassphrasePolicy: Sendable, Equatable {
    public var wordCount: Int
    public var separator: String
    public var capitalize: Bool
    /// Append a random digit to one random word for extra entropy.
    public var includeNumber: Bool

    public init(
        wordCount: Int = 5,
        separator: String = "-",
        capitalize: Bool = false,
        includeNumber: Bool = false
    ) {
        self.wordCount = wordCount
        self.separator = separator
        self.capitalize = capitalize
        self.includeNumber = includeNumber
    }
}

/// A generated password together with its estimated strength.
public struct GeneratedPassword: Sendable, Equatable {
    public let value: String
    /// Estimated entropy (upper bound: `log2(space) * count`).
    public let entropyBits: Double
    public let mode: PasswordMode

    public init(value: String, entropyBits: Double, mode: PasswordMode) {
        self.value = value
        self.entropyBits = entropyBits
        self.mode = mode
    }
}

public enum PasswordGeneratorError: Error, Equatable {
    case noCharacterClassesSelected
    case invalidLength
    case invalidWordCount
    case emptyWordlist
}
