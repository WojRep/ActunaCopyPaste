import SwiftUI
import AppKit

/// Root content of the panel: the saved-clipboard/passwords list, a gear that opens
/// the generator settings (separate window), and a single "Generuj i zapisz" button.
/// All generator options live behind the gear; this window keeps just the one button.
struct PanelRootView: View {
    @Bindable var viewModel: ClipboardViewModel
    let onPaste: (UUID) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onGenerate: () -> Void
    let onAbout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Actuna CopyPaste")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onAbout) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help(L("About Actuna CopyPaste"))
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help(L("Password generator settings"))
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if !viewModel.autoPasteAvailable {
                Button {
                    viewModel.enableAutoPaste()
                } label: {
                    Label(L("Enable auto-paste (Accessibility)"), systemImage: "exclamationmark.shield")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .help(L("Without it, the item is only copied — press ⌘V manually."))
            }

            Divider()

            HistoryView(viewModel: viewModel, onPaste: onPaste)

            Divider()

            Button(action: onGenerate) {
                Label(L("Generate and save password"), systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(8)
            .help(L("Generates a password from the settings (⚙️) and copies it to the clipboard (auto-clear)"))

            Divider()

            HStack {
                Button {
                    Task { await viewModel.clearUnpinned() }
                } label: {
                    Label(L("Clear"), systemImage: "trash")
                }
                .help(L("Remove unpinned items"))

                Spacer()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(L("Quit"), systemImage: "power")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .padding(8)
        }
        .frame(width: 360, height: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand(perform: onClose) // Esc closes the panel
    }
}
