import SwiftUI

/// The one question a first launch asks: what to call you. Nearby tables are named after
/// their host, so two phones both called Player cannot tell each other apart.
struct NameSheet: View {
    @Bindable var store: TableStore

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading
            nameField
            Button("Sit down", action: sitDown)
                .buttonStyle(FilledButtonStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { TableGround() }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .onAppear { isTyping = true }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What should we call you?")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
            Text("Your name at the table, and how friends find your table nearby.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        HStack(spacing: 12) {
            SeatBadge(name: trimmed.isEmpty ? "?" : trimmed, tint: Palette.seat(0), size: 40)
                .animation(.snappy, value: trimmed.isEmpty)
            TextField("", text: $draft, prompt: Text("Name").foregroundStyle(Palette.onTableSoft))
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isTyping)
                .onSubmit(sitDown)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(radius: GlassRadius.control)
    }

    private func sitDown() {
        guard !trimmed.isEmpty else { return }
        store.playerName = trimmed
        dismiss()
    }
}
