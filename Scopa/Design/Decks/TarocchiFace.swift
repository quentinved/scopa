// Needs no clip: the face clips itself to the card's rounded corner (radius width * 0.12).
import ScopaCore
import SwiftUI

/// The Visconti tarocchi of Milan, for the album's tenth and last volume: the forty cards
/// painted as the Bembo workshop painted its trumps. Courts stand full length on tooled
/// leaf, numerals lie on gesso among sprigs inside a punched band of gold, and the
/// settebello's coins lie on vermilion scratched back to the leaf in the pattern of a
/// Milanese velvet. A thin border of bole runs round them all.
///
/// Every shape is laid flat in tempera inside a fine dark line, in one `Canvas`. The gold
/// is a single warm colour: what makes it leaf is its tooling, never a sheen.
struct TarocchiFace: View {
    let card: Card
    let width: CGFloat

    private var isSettebello: Bool { card == .settebello }

    var body: some View {
        Canvas { context, size in
            context.clip(to: RoundedRectangle(cornerRadius: size.width * 0.12).path(in: CGRect(origin: .zero, size: size)))
            TarocchiCard(card: self.card, panel: TarocchiPanel(context: context, w: size.width)).paint()
        }
        .frame(width: width, height: width * 1.5)
        .overlay { index }
        .overlay { index.rotationEffect(.degrees(180)) }
        .overlay { caption }
    }

    /// The rank in sinopia, on a court's cartellino or straight on the gesso; in gesso on
    /// the settebello's vermilion.
    private var index: some View {
        let label = TarocchiFrame.cartellino(card.rank), inset = TarocchiFrame.cartellinoInset
        let centre = card.rank.isFace
            ? CGPoint(x: inset + label.width / 2, y: inset + label.height / 2)
            : CGPoint(x: 0.19, y: 0.215)
        let ink = isSettebello ? Tempera.gesso : Tempera.sinopia
        // A six and a nine read as each other upside down, so they get a rule under them.
        let ruled = card.rank == .six || card.rank == .knight
        return ZStack {
            Text(verbatim: card.rank.label)
                .font(.display(width * 0.26))
                .foregroundStyle(ink)
                .position(x: width * centre.x, y: width * (centre.y - (ruled ? 0.025 : 0.005)))
            if ruled {
                Rectangle()
                    .fill(ink)
                    .frame(width: width * 0.13, height: max(1, width * 0.018))
                    .position(x: width * centre.x, y: width * (centre.y + 0.098))
            }
        }
        .frame(width: width, height: width * 1.5)
    }

    @ViewBuilder private var caption: some View {
        if isSettebello && width >= 70 {
            Text(verbatim: "SETTEBELLO")
                .font(.system(size: width * 0.05, weight: .bold, design: .serif))
                .tracking(width * 0.005)
                .foregroundStyle(Tempera.sinopia)
                .position(x: width * 0.5, y: width * (TarocchiCard.banderole + 0.008))
                .frame(width: width, height: width * 1.5)
        }
    }
}

/// A suit in Tarocchi's own colours, painted the way the cards paint it.
struct TarocchiSuit: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let panel = TarocchiPanel(context: context, w: canvas.width * 1.6)
            panel.sign(suit, at: CGPoint(x: canvas.width / 2, y: canvas.height / 2), size: canvas.width * 0.94)
        }
        .frame(width: size, height: size)
    }
}
