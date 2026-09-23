import SwiftUI
import ScopaCore

/// The table as it is currently dressed: real cards on the real felt under the real seat mark.
/// Drawn large enough that the deck's drawing can be told apart, which a swatch cannot show.
struct TableHero: View {
    let theme: CardTheme
    let felt: TableFelt
    let tapis: Tapis
    let back: CardBackPattern
    let name: String
    let mark: SeatMark
    let cornice: Cornice
    /// The colour the mark is struck in.
    var livery: SeatLivery = .tavolo
    let companion: Companion

    /// The settebello, a court card for the drawing, and a plain card for the pips.
    private static let hand: [Card] = [
        .settebello, Card(.king, of: .cups), Card(.three, of: .swords),
    ]

    var body: some View {
        ZStack {
            ground
            VStack(spacing: 14) {
                fan
                caption
            }
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GlassRadius.panel, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            SeatBadge(name: name, tint: Palette.seat(0), size: 38, mark: mark, cornice: cornice,
                      livery: livery)
                .padding(14)
        }
        // Opposite the seat mark, and away from the caption at the bottom.
        .overlay(alignment: .topTrailing) {
            CompanionView(companion: companion, size: 46, mood: .watching)
                .padding(.trailing, 14)
                .padding(.top, 10)
        }
        .shadow(color: felt.shade(0.5), radius: 14, y: 8)
    }

    private var fan: some View {
        HStack(spacing: -14) {
            ForEach(Array(Self.hand.enumerated()), id: \.element) { index, card in
                CardView(card: card, width: 62)
                    .rotationEffect(.degrees(Double(index - 2) * 4 + 2))
                    .offset(y: abs(Double(index) - 1.5) * 4)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
            }
            CardBack(width: 62)
                .rotationEffect(.degrees(10))
                .offset(y: 6)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        }
        .environment(\.cardTheme, theme)
        .environment(\.cardBack, back)
    }

    /// The felt, lit the way the table lights it.
    private var ground: some View {
        ZStack {
            LinearGradient(colors: [felt.light, felt.base, felt.deep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Palette.gold.opacity(0.18), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 190)
            // Half scale: the hero is about half a screen wide, so a border sewn for a
            // phone would have its corners off the end of it.
            TapisWeave(tapis: tapis, scale: 0.55)
        }
    }

    /// The names of the drawing, the colourway, the felt and the cloth.
    private var caption: some View {
        HStack(spacing: 6) {
            Text(verbatim: theme.style.title)
            Text(verbatim: "·").opacity(0.5)
            Text(verbatim: theme.skin.title)
            Text("on").opacity(0.5)
            Text(verbatim: felt.title)
            if tapis != .liscio {
                Text(verbatim: "·").opacity(0.5)
                Text(verbatim: tapis.title)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.onTable.opacity(0.85))
        // Four names can be wider than a small phone, so the capsule shrinks to hold them.
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.22)))
        .padding(.horizontal, 14)
    }
}
