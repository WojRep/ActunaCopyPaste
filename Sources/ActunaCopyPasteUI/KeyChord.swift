/// A global-hotkey chord, expressed independently of Carbon so the keyCode +
/// modifier-mask mapping is pure and unit-testable. `CarbonHotKeyTrigger` consumes
/// `keyCode` and `carbonModifierMask` directly in `RegisterEventHotKey`.
public struct KeyChord: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: Set<KeyModifier>

    public init(keyCode: UInt32, modifiers: Set<KeyModifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// OR of the Carbon modifier bits for the chord's modifiers.
    public var carbonModifierMask: UInt32 {
        modifiers.reduce(0) { $0 | $1.carbonBit }
    }

    /// Default summon chord: ⌘⇧V (V is virtual key 0x09).
    public static let `default` = KeyChord(keyCode: 0x09, modifiers: [.command, .shift])
}

public enum KeyModifier: Sendable, Hashable {
    case command
    case shift
    case option
    case control

    /// Carbon `*Key` bit (from HIToolbox/Events.h): cmd=256, shift=512, opt=2048, ctrl=4096.
    public var carbonBit: UInt32 {
        switch self {
        case .command: return 256
        case .shift:   return 512
        case .option:  return 2048
        case .control: return 4096
        }
    }
}
