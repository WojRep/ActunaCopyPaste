import AppKit
import ActunaCopyPasteUI

// Entry point for the FULL (Developer-ID, non-sandboxed) build. Builds the full
// adapter set and runs as a menu-bar accessory agent.

let app = NSApplication.shared

let controller: AppController
do {
    controller = AppController(composition: try CompositionBuilder.makeFull())
} catch {
    NSLog("Actuna CopyPaste (Full) failed to start: \(error)")
    exit(1)
}

// NSApplication.delegate is weak — keep `controller` alive via this global binding.
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
