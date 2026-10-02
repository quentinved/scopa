import StoreKit
import SwiftUI

/// The house asking, once in a long while, for a rating. Rating goes on to iOS's sheet;
/// later just closes it. Every answer that rates reaches Apple, so nothing is filtered.
///
/// `ReviewPrompt` decides when; the lobby lays it over the room on the way back from a win.
struct ReviewAskCard: View {
    let close: () -> Void

    @Environment(\.requestReview) private var requestReview
    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    /// Set a beat after the card arrives, so the stars are caught landing.
    @State private var landed = false

    var body: some View {
        VStack(spacing: 0) {
            Text("A WORD FROM THE HOUSE")
                .font(.system(size: 12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Palette.goldLight)
                .padding(.bottom, 18)
            stars
            asking
        }
        .padding(26)
        .frame(maxWidth: 380)
        .background { cardBackground }
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.7, bounce: 0.42)) { landed = true }
        }
    }

    private var stars: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.goldSheen)
                    .scaleEffect(landed ? 1 : 0.4)
                    .opacity(landed ? 1 : 0)
                    .animation(.spring(duration: 0.5, bounce: 0.5).delay(Double(index) * 0.06), value: landed)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background { Capsule().fill(felt.shade(0.5)) }
        .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1) }
        .padding(.bottom, 20)
    }

    private var asking: some View {
        VStack(spacing: 0) {
            words(title: "Enjoying Scopa?",
                  body: "That was a good long sitting. If the table treats you well, a few stars on the App Store help other players find it.")
            primary("Rate Scopa") { answer(.rated) }
            quiet("Later") { answer(.later) }
        }
    }

    private func answer(_ answer: ReviewPrompt.Answer) {
        ReviewPrompt.answered(answer)
        close()
        if answer == .rated { requestReview() }
    }

    // MARK: Pieces

    private func words(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.display(32))
                .foregroundStyle(Palette.onTable)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(body)
                .font(.system(size: 14.5))
                .foregroundStyle(Palette.onTableSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 22)
    }

    private func primary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { Capsule().fill(Palette.terracotta) }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }

    private func quiet(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(felt.plate(from: .top, to: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1.5)
            }
            .shadow(color: Palette.ink.opacity(0.4), radius: 30, y: 14)
    }
}

#Preview("Enjoying Scopa?") {
    ZStack {
        TableGround()
        ReviewAskCard {}
            .padding(20)
    }
}
