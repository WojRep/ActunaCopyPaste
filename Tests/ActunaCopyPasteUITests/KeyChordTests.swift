import Testing
@testable import ActunaCopyPasteUI

@Suite("KeyChord")
struct KeyChordTests {
    @Test("Default chord is ⌘⇧V")
    func defaultChord() {
        #expect(KeyChord.default.keyCode == 0x09)
        #expect(KeyChord.default.carbonModifierMask == 256 | 512) // cmd | shift
    }

    @Test("Carbon modifier mask ORs the modifier bits")
    func modifierMask() {
        let chord = KeyChord(keyCode: 0x31, modifiers: [.command, .option, .control])
        #expect(chord.carbonModifierMask == 256 | 2048 | 4096)
    }

    @Test("No modifiers yields a zero mask")
    func noModifiers() {
        #expect(KeyChord(keyCode: 0x00, modifiers: []).carbonModifierMask == 0)
    }
}
