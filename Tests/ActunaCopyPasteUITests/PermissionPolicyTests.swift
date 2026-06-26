import Testing
@testable import ActunaCopyPasteUI
import ActunaCopyPasteCore

@Suite("PermissionPolicy")
struct PermissionPolicyTests {
    let full = PermissionRequirements.forCapabilities(.full)   // PostEvent + Accessibility
    // A build with the gesture tap disabled needs PostEvent only (no active CGEventTap).
    let noGesture = PermissionRequirements.forCapabilities(
        CapabilitySet(gestureTrigger: false, secureFieldDetection: false, sync: true)
    )

    @Test("Full requires both PostEvent and Accessibility")
    func fullRequirements() {
        #expect(full.needsPostEvent)
        #expect(full.needsAccessibility)
    }

    @Test("Gesture-disabled build requires PostEvent but not Accessibility")
    func noGestureRequirements() {
        #expect(noGesture.needsPostEvent)
        #expect(!noGesture.needsAccessibility)
    }

    @Test("Full: no prompt only when both permissions are granted")
    func fullBothGranted() {
        #expect(!PermissionPolicy.shouldPrompt(postEventGranted: true, axTrusted: true, requirements: full))
    }

    @Test("Full: prompt when PostEvent missing")
    func fullPostEventMissing() {
        #expect(PermissionPolicy.shouldPrompt(postEventGranted: false, axTrusted: true, requirements: full))
    }

    @Test("Full: prompt when Accessibility missing")
    func fullAccessibilityMissing() {
        #expect(PermissionPolicy.shouldPrompt(postEventGranted: true, axTrusted: false, requirements: full))
    }

    @Test("Full: prompt when both missing")
    func fullBothMissing() {
        #expect(PermissionPolicy.shouldPrompt(postEventGranted: false, axTrusted: false, requirements: full))
    }

    @Test("Gesture-disabled: no prompt when PostEvent granted, regardless of Accessibility")
    func noGesturePostEventGranted() {
        #expect(!PermissionPolicy.shouldPrompt(postEventGranted: true, axTrusted: false, requirements: noGesture))
        #expect(!PermissionPolicy.shouldPrompt(postEventGranted: true, axTrusted: true, requirements: noGesture))
    }

    @Test("Gesture-disabled: prompt when PostEvent missing")
    func noGesturePostEventMissing() {
        #expect(PermissionPolicy.shouldPrompt(postEventGranted: false, axTrusted: false, requirements: noGesture))
    }
}
