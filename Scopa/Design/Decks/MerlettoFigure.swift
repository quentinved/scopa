import ScopaCore
import SwiftUI

/// The parts every court shares: a face of toile with its features left open to the
/// velvet, hands, the suit held up, a crown, and lace at the wrist.
extension MerlettoPillow {
    /// A face `rx` by `ry` card widths: almond eyes, brows and a long nose cut through the
    /// toile, and a mouth in a stitch of rose.
    func face(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, mouth: Bool = true) {
        toile(oval(x, y, rx, ry), rows: 0)
        var eyes = Path()
        for side in [-1, 1] as [CGFloat] {
            let ex = x + side * rx * 0.40, ey = y - ry * 0.05
            eyes.addPath(outline([(ex - rx * 0.25, ey), (ex, ey - ry * 0.13), (ex + rx * 0.25, ey), (ex, ey + ry * 0.10)]))
            open(line([(ex - side * rx * 0.30, y - ry * 0.27), (ex, y - ry * 0.37), (ex + side * rx * 0.28, y - ry * 0.28)]),
                 weight: rx * 0.075)
        }
        context.fill(eyes, with: .color(velvet))
        open(line([(x + rx * 0.02, y - ry * 0.15), (x + rx * 0.07, y + ry * 0.22), (x - rx * 0.10, y + ry * 0.29)]),
             weight: rx * 0.07)
        if mouth { lips(x, y + ry * 0.53, rx * 0.24) }
    }

    /// A mouth in a single rose stitch, `half` card widths either side of (x, y).
    func lips(_ x: CGFloat, _ y: CGFloat, _ half: CGFloat) {
        thread(line([(x - half, y - half * 0.12), (x, y + half * 0.22), (x + half, y - half * 0.12)]), .rose,
               weight: 0.85)
    }

    func hand(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 0.042) {
        toile(oval(x, y, r, r * 0.88), rows: .pi / 2)
    }

    /// Lace at a wrist: a row of toile beads across it, picoted below.
    func cuff(_ x: CGFloat, _ y: CGFloat, width: CGFloat = 0.10) {
        let (beads, tips) = beads(p(x, y), width / 2 * w, w * 0.008, count: 4, r: w * 0.017, from: .pi, to: 0)
        toile(beads, rows: 0)
        picots(tips.filter { $0.y >= y * w }, size: 0.8)
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
        self.suit(suit, at: p(x + lean * size, y - grip * size), size: size * w)
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

    /// A crown of toile, picoted at its three points, on a band of the suit's thread set
    /// with eyelets.
    func crown(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ house: MerlettoThread) {
        toile(cut(KingCrown(), x, y, width, width * 0.42), rows: .pi / 2)
        toile(cut(Capsule(), x, y + width * 0.25, width * 1.04, width * 0.17), house, rows: 0)
        eyelets([-0.30, 0, 0.30].map { p(x + $0 * width, y + width * 0.25) }, r: width * 0.05)
        let tips = [-0.5, 0, 0.5].map { dx in p(x + dx * width * 0.64, y - width * (dx == 0 ? 0.04 : 0.21)) }
        picots(tips.map { CGPoint(x: $0.x, y: $0.y - picot * 1.4) }, size: 1.2)
    }

    /// A band down a gown: toile set with eyelets, a cord either side.
    func orphrey(x: CGFloat, from top: CGFloat, to bottom: CGFloat, width: CGFloat) {
        toile(polygon([(x - width / 2, top), (x + width / 2, top), (x + width / 2, bottom), (x - width / 2, bottom)]),
              rows: 0)
        let holes = stride(from: top + width * 0.9, to: bottom - width * 0.4, by: width * 1.3).map { p(x, $0) }
        eyelets(holes, r: width * 0.22)
    }
}
