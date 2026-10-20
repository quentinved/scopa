// Needs no clip: the face clips itself to the card's rounded corner (radius width * 0.12).
import ScopaCore
import SwiftUI

/// Sorrento's inlaid wood: the forty cards set as marquetry panels, for the album's eighth
/// volume. Walnut cross-banding and a string of ebony and box round every card; numerals on
/// a book-matched maple field, courts cut in light woods against rosewood, the settebello's
/// coins on an ebony oval strung in brass and pearl.
///
/// Nothing is painted. Every piece is a veneer laid in one `Canvas`, with a few seeded lines
/// of grain, a sand-scorched edge where it turns away, and its kerf.
struct IntarsioFace: View {
    let card: Card
    let width: CGFloat

    private var isSettebello: Bool { card == .settebello }

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.clip(to: RoundedRectangle(cornerRadius: size.width * 0.12).path(in: bounds))
            IntarsioCard(card: self.card, panel: IntarsioPanel(context: context, w: size.width,
                                                              seed: Self.seed(self.card))).inlay()
        }
        .frame(width: width, height: width * 1.5)
        .overlay { index }
        .overlay { index.rotationEffect(.degrees(180)) }
        .overlay { caption }
    }

    private static func seed(_ card: Card) -> UInt64 {
        UInt64(Suit.allCases.firstIndex(of: card.suit) ?? 0) * 16 + UInt64(card.rank.rawValue)
    }

    /// The rank in ebony, on a court's box tablet or straight on the maple.
    private var index: some View {
        let tablet = IntarsioFrame.tablet(card.rank)
        let centre = card.rank.isFace
            ? CGPoint(x: 0.094 + tablet.width / 2, y: 0.094 + tablet.height / 2)
            : CGPoint(x: 0.19, y: 0.215)
        // A six and a nine read as each other upside down, so they get a rule under them.
        let ruled = card.rank == .six || card.rank == .knight
        return ZStack {
            Text(verbatim: card.rank.label)
                .font(.display(width * 0.26))
                .foregroundStyle(IntarsioWood.ebony.face)
                .position(x: width * centre.x, y: width * (centre.y - (ruled ? 0.025 : 0.005)))
            if ruled {
                Rectangle()
                    .fill(IntarsioWood.ebony.face)
                    .frame(width: width * 0.13, height: max(1, width * 0.018))
                    .position(x: width * centre.x, y: width * (centre.y + 0.098))
            }
        }
        .frame(width: width, height: width * 1.5)
    }

    @ViewBuilder private var caption: some View {
        if isSettebello && width >= 70 {
            Text(verbatim: "SETTEBELLO")
                .font(.system(size: width * 0.054, weight: .bold, design: .serif))
                .tracking(width * 0.006)
                .foregroundStyle(IntarsioWood.ebony.face)
                .position(x: width * 0.5, y: width * IntarsioCard.cartoucheCentre)
                .frame(width: width, height: width * 1.5)
        }
    }
}

/// A suit in Intarsio's own woods, cut the way the cards cut it.
struct IntarsioSuit: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let panel = IntarsioPanel(context: context, w: canvas.width * 1.6, seed: 91)
            panel.suit(suit, at: CGPoint(x: canvas.width / 2, y: canvas.height / 2), size: canvas.width * 0.94)
        }
        .frame(width: size, height: size)
    }
}
