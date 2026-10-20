// Needs no clip: the face clips itself to the card's rounded corner (radius width * 0.12).
import ScopaCore
import SwiftUI

/// Burano's needle lace: the forty cards worked as lace panels on blu notte velvet, for the
/// album's ninth volume. A net-ground edging scalloped and picoted round every card, its
/// footing corded in the suit's thread; the numerals worked free in punto in aria and
/// held by brides; the courts in toile and réseau, every part cut clear of the next; the
/// settebello wheeled in gold on garnet.
///
/// Nothing is painted. Every piece is thread laid in one `Canvas`: toile in rows of
/// buttonhole stitch, a honeycomb of réseau, raised cords wrapped over, and the hard
/// shadow each casts on whatever lies under it.
struct MerlettoFace: View {
    let card: Card
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.clip(to: RoundedRectangle(cornerRadius: size.width * 0.12).path(in: bounds))
            MerlettoCard(card: card, pillow: MerlettoPillow(context: context, w: size.width)).work()
        }
        .frame(width: width, height: width * 1.5)
        .overlay { index }
        .overlay { index.rotationEffect(.degrees(180)) }
        .overlay { caption }
    }

    /// The rank in linen, raised off the velvet of its window over its own shadow.
    private var index: some View {
        let lift = max(0.4, width * 0.008)
        return ZStack {
            numeral.foregroundStyle(MerlettoThread.shadow).offset(x: lift, y: lift * 1.4)
            numeral.foregroundStyle(MerlettoThread.linen.face)
        }
        .frame(width: width, height: width * 1.5)
    }

    private var numeral: some View {
        let tablet = MerlettoBorder.tablet(card.rank)
        let inset = MerlettoBorder.tabletInset
        let centre = CGPoint(x: inset + tablet.width / 2, y: inset + tablet.height / 2)
        // A six and a nine read as each other upside down, so they get a rule under them.
        let ruled = card.rank == .six || card.rank == .knight
        return ZStack {
            Text(verbatim: card.rank.label)
                .font(.display(width * 0.24))
                .position(x: width * centre.x, y: width * (centre.y - (ruled ? 0.018 : 0.003)))
            if ruled {
                Rectangle()
                    .frame(width: width * 0.12, height: max(1, width * 0.017))
                    .position(x: width * centre.x, y: width * (centre.y + 0.092))
            }
        }
    }

    @ViewBuilder private var caption: some View {
        if card == .settebello && width >= 70 {
            Text(verbatim: "SETTEBELLO")
                .font(.system(size: width * 0.05, weight: .bold, design: .serif))
                .tracking(width * 0.006)
                .foregroundStyle(MerlettoThread.gold.face)
                .position(x: width * 0.5, y: width * MerlettoCard.cartoucheCentre)
                .frame(width: width, height: width * 1.5)
        }
    }
}

/// A suit in Merletto's own threads: the motif the cards work, mounted on a velvet cut
/// close round it, so it reads on a pale page as on the table.
struct MerlettoSuit: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let pillow = MerlettoPillow(context: context, w: canvas.width * 1.6, mount: 2.2)
            pillow.suit(suit, at: CGPoint(x: canvas.width / 2, y: canvas.height / 2), size: canvas.width * 0.84)
        }
        .frame(width: size, height: size)
    }
}
