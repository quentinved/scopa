import SwiftUI

/// The stock count under the cloth, with Scatouch on: the count, and the mode's tag, which
/// opens the deck. The tag is also what says at a glance that this game is not a real one.
struct ScatouchStock: View {
    let scatouch: ScatouchTable
    let count: Int
    let lift: CGFloat
    /// Puts down any card picked up from the hand, which a swap may take out of it.
    let putDown: () -> Void

    @State private var showsDeck = false

    var body: some View {
        Button {
            putDown()
            showsDeck = true
        } label: {
            HStack(spacing: 6) {
                CardBack(width: 14 * lift)
                Text("\(count) left")
                tag
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows every card still to come")
        .sensoryFeedback(Haptic.pick, trigger: showsDeck)
        .sheet(isPresented: $showsDeck) { ScatouchDeckSheet(scatouch: scatouch) }
        .task { await openForScreenshot() }
    }

    private var tag: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(verbatim: "Scatouch")
                .font(.system(size: 11, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(Palette.cream)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .glassCapsule(tint: Palette.terracotta.opacity(0.85))
    }

    /// `-scatouchDeck`: a beat after the table has dealt, or the sheet is refused.
    private func openForScreenshot() async {
        #if DEBUG
        guard DebugLaunch.opensScatouchDeck else { return }
        try? await Task.sleep(for: .seconds(1.5))
        showsDeck = true
        #endif
    }
}
