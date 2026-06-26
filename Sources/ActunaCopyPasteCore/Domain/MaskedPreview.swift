import Foundation

/// A non-reversible, display-only preview of a sensitive value.
///
/// Computed once from the plaintext at capture time and then stored alongside
/// the ciphertext. Rendering the history afterwards uses only this value object;
/// the plaintext is never touched again until an explicit, authorized reveal.
///
/// Example: `"ab••••yz"` with context `"24 chars · API key"`.
public struct MaskedPreview: Sendable, Equatable, Hashable {
    /// Ready-to-display masked string, e.g. `"ab••••yz"`.
    public let masked: String
    /// Leading characters left visible (may be empty for short secrets).
    public let visiblePrefix: String
    /// Trailing characters left visible (may be empty for short secrets).
    public let visibleSuffix: String
    /// Number of characters hidden behind the mask (the true length minus the
    /// visible edges). Exposed so the UI can describe the secret truthfully.
    public let hiddenCount: Int
    /// Human-readable context, e.g. `"24 chars · API key"`.
    public let context: String

    public init(masked: String, visiblePrefix: String, visibleSuffix: String, hiddenCount: Int, context: String) {
        self.masked = masked
        self.visiblePrefix = visiblePrefix
        self.visibleSuffix = visibleSuffix
        self.hiddenCount = hiddenCount
        self.context = context
    }

    /// Bullet glyph used in the masked rendering.
    public static let bullet: Character = "\u{2022}" // •
    /// Maximum bullets rendered, regardless of true hidden length (UI tidiness).
    public static let maxBullets = 8

    /// Builds a preview from plaintext, revealing at most `visibleEdge` characters
    /// on each side while always hiding at least 4 characters. Secrets of length
    /// `<= 4` are fully masked so nothing leaks.
    public static func make(from plaintext: String, visibleEdge: Int = 2, context: String) -> MaskedPreview {
        let characters = Array(plaintext)
        let length = characters.count

        // Largest symmetric edge that still keeps >= 4 characters hidden.
        let maxEachSide = max(0, (length - 4) / 2)
        let edge = max(0, min(visibleEdge, maxEachSide))

        let prefix = edge > 0 ? String(characters.prefix(edge)) : ""
        let suffix = edge > 0 ? String(characters.suffix(edge)) : ""
        let hidden = length - (2 * edge)

        let bulletCount = min(max(hidden, 0), maxBullets)
        let bullets = String(repeating: bullet, count: bulletCount)
        let masked = prefix + bullets + suffix

        return MaskedPreview(
            masked: masked,
            visiblePrefix: prefix,
            visibleSuffix: suffix,
            hiddenCount: max(hidden, 0),
            context: context
        )
    }
}
