import ScopaCore
import SwiftUI

/// What is inlaid where on one card: the frame, then the pips or the court, then the
/// tablets a court's index sits on.
struct IntarsioCard {
    let card: Card
    let panel: IntarsioPanel

    private var w: CGFloat { panel.w }
    private var frame: IntarsioFrame { IntarsioFrame(panel: panel, card: card) }

    func inlay() {
        frame.inlay()
        if card.rank.isFace {
            court()
            frame.tablets()
        } else if card == .settebello {
            settebello()
        } else if card.rank == .ace {
            ace()
        } else {
            pips()
        }
    }

    /// Cut to the field, so a hem or the ground runs under the stringing rather than over it.
    private func court() {
        let dress = IntarsioDress(card.suit)
        var field = panel.context
        field.clip(to: frame.rounded(IntarsioFrame.inset(card)))
        let figure = IntarsioPanel(context: field, w: w, seed: panel.seed)
        switch card.rank {
        case .king: figure.king(card.suit, dress)
        case .knight: figure.knight(card.suit, dress)
        default: figure.knave(card.suit, dress)
        }
    }

    // MARK: Numerals

    /// Rows of pips per rank, the layout every deck in the app uses. Seven is two, three, two.
    private static let rows: [Int: [Int]] = [
        2: [1, 1], 3: [1, 1, 1], 4: [2, 2], 5: [2, 1, 2], 6: [2, 2, 2], 7: [2, 3, 2],
    ]

    /// Where each pip goes inside `area`, and how large it is.
    static func layout(_ count: Int, in area: CGRect) -> (CGFloat, [CGPoint]) {
        let rows = Self.rows[count] ?? [count]
        let widest = CGFloat(rows.max() ?? 1), lines = CGFloat(rows.count)
        let pip = min(area.width / (widest + (widest - 1) * 0.28), area.height / (lines + (lines - 1) * 0.22))
        let tall = pip * lines + pip * 0.22 * (lines - 1)
        var centres: [CGPoint] = []
        for (row, count) in rows.enumerated() {
            let y = area.midY - tall / 2 + pip / 2 + CGFloat(row) * pip * 1.22
            let across = pip * CGFloat(count) + pip * 0.28 * CGFloat(count - 1)
            for column in 0..<count {
                centres.append(CGPoint(x: area.midX - across / 2 + pip / 2 + CGFloat(column) * pip * 1.28, y: y))
            }
        }
        return (pip, centres)
    }

    private func pips() {
        let area = CGRect(x: 0.20 * w, y: 0.28 * w, width: 0.60 * w, height: 0.94 * w)
        let (pip, centres) = Self.layout(card.rank.rawValue, in: area)
        // A blade or a cudgel is a sliver of its square, so it is cut a little longer.
        let slender: CGFloat = card.suit == .swords || card.suit == .clubs ? 1.16 : 1
        for centre in centres { panel.suit(card.suit, at: centre, size: pip * slender) }
    }

    // MARK: Ace

    /// The ace's sign on a medallion strung in box and ebony, its grain laid across the
    /// field's: walnut, or holly under a walnut hilt or cudgel.
    private func ace() {
        let slender = card.suit == .swords || card.suit == .clubs
        medallion(rx: 0.33, ry: 0.47, wood: slender ? .holly : .walnut, string: .box)
        panel.suit(card.suit, at: panel.p(0.5, 0.75), size: w * (slender ? 0.80 : 0.58))
    }

    private func medallion(rx: CGFloat, ry: CGFloat, y: CGFloat = 0.75, wood: IntarsioWood, string: IntarsioWood) {
        let courses: [(CGFloat, IntarsioWood)] = [(0.026, .ebony), (0.018, string), (0.008, .ebony)]
        for (grow, course) in courses {
            panel.context.fill(panel.oval(0.5, y, rx + grow, ry + grow), with: .color(course.face))
        }
        panel.lay(panel.oval(0.5, y, rx, ry), wood, grain: 0, scorch: .none, kerf: false)
    }

    // MARK: Settebello

    /// The rarest card: its seven coins, pearl at their hearts, on an ebony oval inside a
    /// brass string and a ring of pearl, with its name on a box cartouche at its foot.
    private func settebello() {
        let y: CGFloat = 0.69
        medallion(rx: 0.37, ry: 0.50, y: y, wood: .ebony, string: .brass)
        pearlRing(y: y, rx: 0.34, ry: 0.47)
        let area = CGRect(x: 0.20 * w, y: (y - 0.39) * w, width: 0.60 * w, height: 0.78 * w)
        let (pip, centres) = Self.layout(7, in: area)
        for centre in centres { panel.suit(.coins, at: centre, size: pip, rich: true) }
        if w >= 70 { cartouche() }
    }

    /// Pearl dots set round inside the oval's string.
    private func pearlRing(y: CGFloat, rx: CGFloat, ry: CGFloat) {
        var dots = Path()
        let r = max(0.6, w * 0.011)
        for k in 0..<28 {
            let angle = CGFloat(k) / 28 * 2 * .pi
            let centre = panel.p(0.5 + cos(angle) * rx, y + sin(angle) * ry)
            dots.addEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
        }
        panel.context.fill(dots, with: .color(IntarsioWood.pearl.face))
    }

    private func cartouche() {
        let rect = CGRect(x: 0.27 * w, y: 1.25 * w, width: 0.46 * w, height: 0.085 * w)
        panel.context.fill(RoundedRectangle(cornerRadius: w * 0.02).path(in: rect.insetBy(dx: -w * 0.01, dy: -w * 0.01)),
                           with: .color(IntarsioWood.brass.face))
        panel.lay(RoundedRectangle(cornerRadius: w * 0.015).path(in: rect), .box, grain: 0, scorch: .none)
    }

    /// Where the cartouche's name is centred, for the face's lettering.
    static let cartoucheCentre: CGFloat = 1.2925
}
