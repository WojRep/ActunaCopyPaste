import AppKit
import SwiftUI
import ActunaCopyPastePlatform

/// Owns the `HistoryPanel`, hosts the SwiftUI content, and positions it at the
/// cursor via the pure `PanelAnchor` math. `orderFrontRegardless()` is used because
/// an accessory app cannot rely on normal activation.
///
/// Dismissal (the panel is borderless, no close button): the hotkey toggles it, Esc
/// closes it (`HistoryPanel.cancelOperation`), and a global mouse monitor closes it
/// when the user clicks any OTHER app.
@MainActor
public final class HistoryPanelController {
    private let viewModel: ClipboardViewModel
    private let onOpenSettings: () -> Void
    private let onGenerate: () -> Void
    private let onAbout: () -> Void
    private var panel: HistoryPanel?
    private var outsideClickMonitor: Any?
    private let panelSize = CGSize(width: 360, height: 460)
    /// Delay between hiding the panel and posting the synthetic ⌘V, giving the
    /// previously-focused app time to become frontmost again so the paste lands there.
    private static let pasteFocusDelayNanos: UInt64 = 120_000_000 // 120 ms

    public init(
        viewModel: ClipboardViewModel,
        onOpenSettings: @escaping () -> Void,
        onGenerate: @escaping () -> Void,
        onAbout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
        self.onGenerate = onGenerate
        self.onAbout = onAbout
    }

    public func toggle(at mouse: CGPoint) {
        if let panel, panel.isVisible {
            hide()
        } else {
            show(at: mouse)
        }
    }

    public func show(at mouse: CGPoint) {
        present(at: mouse)
    }

    public func hide() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        panel?.orderOut(nil)
    }

    private func present(at mouse: CGPoint) {
        let panel = ensurePanel()
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }?.frame
            ?? NSScreen.main?.frame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = PanelAnchor.anchoredFrame(panelSize: panelSize, mouse: mouse, screen: screen)
        panel.setFrame(frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installOutsideClickMonitor()
        DebugLog.log("panel present frame=\(NSStringFromRect(frame)) visible=\(panel.isVisible) key=\(panel.isKeyWindow)", category: "panel")
        Task { await viewModel.refresh() }
    }

    private func ensurePanel() -> HistoryPanel {
        if let panel { return panel }
        let created = HistoryPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        created.onUserDismiss = { [weak self] in self?.hide() }
        let root = PanelRootView(
            viewModel: viewModel,
            onPaste: { [weak self] id in self?.pasteAndHide(id) },
            onClose: { [weak self] in self?.hide() },
            onOpenSettings: { [weak self] in
                // Close the panel first so the settings window is unobstructed and frontmost.
                self?.hide()
                self?.onOpenSettings()
            },
            onGenerate: { [weak self] in self?.onGenerate() },
            onAbout: { [weak self] in self?.onAbout() }
        )
        created.contentView = NSHostingView(rootView: root)
        panel = created
        return created
    }

    /// Closes the panel when the user clicks any other app (global mouse monitor —
    /// fires only for events delivered outside our process, so clicks inside the
    /// panel don't dismiss it). No accessibility permission needed for mouse events.
    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func pasteAndHide(_ id: UUID) {
        // Hide first so the previously focused app regains key/focus, then paste.
        DebugLog.log("row clicked → pasteAndHide id=\(id) autoPaste=\(viewModel.autoPasteAvailable)", category: "panel")
        hide()
        Task { [weak self] in
            guard let self else { return }
            // Small delay so the target app is frontmost again before the synthetic
            // ⌘V is posted (otherwise it could be delivered to nothing).
            try? await Task.sleep(nanoseconds: Self.pasteFocusDelayNanos)
            let pasted = await self.viewModel.paste(id)
            if !pasted {
                // Failed before any keystroke (e.g. an undecryptable secret) — re-show the
                // panel so its status message explains why instead of failing silently.
                self.present(at: NSEvent.mouseLocation)
            }
        }
    }
}
