import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("CryptoKitHashing")
struct CryptoKitHashingTests {

    @Test("Matches the SHA-256 NIST test vector for \"abc\"")
    func knownVector() {
        let hashing = CryptoKitHashing()
        #expect(hashing.hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Is deterministic")
    func deterministic() {
        let hashing = CryptoKitHashing()
        #expect(hashing.hash("clipboard") == hashing.hash("clipboard"))
    }

    @Test("Different inputs produce different hashes")
    func distinct() {
        let hashing = CryptoKitHashing()
        #expect(hashing.hash("alpha") != hashing.hash("beta"))
    }

    @Test("Conforms to the ContentHashing port")
    func conformsToPort() {
        let hashing: any ContentHashing = CryptoKitHashing()
        #expect(hashing.hash("x").count == 64) // 32 bytes hex-encoded
    }
}
