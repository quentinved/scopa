import SwiftUI
import ScopaCore

/// Asked once, at the end of a first launch: a table that talks you through it, or a plain
/// one. Both are levels of the help setting, and the sheet says where that lives.
struct CoachChoiceSheet: View {
    /// A first hand is dealt as this closes, so the button says so.
    var dealsNext = false
    let onChoose: (AssistLevel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: AssistLevel?

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                    VStack(spacing: 12) {
                        ForEach([AssistLevel.coached, .normal], id: \.self) { level in
                            CoachChoiceCard(level: level, isPicked: picked == level) { picked = level }
                        }
                    }
                    whereToChange
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            confirm
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { TableGround() }
        .presentationDetents([.height(680)])
        .presentationDragIndicator(.hidden)
        // One tap answers it, and leaving it unanswered would leave the first hand unsure.
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: picked)
        .sound(.toggle, trigger: picked)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shall I sit beside you?")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
            Text("I can talk you through every hand, or leave you to the cards. Pick one, and change your mind whenever you like.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The exact way back to this choice, in the words the settings page uses.
    private var whereToChange: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
                .frame(width: 20)
                .padding(.top, 1)
            Text("To change it later, tap your name at the top of the lobby to open **Settings**, then **At the table › How much help you want**. Beginner sits in between: it outlines your takes, without the talk.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: GlassRadius.control)
    }

    private var confirm: some View {
        Button(dealsNext ? "Deal me a hand" : "Sit down", action: choose)
            .buttonStyle(FilledButtonStyle())
            .disabled(picked == nil)
            .opacity(picked == nil ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
    }

    private func choose() {
        guard let picked else { return }
        onChoose(picked)
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        CoachChoiceSheet(dealsNext: true) { _ in }
    }
}
