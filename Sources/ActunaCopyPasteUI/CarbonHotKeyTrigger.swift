import Foundation
import Carbon.HIToolbox
import ActunaCopyPasteCore

/// Global-hotkey `TriggerPort` via Carbon `RegisterEventHotKey` — the only native
/// global-hotkey primitive that needs no TCC permission and works under the sandbox
/// (so both the full and mini builds can summon the panel). Carbon hotkey events
/// arrive on the main run loop, hence `@MainActor`.
///
/// Not unit-tested (requires the real Carbon event target + a key press); the pure
/// `KeyChord` mapping it relies on is. Verified manually in the app.
@MainActor
public final class CarbonHotKeyTrigger: TriggerPort {
    private let chord: KeyChord
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (@Sendable (TriggerSource) -> Void)?

    public init(chord: KeyChord = .default) {
        self.chord = chord
    }

    public func start(onTrigger: @escaping @Sendable (TriggerSource) -> Void) async {
        callback = onTrigger

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let trigger = Unmanaged<CarbonHotKeyTrigger>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { trigger.fire() }
            return noErr
        }, 1, &eventSpec, selfPtr, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x41435450), id: 1) // 'ACTP'
        var ref: EventHotKeyRef?
        RegisterEventHotKey(chord.keyCode, chord.carbonModifierMask, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
    }

    public func stop() async {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        callback = nil
    }

    private func fire() {
        callback?(.hotKey)
    }
}
