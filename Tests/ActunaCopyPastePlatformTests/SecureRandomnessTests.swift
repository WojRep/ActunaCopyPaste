import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("SecureRandomness")
struct SecureRandomnessTests {

    @Test("Returns exactly the requested number of bytes")
    func count() {
        let rng = SecureRandomness()
        #expect(rng.randomBytes(count: 32).count == 32)
        #expect(rng.randomBytes(count: 1).count == 1)
        #expect(rng.randomBytes(count: 0).isEmpty)
    }

    @Test("Two large draws are not identical")
    func notConstant() {
        let rng = SecureRandomness()
        // Collision probability for 32 random bytes is ~2^-256.
        #expect(rng.randomBytes(count: 32) != rng.randomBytes(count: 32))
    }

    @Test("Drives the password generator with the real CSPRNG")
    func powersPasswordGenerator() throws {
        let gen = PasswordGenerator(randomness: SecureRandomness())
        let pw = try gen.generate(.characters(CharacterPolicy(length: 20)))
        #expect(pw.value.count == 20)
        #expect(pw.value.allSatisfy { !$0.isWhitespace })
        // Class coverage holds end-to-end with the real CSPRNG.
        #expect(pw.value.contains { $0.isLowercase })
        #expect(pw.value.contains { $0.isNumber })
    }

    @Test("Generates distinct passwords across calls")
    func distinctPasswords() throws {
        let gen = PasswordGenerator(randomness: SecureRandomness())
        let a = try gen.generate(.characters(CharacterPolicy(length: 24)))
        let b = try gen.generate(.characters(CharacterPolicy(length: 24)))
        #expect(a.value != b.value)
    }
}
