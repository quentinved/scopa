import SwiftUI
import ScopaCore

/// One side's score in the top strip. Four of these share the strip with two buttons,
/// so the name shrinks inside its own box and the score is never compressed.
struct ScoreChip: View {
    var label: String?
    var badge: String?
    var tint: Color = Palette.terracotta
    let score: Int
    let emphasised: Bool
    /// Whether the chip carries its side's colour as a dot. Set at a table in teams, where
    /// the chip is the only place the two colours worn by four faces are named: without it
    /// the cloth says which pairs are pairs but not which pair is yours.
    var swatch = false

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(alignment: .center, spacing: label == nil ? 4 : 6) {
            if let badge { SeatBadge(name: badge, tint: tint, size: 17) }
            if swatch {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
                    .overlay { Circle().strokeBorder(Palette.cream.opacity(0.35), lineWidth: 0.5) }
            }
            if let label {
                Text(label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                    .frame(maxWidth: 92, alignment: .leading)
            }
            Text("\(score)")
                .font(.display(label == nil ? 19 : 22))
                // The total rolls up to the new score rather than blinking to it.
                .contentTransition(.numericText(value: Double(score)))
                .animation(.snappy(duration: 0.35), value: score)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(emphasised ? Palette.goldLight : Palette.onTable)
        .padding(.horizontal, label == nil ? 8 : 11)
        .padding(.vertical, label == nil ? 6 : 7)
        .glassPanel(radius: GlassRadius.chip, tint: emphasised ? felt.shade(0.92) : nil)
    }
}

/// How many times a seat has swept, as a broom and a number. Shaped after `PileCount`
/// so it does not read as a turn pill. Only drawn when there is a sweep to show.
struct SweepTally: View {
    let count: Int
    /// The broom's box. Sized against the card stack next to it, not the type.
    var width: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            BroomMark(size: width, tint: Palette.goldLight)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Palette.goldLight)
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: count)
        .transition(.scale.combined(with: .opacity))
    }
}

/// A few card backs fanned into a stack, with the count beside them.
struct PileCount: View {
    let count: Int
    var width: CGFloat
    var tint: Color = Palette.onTable

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                ForEach(0..<min(max(count, 1), 3), id: \.self) { index in
                    CardBack(width: width)
                        .rotationEffect(.degrees(Double(index) * 7 - 7))
                        .offset(x: CGFloat(index) * 2)
                }
            }
            .opacity(count == 0 ? 0.35 : 1)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(tint)
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: count)
    }
}

/// Your own take, counted beside the pile: how many cards came over, and whether one of
/// them was the seven of coins.
struct PilePop: Equatable, Identifiable {
    let id = UUID()
    let cards: Int
    let settebello: Bool
}

/// Your pile: the stack, the count, and a pop over it when cards arrive.
struct PileTag: View {
    let count: Int
    let teams: Bool
    let pop: PilePop?
    /// Off where the row is too narrow to say it: landscape gives the status row a third of
    /// the screen, and four seats leave the turn pill truncating to "Your t…" to pay for
    /// these two words. The stack and the count say the same thing without them, and the
    /// cards visibly fly into it.
    var showsLabel = true

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(spacing: 6) {
            PileCount(count: count, width: 14)
            Group {
                if showsLabel {
                    if teams { Text("taken by us") } else { Text("taken") }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassCapsule(tint: pop?.settebello == true ? Palette.gold.opacity(0.75) : nil)
        .scaleEffect(pop == nil ? 1 : 1.06)
        .overlay(alignment: .top) { if let pop { popLabel(pop) } }
        .animation(.spring(duration: 0.4, bounce: 0.35), value: pop)
    }

    private func popLabel(_ pop: PilePop) -> some View {
        HStack(spacing: 4) {
            if pop.settebello { Text("Settebello!") } else { Text("+\(pop.cards)") }
        }
        .font(.display(pop.settebello ? 18 : 20))
        .foregroundStyle(pop.settebello ? Palette.goldLight : Palette.cream)
        .shadow(color: felt.shade(0.6), radius: 4, y: 2)
        .offset(y: -26)
        .transition(.asymmetric(
            insertion: .offset(y: 14).combined(with: .opacity).combined(with: .scale(scale: 0.6)),
            removal: .offset(y: -10).combined(with: .opacity)
        ))
    }
}

/// The last move, in the corner of the cloth: who played, what they laid down, and what
/// went with it. The move itself is played out by `CardFlight`, this is only the record.
///
/// The player is their face rather than their name: the name is already on their chair
/// and in the turn pill.
struct LastMoveTag: View {
    let play: TableStore.Play
    let tint: Color
    /// Only VoiceOver hears it.
    let isMine: Bool
    /// Landscape, where everything on the cloth is drawn a size down.
    var compact = false

    /// Past four, the captures give way to a count.
    private static let shown = 4
    /// The played card is the tallest thing on the line, so it sets the tag's height.
    private static func card(compact: Bool) -> CGFloat { compact ? 20 : 23 }
    private static let padding: CGFloat = 7

    /// The height the cloth reserves for it above the cards.
    static func height(compact: Bool) -> CGFloat { card(compact: compact) * 1.5 + padding * 2 }

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(spacing: 7) {
            badge
            move
            if play.sweeps { BroomMark(size: 13, tint: Palette.goldLight) }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, Self.padding)
        .glassPanel(radius: GlassRadius.chip,
                    tint: play.tookSettebello ? Palette.goldDeep.opacity(0.8) : felt.shade(0.8))
        .shadow(color: felt.shade(0.4), radius: 10, y: 4)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private var badge: some View {
        PlayerBadge(name: play.name, isBot: play.isBot, tint: tint, size: compact ? 22 : 26,
                    mark: play.mark, honoured: play.isHonoured)
            .accessibilityLabel(isMine ? Text("You") : Text(play.name.shortName()))
    }

    private var move: some View {
        let width = Self.card(compact: compact)
        return HStack(spacing: 5) {
            CardView(card: play.card, width: width)
            if play.captures.isEmpty {
                Text("laid it down")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.onTableSoft)
                ForEach(play.captures.prefix(Self.shown)) { card in
                    CardView(card: card, width: width - 4)
                }
                if play.captures.count > Self.shown {
                    Text("+\(play.captures.count - Self.shown)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
        }
    }
}
