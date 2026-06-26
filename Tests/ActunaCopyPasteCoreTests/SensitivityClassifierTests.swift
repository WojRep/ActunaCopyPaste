import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("SensitivityClassifier")
struct SensitivityClassifierTests {
    let sut = SensitivityClassifier()

    // MARK: - Markers take priority

    @Test("Transient marker wins and signals discard")
    func transientMarker() {
        let result = sut.classify(markers: [.transient, .concealed], content: "whatever")
        #expect(result == .transient)
        #expect(result.shouldDiscard)
    }

    @Test("Concealed marker is sensitive")
    func concealedMarker() {
        let result = sut.classify(markers: [.concealed], content: "hunter2")
        #expect(result == .concealedByMarker)
        #expect(result.isSensitive)
    }

    @Test("No markers, ordinary text is normal")
    func ordinaryText() {
        let result = sut.classify(markers: [], content: "Hello, world — meeting at 10am")
        #expect(result == .normal)
        #expect(!result.isSensitive)
    }

    // MARK: - Heuristics

    @Test("Detects private key blocks")
    func privateKey() {
        let pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIabc...\n-----END RSA PRIVATE KEY-----"
        #expect(sut.classify(markers: [], content: pem) == .detectedSecret(reason: .privateKey))
    }

    @Test("Detects JWTs")
    func jwt() {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dQw4w9WgXcQ"
        #expect(sut.classify(markers: [], content: token) == .detectedSecret(reason: .jwt))
    }

    @Test("Detects known API key prefixes", arguments: [
        "sk_live_abcdefghijklmnop",
        "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
        "AKIAIOSFODNN7EXAMPLE",
        "xoxb-123456789012-abcdefghijkl"
    ])
    func apiKeys(_ key: String) {
        #expect(sut.classify(markers: [], content: key) == .detectedSecret(reason: .apiKey))
    }

    @Test("Detects credit cards via Luhn")
    func creditCard() {
        // Valid Visa test number (passes Luhn)
        #expect(sut.classify(markers: [], content: "4111 1111 1111 1111") == .detectedSecret(reason: .creditCard))
        #expect(sut.classify(markers: [], content: "4012-8888-8888-1881") == .detectedSecret(reason: .creditCard))
    }

    @Test("Rejects digit strings that fail Luhn")
    func notACreditCard() {
        #expect(sut.classify(markers: [], content: "1234 5678 9012 3456") != .detectedSecret(reason: .creditCard))
    }

    @Test("Detects high-entropy tokens without a known prefix")
    func highEntropy() {
        let token = "G7x!q2Lp9Zr4Vt8Wm1Ke6Bn3Yc5Df0Hs"
        #expect(sut.classify(markers: [], content: token) == .detectedSecret(reason: .highEntropy))
    }

    @Test("Short or low-entropy tokens stay normal")
    func notHighEntropy() {
        #expect(sut.classify(markers: [], content: "aaaaaaaaaaaaaaaaaaaaaaaa") == .normal)
        #expect(sut.classify(markers: [], content: "short") == .normal)
    }

    @Test("A normal sentence is not flagged as a secret")
    func sentenceNotSecret() {
        let text = "Please review the pull request before the standup tomorrow morning."
        #expect(sut.classify(markers: [], content: text) == .normal)
    }

    // MARK: - Building blocks

    @Test("Luhn validates a known-good number")
    func luhnValid() {
        #expect(sut.luhnIsValid("4111111111111111"))
        #expect(!sut.luhnIsValid("4111111111111112"))
    }
}
