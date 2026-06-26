import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("PasswordGenerator")
struct PasswordGeneratorTests {

    // MARK: - Character mode

    @Test("Character password has the requested length")
    func characterLength() throws {
        let gen = PasswordGenerator(randomness: SequenceRandomness(seed: [3, 7, 11, 19, 23, 29, 31, 37]))
        let pw = try gen.generate(.characters(CharacterPolicy(length: 24)))
        #expect(pw.value.count == 24)
    }

    @Test("All enabled character classes are represented")
    func classCoverage() throws {
        let gen = PasswordGenerator(randomness: SequenceRandomness(seed: [1, 2, 3, 4, 5, 6, 7, 8, 9]))
        let policy = CharacterPolicy(length: 16, useLowercase: true, useUppercase: true,
                                     useDigits: true, useSymbols: true, excludeAmbiguous: true)
        let pw = try gen.generate(.characters(policy))
        #expect(pw.value.contains { $0.isLowercase })
        #expect(pw.value.contains { $0.isUppercase })
        #expect(pw.value.contains { $0.isNumber })
        #expect(pw.value.contains { "!@#$%^&*()-_=+[]{};:,.?/".contains($0) })
    }

    @Test("Ambiguous characters are excluded from the alphabet")
    func excludesAmbiguous() {
        let policy = CharacterPolicy(excludeAmbiguous: true)
        let alphabet = Set(policy.classes.flatMap { $0 })
        #expect(alphabet.isDisjoint(with: CharacterPolicy.ambiguous))
    }

    @Test("Entropy equals length * log2(alphabet size)")
    func entropyCharacters() throws {
        let gen = PasswordGenerator(randomness: SequenceRandomness.zeros)
        // lower(24) + upper(24) + digits(8) + symbols(24) = 80 with ambiguity excluded
        let pw = try gen.generate(.characters(CharacterPolicy(length: 20)))
        let expected = 20.0 * log2(80.0)
        #expect(abs(pw.entropyBits - expected) < 1e-9)
    }

    @Test("Same randomness seed yields the same password (deterministic)")
    func deterministic() throws {
        let seed: [UInt8] = [9, 17, 4, 200, 13, 88, 250, 1, 42, 7]
        let a = try PasswordGenerator(randomness: SequenceRandomness(seed: seed))
            .generate(.characters(CharacterPolicy(length: 18)))
        let b = try PasswordGenerator(randomness: SequenceRandomness(seed: seed))
            .generate(.characters(CharacterPolicy(length: 18)))
        #expect(a.value == b.value)
    }

    @Test("No character classes selected throws")
    func noClasses() {
        let gen = PasswordGenerator(randomness: SequenceRandomness.zeros)
        let policy = CharacterPolicy(length: 10, useLowercase: false, useUppercase: false,
                                     useDigits: false, useSymbols: false)
        #expect(throws: PasswordGeneratorError.noCharacterClassesSelected) {
            try gen.generate(.characters(policy))
        }
    }

    @Test("Length smaller than required class count throws")
    func tooShortForCoverage() {
        let gen = PasswordGenerator(randomness: SequenceRandomness.zeros)
        // 4 classes enabled but length 3 cannot cover all of them
        let policy = CharacterPolicy(length: 3)
        #expect(throws: PasswordGeneratorError.invalidLength) {
            try gen.generate(.characters(policy))
        }
    }

    // MARK: - Passphrase mode

    @Test("Passphrase has the requested number of words")
    func passphraseWordCount() throws {
        let gen = PasswordGenerator(randomness: SequenceRandomness(seed: [5, 90, 33, 12, 7, 44, 2, 88]))
        let pw = try gen.generate(.passphrase(PassphrasePolicy(wordCount: 5, separator: "-")))
        #expect(pw.value.split(separator: "-").count == 5)
    }

    @Test("Passphrase entropy equals words * log2(wordlist size)")
    func passphraseEntropy() throws {
        let words = ["alpha", "bravo", "charlie", "delta"]
        let gen = PasswordGenerator(randomness: SequenceRandomness.zeros, wordlist: words)
        let pw = try gen.generate(.passphrase(PassphrasePolicy(wordCount: 6, includeNumber: false)))
        let expected = 6.0 * log2(4.0)
        #expect(abs(pw.entropyBits - expected) < 1e-9)
    }

    @Test("includeNumber injects a digit into the passphrase")
    func passphraseNumber() throws {
        let words = ["alpha", "bravo", "charlie"]
        let gen = PasswordGenerator(randomness: SequenceRandomness(seed: [2, 9, 4, 6, 1, 7, 3, 8]),
                                    wordlist: words)
        let pw = try gen.generate(.passphrase(PassphrasePolicy(wordCount: 3, includeNumber: true)))
        #expect(pw.value.contains { $0.isNumber })
    }

    @Test("Empty wordlist throws for passphrase mode")
    func emptyWordlist() {
        let gen = PasswordGenerator(randomness: SequenceRandomness.zeros, wordlist: [])
        #expect(throws: PasswordGeneratorError.emptyWordlist) {
            try gen.generate(.passphrase(PassphrasePolicy()))
        }
    }

    @Test("Built-in wordlist is non-trivial")
    func builtinWordlist() {
        #expect(PasswordGenerator.defaultWordlist.count >= 200)
    }
}
