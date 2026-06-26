import CoreGraphics

/// A modifier + mouse-button gesture that summons the picker (e.g. ⌃ + right-click),
/// expressed independently of the `CGEventTap` so the button/modifier mapping and the
/// flag-matching are pure and unit-testable — the mouse analogue of `KeyChord`.
/// `GestureTrigger` consumes `downEventType` (for the tap mask) and `matches(eventFlags:)`.
public struct MouseChord: Equatable, Sendable {
    /// The mouse button, kept framework-independent for a clean `Sendable` value type.
    public enum Button: Sendable, Hashable {
        case left
        case right
        case center
    }

    public let button: Button
    public let modifiers: Set<KeyModifier>

    public init(button: Button, modifiers: Set<KeyModifier>) {
        self.button = button
        self.modifiers = modifiers
    }

    /// Default summon gesture: ⌃ + right-click (Control is macOS's secondary-click
    /// modifier, so users already expect a menu there; we replace it with the picker).
    public static let `default` = MouseChord(button: .right, modifiers: [.control])

    /// The CoreGraphics event type for this button's "down" press (what we tap + consume).
    public var downEventType: CGEventType {
        switch button {
        case .left:   return .leftMouseDown
        case .right:  return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }

    /// The standard modifier flags this chord requires (cmd/shift/option/control only).
    public var requiredFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    /// The standard modifiers we compare on — everything else (caps-lock, numeric-pad,
    /// fn, and the device-dependent low-order bits CGEvent sets) is ignored.
    static let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    /// Pure: do the event's modifier flags EXACTLY match this chord's modifiers? Exact
    /// (not "contains") so ⌃+right-click fires but ⌃⇧+right-click does not — predictable.
    public func matches(eventFlags: CGEventFlags) -> Bool {
        eventFlags.intersection(MouseChord.relevantFlags) == requiredFlags
    }
}
