import AppKit
import SwiftUI

/// Hosts the password-generator settings in a standard, titled macOS window opened
/// from the panel's gear. The app is an accessory (no Dock icon), so we activate it
/// (`NSApp.activate`) before showing the window so it comes forward and is interactive.
/// The window is reused across opens (`isReleasedWhenClosed = false`).
@MainActor
public final class SettingsWindowController {
    private let settings: GeneratorSettingsModel
    private var window: NSWindow?

    public init(settings: GeneratorSettingsModel) {
        self.settings = settings
    }

    public func show() {
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            created.title = L("Password generator settings")
            created.isReleasedWhenClosed = false
            created.center()
            created.contentView = NSHostingView(rootView: GeneratorSettingsView(settings: settings))
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
