import AppKit

/// Non-activating floating panel anchored at the cursor. Can become key (so the
/// search field accepts typing) but never main (so the app we paste into keeps its
/// focus). Borderless + clear background for a popup look.
///
/// IMPORTANT for an LSUIElement accessory agent: `hidesOnDeactivate` must stay
/// `false` and `.transient` must NOT be in the collection behavior — the agent is
/// essentially never the "active" app, so either of those makes macOS hide the
/// panel the instant it is ordered front (i.e. it never visibly appears).
public final class HistoryPanel: NSPanel {
    /// Invoked when the user dismisses via Esc (the panel is borderless, so there is
    /// no close button — dismissal is Esc, click-outside, or the hotkey).
    var onUserDismiss: (() -> Void)?

    public init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// Esc routes here when nothing else consumes it.
    public override func cancelOperation(_ sender: Any?) {
        onUserDismiss?()
    }
}
