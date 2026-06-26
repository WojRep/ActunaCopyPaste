import Testing
import CoreGraphics
@testable import ActunaCopyPasteUI

/// Pure flag-match / mapping tests for the gesture chord. The `GestureTrigger`
/// CGEventTap itself is a thin platform shim verified manually (like
/// `CarbonHotKeyTrigger`), so only `MouseChord` is unit-tested here.
@Suite("MouseChord")
struct MouseChordTests {
    @Test("Default gesture is Control + right-click")
    func defaultChord() {
        #expect(MouseChord.default.button == .right)
        #expect(MouseChord.default.modifiers == [.control])
        #expect(MouseChord.default.downEventType == .rightMouseDown)
        #expect(MouseChord.default.requiredFlags == .maskControl)
    }

    @Test("Matches exactly the required modifier")
    func matchesExact() {
        let chord = MouseChord.default
        #expect(chord.matches(eventFlags: .maskControl))
    }

    @Test("Ignores caps-lock / numeric-pad / device bits")
    func ignoresIrrelevantBits() {
        let chord = MouseChord.default
        let noisy: CGEventFlags = [.maskControl, .maskAlphaShift, .maskNumericPad]
        #expect(chord.matches(eventFlags: noisy))
    }

    @Test("Does not match when an extra standard modifier is held")
    func rejectsExtraModifier() {
        let chord = MouseChord.default
        #expect(!chord.matches(eventFlags: [.maskControl, .maskShift]))
    }

    @Test("Does not match when the required modifier is absent")
    func rejectsMissingModifier() {
        let chord = MouseChord.default
        #expect(!chord.matches(eventFlags: []))
        #expect(!chord.matches(eventFlags: .maskCommand))
    }

    @Test("Multi-modifier chord maps to the OR of its flags and the right down-event")
    func multiModifier() {
        let chord = MouseChord(button: .right, modifiers: [.command, .control])
        #expect(chord.requiredFlags == [.maskCommand, .maskControl])
        #expect(chord.matches(eventFlags: [.maskCommand, .maskControl]))
        #expect(!chord.matches(eventFlags: .maskControl))
        #expect(chord.downEventType == .rightMouseDown)
    }

    @Test("Button maps to its CoreGraphics down-event type")
    func buttonMapping() {
        #expect(MouseChord(button: .left, modifiers: []).downEventType == .leftMouseDown)
        #expect(MouseChord(button: .center, modifiers: []).downEventType == .otherMouseDown)
    }
}
