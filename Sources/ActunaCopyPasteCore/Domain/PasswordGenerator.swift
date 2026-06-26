import Foundation

/// Pure domain service that produces strong passwords.
///
/// All randomness flows through `RandomnessPort`, so the same source yields the
/// same password — which makes the generator fully testable under TDD.
public struct PasswordGenerator: Sendable {
    private let randomness: RandomnessPort
    private let wordlist: [String]

    public init(randomness: RandomnessPort, wordlist: [String] = PasswordGenerator.defaultWordlist) {
        self.randomness = randomness
        self.wordlist = wordlist
    }

    public func generate(_ mode: PasswordMode) throws -> GeneratedPassword {
        switch mode {
        case .characters(let policy):
            return try generateCharacters(policy)
        case .passphrase(let policy):
            return try generatePassphrase(policy)
        }
    }

    // MARK: - Character mode

    private func generateCharacters(_ policy: CharacterPolicy) throws -> GeneratedPassword {
        let classes = policy.classes
        guard !classes.isEmpty else { throw PasswordGeneratorError.noCharacterClassesSelected }
        guard policy.length >= 1 else { throw PasswordGeneratorError.invalidLength }
        // Need room for at least one character from each required class.
        guard policy.length >= classes.count else { throw PasswordGeneratorError.invalidLength }

        let alphabet = classes.flatMap { $0 }

        var chosen: [Character] = []
        // Guarantee class coverage: one mandatory character per enabled class.
        for charClass in classes {
            chosen.append(charClass[randomness.uniformIndex(upperBound: charClass.count)])
        }
        // Fill the remainder from the full alphabet.
        while chosen.count < policy.length {
            chosen.append(alphabet[randomness.uniformIndex(upperBound: alphabet.count)])
        }
        // Shuffle so mandatory characters aren't always at the front.
        let value = String(randomness.shuffled(chosen))

        let entropy = Double(policy.length) * log2(Double(alphabet.count))
        return GeneratedPassword(value: value, entropyBits: entropy, mode: .characters(policy))
    }

    // MARK: - Passphrase mode

    private func generatePassphrase(_ policy: PassphrasePolicy) throws -> GeneratedPassword {
        guard policy.wordCount >= 1 else { throw PasswordGeneratorError.invalidWordCount }
        guard !wordlist.isEmpty else { throw PasswordGeneratorError.emptyWordlist }

        var words: [String] = []
        for _ in 0..<policy.wordCount {
            var word = wordlist[randomness.uniformIndex(upperBound: wordlist.count)]
            if policy.capitalize { word = word.capitalized }
            words.append(word)
        }

        if policy.includeNumber {
            let idx = randomness.uniformIndex(upperBound: words.count)
            let digit = randomness.uniformIndex(upperBound: 10)
            words[idx] += String(digit)
        }

        let value = words.joined(separator: policy.separator)

        var entropy = Double(policy.wordCount) * log2(Double(wordlist.count))
        if policy.includeNumber { entropy += log2(10.0) + log2(Double(policy.wordCount)) }
        return GeneratedPassword(value: value, entropyBits: entropy, mode: .passphrase(policy))
    }
}
