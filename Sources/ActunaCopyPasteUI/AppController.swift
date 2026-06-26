import AppKit
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

/// Drives the menu-bar agent lifecycle: accessory activation, history bootstrap,
/// the pasteboard-capture loop, the global hotkey, and the status item. The app
/// target's `main` builds a `Composition` and installs this as the app delegate.
///
/// The pasteboard monitor and the hotkey hand work back via `@Sendable` callbacks;
/// those are bridged through `AsyncStream` (Sendable continuations) so the
/// MainActor-isolated engine/UI work runs on consumer tasks without data races.
///
/// Diagnostics: every step is logged via `DebugLog` to
/// `~/Library/Logs/ActunaCopyPaste/debug.log`. With `ACTUNA_E2E=1` a file-driven
/// command channel (`/tmp/actuna-cmd.txt`) lets a test script drive the app headlessly.
@MainActor
public final class AppController: NSObject, NSApplicationDelegate {
    private let composition: CompositionBuilder.Composition
    private let viewModel: ClipboardViewModel
    private let panelController: HistoryPanelController
    private let settings: GeneratorSettingsModel
    private let settingsWindow: SettingsWindowController
    private let menuBar = MenuBarController()
    private var e2eTimer: Timer?

    public init(composition: CompositionBuilder.Composition) {
        self.composition = composition
        let model = ClipboardViewModel(engine: composition.engine)
        self.viewModel = model
        let settings = GeneratorSettingsModel()
        let settingsWindow = SettingsWindowController(settings: settings)
        self.settings = settings
        self.settingsWindow = settingsWindow
        self.panelController = HistoryPanelController(
            viewModel: model,
            onOpenSettings: { settingsWindow.show() },
            onGenerate: { Task { await model.generateAndUse(settings.mode) } },
            onAbout: { AppController.showAboutPanel() }
        )
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLog.reset()
        DebugLog.log("applicationDidFinishLaunching; canAutoPaste=\(SystemPaster.canAutoPaste) capabilities=\(composition.capabilities)")
        NSApp.setActivationPolicy(.accessory)

        promptForMissingPermissionsAtLaunch()

        menuBar.install(onClick: { [weak self] in
            DebugLog.log("status item clicked")
            self?.panelController.toggle(at: NSEvent.mouseLocation)
        })

        Task { [composition, viewModel] in
            do {
                try await composition.engine.bootstrap()
                await viewModel.refresh()
                DebugLog.log("bootstrap done; rows=\(viewModel.rows.count)")
            } catch {
                DebugLog.log("bootstrap FAILED: \(error)")
            }
        }

        startCaptureLoop()
        startTriggers()
        startE2EChannelIfEnabled()
    }

    /// Shows the standard macOS About panel (app icon, name, version, copyright) — the
    /// accessory agent must activate first so the panel comes forward. Version/copyright
    /// are read from the app bundle's Info.plist (CFBundleShortVersionString, …).
    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        let credits = NSAttributedString(
            string: "GPLv3 · github.com/WojRep/ActunaCopyPaste",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Actuna CopyPaste",
            .applicationVersion: version,
            .version: build,
            .credits: credits
        ])
    }

    public func applicationWillTerminate(_ notification: Notification) {
        let monitor = composition.monitor
        let triggers = composition.triggers
        Task {
            await monitor.stop()
            for trigger in triggers { await trigger.stop() }
        }
    }

    /// Auto-paste (PostEvent) is required so a picked item lands at the cursor; the
    /// gesture tap additionally needs Accessibility (full build). We probe both and
    /// prompt once when something required is missing. (The old "never prompt at launch"
    /// rule was a workaround for ad-hoc builds losing the grant; `Scripts/make-signing-cert.sh`
    /// now gives a stable signature so the grant persists and a one-time prompt no longer nags.)
    private func promptForMissingPermissionsAtLaunch() {
        let requirements = PermissionRequirements.forCapabilities(composition.capabilities)
        let postEvent = SystemPaster.canAutoPaste
        let axTrusted = SystemPaster.isAccessibilityTrusted
        DebugLog.log("launch permissions: postEvent=\(postEvent) ax=\(axTrusted) req=\(requirements)")
        guard PermissionPolicy.shouldPrompt(postEventGranted: postEvent, axTrusted: axTrusted, requirements: requirements) else { return }
        DebugLog.log("launch: required permission missing — prompting once")
        SystemPaster.promptForAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Pasteboard → engine.ingest → refresh, fed by the monitor's Sendable callback.
    private func startCaptureLoop() {
        let (stream, continuation) = AsyncStream.makeStream(of: CapturedContent.self)
        let monitor = composition.monitor
        Task { await monitor.start { content in continuation.yield(content) } }
        Task { [composition, viewModel] in
            for await content in stream {
                DebugLog.log("captured kind=\(content.kind) textLen=\(content.text?.count ?? 0)")
                _ = try? await composition.engine.ingest(content)
                await viewModel.refresh()
            }
        }
    }

    /// Every trigger (global hotkey ⌘⇧V, and on the full build the ⌃+right-click
    /// gesture) → toggle the panel at the cursor. `PanelAnchor` clamps to the screen
    /// containing the cursor, so a gesture on a second monitor is positioned correctly.
    private func startTriggers() {
        for trigger in composition.triggers {
            let (stream, continuation) = AsyncStream.makeStream(of: TriggerSource.self)
            Task { await trigger.start { source in continuation.yield(source) } }
            Task { [weak self] in
                for await source in stream {
                    DebugLog.log("trigger fired: \(source)")
                    self?.panelController.toggle(at: NSEvent.mouseLocation)
                }
            }
        }
    }

    // MARK: - E2E command channel (debug only)

    /// When `ACTUNA_E2E=1`, polls `/tmp/actuna-cmd.txt` for commands so a test script
    /// can drive the app: `show`, `hide`, `select:<substring>`, `state`.
    private func startE2EChannelIfEnabled() {
        let enabled = ProcessInfo.processInfo.environment["ACTUNA_E2E"] == "1"
            || FileManager.default.fileExists(atPath: "/tmp/actuna-e2e-on")
        guard enabled else { return }
        DebugLog.log("E2E channel enabled (watching /tmp/actuna-cmd.txt)", category: "e2e")
        let path = "/tmp/actuna-cmd.txt"
        try? FileManager.default.removeItem(atPath: path)
        e2eTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let command = try? String(contentsOfFile: path, encoding: .utf8),
                      !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return }
                try? FileManager.default.removeItem(atPath: path)
                Task { await self.handleE2ECommand(command.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
        }
    }

    private func handleE2ECommand(_ command: String) async {
        DebugLog.log("E2E command: \(command)", category: "e2e")
        await viewModel.refresh()
        switch command {
        case "show":
            panelController.show(at: NSEvent.mouseLocation)
        case "hide":
            panelController.hide()
        case "state":
            DebugLog.log("state: rows=\(viewModel.rows.count) autoPaste=\(viewModel.autoPasteAvailable)", category: "e2e")
        default:
            if command.hasPrefix("select:") {
                let needle = String(command.dropFirst("select:".count))
                if let row = viewModel.rows.first(where: { $0.displayText.contains(needle) }) {
                    DebugLog.log("E2E select matched id=\(row.id) text=\(row.displayText)", category: "e2e")
                    await viewModel.paste(row.id)
                } else {
                    DebugLog.log("E2E select: no row matching '\(needle)' (rows=\(viewModel.rows.map(\.displayText)))", category: "e2e")
                }
            } else {
                DebugLog.log("E2E unknown command: \(command)", category: "e2e")
            }
        }
    }
}
