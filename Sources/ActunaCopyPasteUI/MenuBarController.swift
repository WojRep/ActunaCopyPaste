import AppKit

/// Menu-bar status item for the accessory (LSUIElement) agent. A click on the icon
/// directly toggles the history panel (immediate, discoverable feedback); the panel
/// itself hosts the generator tab and the Clear/Quit actions, so no separate
/// `NSMenu` is needed.
@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var onClick: (() -> Void)?

    public func install(onClick: @escaping () -> Void) {
        self.onClick = onClick
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Actuna CopyPaste")
            image?.isTemplate = true
            button.image = image
            button.toolTip = L("Actuna CopyPaste — click or ⌘⇧V")
            button.target = self
            button.action = #selector(buttonClicked)
        }
        statusItem = item
    }

    @objc private func buttonClicked() {
        onClick?()
    }
}
