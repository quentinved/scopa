import ScopaCore
import SwiftUI

/// What is painted where on one card: the frame, then the pips or the court, then the
/// cartellini a court's index is written on.
struct TarocchiCard {
    let card: Card
    let panel: TarocchiPanel

    private var w: CGFloat { panel.w }
    private var slender: Bool { card.suit == .swords || card.suit == .clubs }

    func paint() {
        let frame = TarocchiFrame(panel: panel, card: card)
        frame.paint()
        if card.rank.isFace {
            court()
            frame.cartellini()
        } else if card == .settebello {
            settebello()
        } else if card.rank == .ace {
            ace()
        } else {
            pips()
        }
    }

    /// Painted inside the gold, so the meadow and a hem stop at the bole.
    private func court() {
        let figure = panel.within(panel.rounded(TarocchiFrame.bole))
        figure.meadow()
        let dress = TarocchiDress(card.suit)
        switch card.rank {
        case .king: figure.king(card.suit, dress)
        case .knight: figure.knight(card.suit, dress)
        default: figure.knave(card.suit, dress)
        }
    }

    // MARK: Numerals

    /// In the rows every deck in the app sets its pips in, among sprigs of flowers.
    private func pips() {
        let area = CGRect(x: 0.20 * w, y: 0.28 * w, width: 0.60 * w, height: 0.94 * w)
        let (pip, centres) = IntarsioCard.layout(card.rank.rawValue, in: area)
        // A blade or a baton is a sliver of its square, so it is painted a little longer.
        let size = pip * (slender ? 1.16 : 1)
        if panel.fine { panel.sprigs(avoiding: centres.map { ($0, size * (slender ? 0.36 : 0.5)) }) }
        for centre in centres { panel.sign(card.suit, at: centre, size: size) }
    }

    // MARK: Ace

    /// The ace's sign painted large over a banderole, among sprigs.
    private func ace() {
        let size = w * (slender ? 0.80 : 0.56)
        let centre = panel.p(0.5, 0.75)
        if panel.fine {
            // A blade or a baton is cleared along its length, a coin or cup round its middle.
            let along: [CGFloat] = slender ? [-0.27, 0, 0.27] : [0]
            var marks: [(CGPoint, CGFloat)] = along.map { (CGPoint(x: centre.x, y: centre.y + $0 * w), size * (slender ? 0.16 : 0.5)) }
            marks += ([0.15, 0.30, 0.70, 0.85] as [CGFloat]).map { (panel.p($0, 0.80), w * 0.05) }
            panel.sprigs(avoiding: marks)
            panel.banderole(y: 0.80, from: 0.16, to: 0.84)
        }
        panel.sign(card.suit, at: centre, size: size)
    }

    // MARK: Settebello

    /// The rarest card: its seven coins tooled their richest on a vermilion velvet scratched
    /// back to the leaf, with its name on a banderole at its foot.
    /// Set closer than the rows the other numerals keep, so each coin can be larger.
    private func settebello() {
        let rows: [(CGFloat, [CGFloat])] = [(0.40, [-0.1175, 0.1175]), (0.69, [-0.235, 0, 0.235]), (0.98, [-0.1175, 0.1175])]
        for (y, across) in rows {
            for x in across { panel.sign(.coins, at: panel.p(0.5 + x, y), size: w * 0.21, rich: true) }
        }
        // Only where it can be lettered.
        if w >= 70 { panel.banderole(y: Self.banderole, from: 0.29, to: 0.71) }
    }

    /// Where the settebello's banderole runs, for the face's lettering.
    static let banderole: CGFloat = 1.255
}
