import SwiftUI
import ActunaCopyPasteCore

/// History list with search. A single click (or the paste button) pastes a row;
/// secrets show a masked preview with a Reveal (Touch ID) action.
struct HistoryView: View {
    @Bindable var viewModel: ClipboardViewModel
    let onPaste: (UUID) -> Void
    @State private var revealed: [UUID: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            TextField(L("Search…"), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.searchText) { Task { await viewModel.refresh() } }
                .padding(8)

            Divider()

            if viewModel.rows.isEmpty {
                ContentUnavailableView(L("No items"), systemImage: "clipboard")
                    .frame(maxHeight: .infinity)
            } else {
                List(viewModel.rows) { row in
                    ClipRowView(
                        row: row,
                        revealedText: revealed[row.id],
                        onPaste: { onPaste(row.id) },
                        onReveal: { Task { revealed[row.id] = await viewModel.reveal(row.id) } },
                        onTogglePin: { Task { await viewModel.togglePin(row) } },
                        onRemove: { Task { await viewModel.remove(row.id) } }
                    )
                }
                .listStyle(.inset)
            }

            if let status = viewModel.statusMessage {
                Divider()
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
    }
}

private struct ClipRowView: View {
    let row: ClipRow
    let revealedText: String?
    let onPaste: () -> Void
    let onReveal: () -> Void
    let onTogglePin: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(row.isSecret ? Color.orange : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(revealedText ?? row.displayText)
                    .lineLimit(1)
                    .font(row.isSecret ? .system(.body, design: .monospaced) : .body)
                if let context = row.secretContext {
                    Text(context)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if row.isSecret {
                Button(action: onReveal) { Image(systemName: "eye") }
                    .buttonStyle(.borderless)
                    .help(L("Reveal (Touch ID)"))
            }
            Button(action: onTogglePin) { Image(systemName: row.pinned ? "pin.fill" : "pin") }
                .buttonStyle(.borderless)
                .help(row.pinned ? L("Unpin") : L("Pin"))
            Button(action: onRemove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help(L("Delete"))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPaste)
        .contextMenu {
            Button(L("Paste"), action: onPaste)
            Button(row.pinned ? L("Unpin") : L("Pin"), action: onTogglePin)
            Button(L("Delete"), role: .destructive, action: onRemove)
        }
    }

    private var icon: String {
        if row.isSecret { return "key.fill" }
        switch row.kind {
        case .image: return "photo"
        case .file: return "doc"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "text.alignleft"
        }
    }
}
