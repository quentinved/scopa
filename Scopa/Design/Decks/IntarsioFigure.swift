import ScopaCore
import SwiftUI

/// The parts every court shares: a frontal head in pear wood with its features engraved,
/// hands, and the suit held up.
extension IntarsioPanel {
    /// A face `rx` by `ry` card widths, scorched down one cheek, with almond eyes, arched
    /// brows and a long nose cut in mastic, and a padouk mouth.
    func face(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, mouth: Bool = true) {
        lay(oval(x, y, rx, ry), .pear, grain: .pi / 2, scorch: .lowerRight)
        for side in [-1, 1] as [CGFloat] {
            let ex = x + side * rx * 0.40, ey = y - ry * 0.06
            let white = outline([(ex - rx * 0.24, ey), (ex, ey - ry * 0.13), (ex + rx * 0.24, ey), (ex, ey + ry * 0.09)])
            lay(white, .holly, scorch: .none, kerf: false)
            let iris = rx * 0.092
            context.fill(Path(ellipseIn: CGRect(x: (ex - iris) * w, y: (ey - iris * 1.05) * w, width: iris * 2 * w,
                                                height: iris * 2.1 * w)), with: .color(IntarsioWood.mastic))
            incise([(ex - rx * 0.27, ey + ry * 0.01), (ex, ey - ry * 0.17), (ex + rx * 0.27, ey + ry * 0.01)], rx * 0.036)
            incise([(ex - side * rx * 0.30, y - ry * 0.27), (ex, y - ry * 0.36), (ex + side * rx * 0.26, y - ry * 0.30)],
                   rx * 0.05)
        }
        incise([(x + rx * 0.02, y - ry * 0.18), (x + rx * 0.06, y + ry * 0.22), (x - rx * 0.10, y + ry * 0.30)], rx * 0.05)
        if mouth {
            lay(outline([(x - rx * 0.24, y + ry * 0.50), (x, y + ry * 0.45), (x + rx * 0.24, y + ry * 0.50),
                         (x, y + ry * 0.61)]), .padauk, grain: 0, scorch: .none)
        }
    }

    func hand(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 0.042) {
        lay(oval(x, y, r, r * 0.88), .pear, grain: .pi / 2, scorch: .rim)
    }

    /// The suit held up in a hand at (x, y), the hand on the part a hand would hold: under
    /// a coin, round a cup's stem, on a sword's grip or a club's shaft.
    func held(_ suit: Suit, hand x: CGFloat, _ y: CGFloat, size: CGFloat) {
        let size = size * Self.reach(suit)
        let grip: CGFloat = switch suit {
        case .coins: 0.44
        case .cups: 0.25
        case .swords: 0.31
        case .clubs: 0.30
        }
        // A cudgel leans, so its foot sits off its centre.
        let lean: CGFloat = suit == .clubs ? -0.073 : 0
        let centre = p(x + lean * size, y - grip * size)
        self.suit(suit, at: centre, size: size * w)
        hand(x, y)
    }

    /// How large a figure holds its suit: slender swords and cudgels larger than a coin.
    static func reach(_ suit: Suit) -> CGFloat {
        switch suit {
        case .coins: 1
        case .cups: 1.05
        case .swords, .clubs: 1.38
        }
    }

    /// A crown of brass: three points over a band set with stones.
    func crown(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat) {
        lay(cut(KingCrown(), x, y, width, width * 0.42), .brass, grain: 0, scorch: .down)
        lay(cut(Capsule(), x, y + width * 0.25, width * 1.04, width * 0.16), .brass, grain: 0, scorch: .down)
        let stones: [(CGFloat, IntarsioWood)] = [(-0.30, .padauk), (0, .green), (0.30, .padauk)]
        for (dx, stone) in stones {
            lay(oval(x + dx * width, y + width * 0.25, width * 0.06, width * 0.05), stone, scorch: .none)
        }
        for dx in [-0.5, 0, 0.5] as [CGFloat] {
            let tip = (x + dx * width * 0.64, y - width * (dx == 0 ? 0.08 : 0.21))
            lay(oval(tip.0, tip.1, width * 0.05, width * 0.05), .pearl, scorch: .none)
        }
    }

    /// A band of trim down a gown, strung either side and set with lozenges.
    func orphrey(x: CGFloat, from top: CGFloat, to bottom: CGFloat, width: CGFloat, _ trim: IntarsioWood) {
        let band = polygon([(x - width / 2, top), (x + width / 2, top), (x + width / 2, bottom), (x - width / 2, bottom)])
        lay(band, trim, grain: .pi / 2, scorch: .none)
        var y = top + width * 0.8
        var k = 0
        while y < bottom {
            let stone: IntarsioWood = k.isMultiple(of: 2) ? .ebony : .padauk
            lay(polygon([(x, y - width * 0.42), (x + width * 0.30, y), (x, y + width * 0.42), (x - width * 0.30, y)]),
                stone, scorch: .none, kerf: false)
            y += width * 1.15
            k += 1
        }
        for edge in [x - width / 2, x + width / 2] { string(line([(edge, top), (edge, bottom)]), .ebony, 0.008) }
    }
}
