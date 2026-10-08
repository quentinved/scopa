import SwiftUI
import ScopaCore

/// One of the two answers on the first launch's help question: a small hand as that level
/// draws it, the level's name as the settings print it, and what it does.
struct CoachChoiceCard: View {
    let level: AssistLevel
    let isPicked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                CoachChoiceHand(isCoached: level == .coached)
                    .frame(width: 104)
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.label)
                        .font(.display(22))
                        .foregroundStyle(Palette.onTable)
                    Text(tagline)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                        .textCase(.uppercase)
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .overlay(alignment: .topTrailing) { tick }
            .glassPanel(radius: GlassRadius.panel, tint: isPicked ? Palette.terracotta.opacity(0.55) : nil,
                        interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: GlassRadius.panel)
                    .strokeBorder(Palette.goldLight, lineWidth: isPicked ? 2 : 0)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isPicked)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    @ViewBuilder private var tick: some View {
        if isPicked {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.cream, Palette.terracotta)
                .padding(10)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var tagline: LocalizedStringKey {
        level == .coached ? "Best for a first game" : "For those who know Scopa"
    }

    private var line: LocalizedStringKey {
        level == .coached
            ? "I mark the card to play and the one that costs you, outline what each card can take, and say what the other side just did."
            : "A plain table, as in any bar in Naples: no marks, no outlines, no warning before a wrong take."
    }
}

/// Three cards in hand, drawn as the level draws them: the coach's marks and its strip of
/// advice under them, or nothing at all.
private struct CoachChoiceHand: View {
    let isCoached: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                card(Card(.four, of: .cups), mark: nil)
                card(.settebello, mark: .best)
                card(Card(.king, of: .swords), mark: .costly)
            }
            strip.opacity(isCoached ? 1 : 0)
        }
        .padding(.top, 6)
        .accessibilityHidden(true)
    }

    private func card(_ card: Card, mark: Coach.Standing?) -> some View {
        CardView(card: card, width: 30, outlined: isCoached && mark == .best)
            .overlay(alignment: .topTrailing) {
                if isCoached, let mark {
                    CoachMark(standing: mark)
                        .scaleEffect(0.75)
                        .offset(x: 7, y: -7)
                }
            }
    }

    /// The coach's strip, shrunk to its icon and two lines of nothing in particular.
    private var strip: some View {
        HStack(spacing: 5) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(Palette.onTable.opacity(0.7)).frame(width: 48, height: 3)
                Capsule().fill(Palette.onTableSoft.opacity(0.5)).frame(width: 34, height: 3)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .glassPanel(radius: 8)
    }
}
