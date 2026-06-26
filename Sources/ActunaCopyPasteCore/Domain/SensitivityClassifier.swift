import Foundation

/// Pure domain service that decides how sensitive a captured item is.
///
/// Priority: source-app markers (cheap, authoritative, no content read) first,
/// then content heuristics as a fallback for apps that don't mark their data.
public struct SensitivityClassifier: Sendable {
    /// Minimum length for a single token to be considered for the entropy rule.
    public var highEntropyMinLength: Int
    /// Shannon-entropy-per-character threshold (bits) for the entropy rule.
    public var highEntropyBitsPerChar: Double

    public init(highEntropyMinLength: Int = 20, highEntropyBitsPerChar: Double = 3.5) {
        self.highEntropyMinLength = highEntropyMinLength
        self.highEntropyBitsPerChar = highEntropyBitsPerChar
    }

    public func classify(markers: Set<PasteboardMarker>, content: String?) -> SensitivityClassification {
        if markers.contains(.transient) { return .transient }
        if markers.contains(.concealed) { return .concealedByMarker }

        guard let content, !content.isEmpty else { return .normal }
        if let reason = detectSecret(in: content) {
            return .detectedSecret(reason: reason)
        }
        return .normal
    }

    // MARK: - Heuristics

    func detectSecret(in content: String) -> SecretReason? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isPrivateKeyBlock(trimmed) { return .privateKey }
        if isJWT(trimmed) { return .jwt }
        if hasKnownAPIKeyPrefix(trimmed) { return .apiKey }
        if isCreditCard(trimmed) { return .creditCard }
        if isHighEntropyToken(trimmed) { return .highEntropy }
        return nil
    }

    private func isPrivateKeyBlock(_ s: String) -> Bool {
        s.contains("-----BEGIN") && s.contains("PRIVATE KEY-----")
    }

    /// JWT: three base64url segments separated by dots, header begins `eyJ`.
    private func isJWT(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        guard s.hasPrefix("eyJ") else { return false }
        let base64url = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for part in parts where part.isEmpty || !part.unicodeScalars.allSatisfy({ base64url.contains($0) }) {
            return false
        }
        return true
    }

    /// Common provider key prefixes (Stripe, GitHub, AWS, Slack, Google, OpenAI…).
    private func hasKnownAPIKeyPrefix(_ s: String) -> Bool {
        guard !s.contains(where: { $0 == " " || $0 == "\n" }) else { return false }
        let prefixes = ["sk-", "sk_live_", "sk_test_", "pk_live_", "rk_live_",
                        "ghp_", "gho_", "ghu_", "ghs_", "github_pat_",
                        "AKIA", "ASIA", "xoxb-", "xoxp-", "xapp-",
                        "AIza", "ya29.", "glpat-", "shpat_", "npm_"]
        return prefixes.contains { s.hasPrefix($0) } && s.count >= 12
    }

    /// 13–19 digits (ignoring spaces/dashes) that satisfy the Luhn checksum.
    private func isCreditCard(_ s: String) -> Bool {
        let digitsAndSeparators = s.allSatisfy { $0.isNumber || $0 == " " || $0 == "-" }
        guard digitsAndSeparators else { return false }
        let digits = s.filter { $0.isNumber }
        guard (13...19).contains(digits.count) else { return false }
        return luhnIsValid(digits)
    }

    func luhnIsValid(_ digits: String) -> Bool {
        var sum = 0
        var double = false
        for char in digits.reversed() {
            guard let d = char.wholeNumberValue else { return false }
            var value = d
            if double {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
            double.toggle()
        }
        return sum % 10 == 0
    }

    /// A single long token with high per-character Shannon entropy — the generic
    /// fallback that catches unprefixed tokens, secrets, and random passwords.
    private func isHighEntropyToken(_ s: String) -> Bool {
        guard !s.contains(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) else { return false }
        guard s.count >= highEntropyMinLength else { return false }
        return shannonEntropyPerCharacter(s) >= highEntropyBitsPerChar
    }

    func shannonEntropyPerCharacter(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for ch in s { counts[ch, default: 0] += 1 }
        let n = Double(s.count)
        var entropy = 0.0
        for count in counts.values {
            let p = Double(count) / n
            entropy -= p * log2(p)
        }
        return entropy
    }
}
