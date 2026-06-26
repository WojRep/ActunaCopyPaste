import Testing
@testable import ActunaCopyPasteUI
import ActunaCopyPasteCore

/// The trigger set is purely a function of the runtime `CapabilitySet`. Asserting the
/// pure mapping avoids constructing the SwiftData/Keychain-backed engine in tests.
@MainActor
@Suite("Composition capability gating")
struct CompositionCapabilityTests {
    private let noGesture = CapabilitySet(gestureTrigger: false, secureFieldDetection: false, sync: true)

    @Test("Shipping build (gesture enabled) installs the hotkey AND the gesture trigger")
    func fullHasGesture() {
        let triggers = CompositionBuilder.makeTriggers(for: .full)
        #expect(triggers.count == 2)
        #expect(triggers.contains { $0 is CarbonHotKeyTrigger })
        #expect(triggers.contains { $0 is GestureTrigger })
    }

    @Test("Gesture-disabled build installs only the hotkey (no event tap)")
    func hotkeyOnlyWhenGestureDisabled() {
        let triggers = CompositionBuilder.makeTriggers(for: noGesture)
        #expect(triggers.count == 1)
        #expect(triggers.contains { $0 is CarbonHotKeyTrigger })
        #expect(!triggers.contains { $0 is GestureTrigger })
    }
}
