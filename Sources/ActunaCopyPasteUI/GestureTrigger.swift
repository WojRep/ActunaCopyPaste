import Foundation
import CoreGraphics
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

/// Mouse-gesture `TriggerPort` via an active `CGEventTap` — summons the picker on
/// ⌃+right-click anywhere (full build only). An *active* tap (`.defaultTap`) is what
/// lets us CONSUME the matching right-click so the native context menu is suppressed
/// in favor of our picker; active taps require the Accessibility (TCC) grant, so if
/// it is missing `tapCreate` returns nil and we simply run hotkey-only (no crash).
///
/// The tap callback is delivered on the main run loop (we add the run-loop source from
/// `start`, which runs on the main actor), hence `@MainActor` and `assumeIsolated` in
/// the C trampoline — mirroring `CarbonHotKeyTrigger`. Not unit-tested (needs the real
/// tap + a physical click); the pure `MouseChord` matching it relies on is.
@MainActor
public final class GestureTrigger: TriggerPort {
    private let chord: MouseChord
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var callback: (@Sendable (TriggerSource) -> Void)?

    public init(chord: MouseChord = .default) {
        self.chord = chord
    }

    public func start(onTrigger: @escaping @Sendable (TriggerSource) -> Void) async {
        callback = onTrigger

        // Watch the chord's down-event plus the two "tap disabled" notifications so we
        // can re-enable a tap the system throttles (the single most important detail —
        // without re-enabling, the gesture silently dies after a slow callback).
        let mask: CGEventMask =
            (CGEventMask(1) << chord.downEventType.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue) |
            (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // Non-capturing closure → convertible to the C `CGEventTapCallBack`; `self` is
        // recovered from `userInfo` (Unmanaged round-trip, like CarbonHotKeyTrigger).
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let trigger = Unmanaged<GestureTrigger>.fromOpaque(userInfo).takeUnretainedValue()
                let consume = MainActor.assumeIsolated { trigger.handle(type: type, event: event) }
                return consume ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            DebugLog.log("GestureTrigger: tapCreate returned nil (Accessibility not granted?) — gesture disabled, hotkey still works", category: "gesture")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        // The main run loop processes input events and is where our @MainActor callback
        // belongs (CFRunLoopGetCurrent is unavailable from async contexts anyway).
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DebugLog.log("GestureTrigger: event tap installed for \(chord)", category: "gesture")
    }

    public func stop() async {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        eventTap = nil
        runLoopSource = nil
        callback = nil
    }

    /// Runs on the main actor (the tap callback's run loop). Returns `true` when the
    /// event should be consumed (suppressing the native menu for a matched gesture).
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        // The system disables a slow/over-budget tap; re-enable and pass through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            DebugLog.log("GestureTrigger: tap re-enabled after \(type)", category: "gesture")
            return false
        }
        guard type == chord.downEventType, chord.matches(eventFlags: event.flags) else {
            return false // not our gesture → let the normal click (and OS menu) through
        }
        fire()
        return true // our gesture → consume so the native context menu does not appear
    }

    private func fire() {
        callback?(.mouseGesture)
    }
}
