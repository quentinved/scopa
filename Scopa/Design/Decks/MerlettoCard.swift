import ScopaCore
import SwiftUI

/// What is worked where on one card: the velvet, the pips on their ground of brides or the
/// court, then the edging over the field's rim and the windows the index sits in.
struct MerlettoCard {
    let card: Card
    let pillow: MerlettoPillow

    private var w: CGFloat { pillow.w }
    private var border: MerlettoBorder { MerlettoBorder(pillow: pillow, card: card) }
    private var slender: Bool { card.suit == .swords || card.suit == .clubs }
    private var seed: UInt64 { UInt64(Suit.allCases.firstIndex(of: card.suit) ?? 0) * 16 + UInt64(card.rank.rawValue) }

    func work() {
        pillow.context.fill(Path(CGRect(x: 0, y: 0, width: w, height: w * 1.5)), with: .color(pillow.velvet))
        if card.rank.isFace {
            court()
        } else if card == .settebello {
            settebello()
        } else {
            pillow.brideGround(border.field, seed: seed)
            if card.rank == .ace { ace() } else { pips() }
        }
        border.work()
        border.tablets()
    }

    /// Cut to the field, so a hem runs under the scallops rather than over them.
    private func court() {
        let figure = pillow.clipped(to: border.field)
        switch card.rank {
        case .king: figure.king(card.suit)
        case .knight: figure.knight(card.suit)
        default: figure.knave(card.suit)
        }
    }

    /// The motifs worked on the brides, each cut clear of the ground round it.
    private func pips() {
        let area = CGRect(x: 0.20 * w, y: 0.28 * w, width: 0.60 * w, height: 0.94 * w)
        let (pip, centres) = IntarsioCard.layout(card.rank.rawValue, in: area)
        for centre in centres { pillow.suit(card.suit, at: centre, size: pip * (slender ? 1.16 : 1)) }
    }

    // MARK: Ace

    /// The ace's sign on an oval of réseau with a beaded rim.
    private func ace() {
        medallion(y: 0.75, rx: 0.335, ry: 0.475)
        pillow.suit(card.suit, at: pillow.p(0.5, 0.75), size: w * (slender ? 0.80 : 0.58))
    }

    private func medallion(y: CGFloat, rx: CGFloat, ry: CGFloat, gold: Bool = false) {
        let centre = pillow.p(0.5, y)
        if gold {
            pillow.part(pillow.oval(0.5, y, rx, ry))
            pillow.context.fill(pillow.oval(0.5, y, rx, ry), with: .color(MerlettoThread.garnet))
            var band = pillow.oval(0.5, y, rx, ry)
            band.addPath(pillow.oval(0.5, y, rx - 0.045, ry - 0.045))
            pillow.net(band, cell: 0.022, cord: .gold, parted: false, eo: true)
        } else {
            pillow.net(pillow.oval(0.5, y, rx, ry), cell: 0.028)
        }
        let (beads, tips) = pillow.beads(centre, rx * w, ry * w, count: gold ? 42 : 34, r: w * 0.021)
        pillow.toile(beads, rows: 0, parted: false)
        pillow.picots(tips, gold ? .gold : .linen, size: 0.9)
    }

    // MARK: Settebello

    /// The rarest card: seven coins corded in gold on a garnet medallion strung with gold
    /// brides, inside a band of réseau and a beaded rim, its name in a cartouche at its foot.
    private func settebello() {
        let y: CGFloat = 0.675
        pillow.brideGround(border.field, seed: seed)
        medallion(y: y, rx: 0.37, ry: 0.48, gold: true)
        let field = pillow.oval(0.5, y, 0.325, 0.435)
        let inner = pillow.clipped(to: field)
        let garnet = MerlettoPillow(context: inner.context, w: w, velvet: MerlettoThread.garnet)
        let area = CGRect(x: 0.22 * w, y: (y - 0.36) * w, width: 0.56 * w, height: 0.72 * w)
        let (pip, centres) = IntarsioCard.layout(7, in: area)
        let size = pip * 1.04
        if garnet.fine { garnet.brides(Self.links(centres, reach: size * 0.47, within: size * 1.75), .gold, weight: 0.5) }
        for centre in centres { garnet.suit(.coins, at: centre, size: size, rich: true) }
        if w >= 70 { cartouche() }
    }

    /// A bride from rim to rim between every two coins nearer than `within`.
    private static func links(_ centres: [CGPoint], reach: CGFloat, within: CGFloat) -> [(CGPoint, CGPoint)] {
        centres.indices.flatMap { i in
            centres[(i + 1)...].compactMap { b -> (CGPoint, CGPoint)? in
                let a = centres[i], gap = hypot(b.x - a.x, b.y - a.y)
                guard gap < within else { return nil }
                let (ux, uy) = ((b.x - a.x) / gap, (b.y - a.y) / gap)
                return (CGPoint(x: a.x + ux * reach, y: a.y + uy * reach), CGPoint(x: b.x - ux * reach, y: b.y - uy * reach))
            }
        }
    }

    private func cartouche() {
        let rect = CGRect(x: 0.285 * w, y: (Self.cartoucheCentre - 0.04) * w, width: 0.43 * w, height: 0.08 * w)
        let window = RoundedRectangle(cornerRadius: w * 0.03).path(in: rect)
        pillow.part(window)
        pillow.context.fill(window, with: .color(pillow.velvet))
        pillow.cordonnet(window, .gold, weight: 0.8)
    }

    /// Where the cartouche's name is centred, for the face's lettering.
    static let cartoucheCentre: CGFloat = 1.258
}
