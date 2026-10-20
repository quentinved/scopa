import ScopaCore
import SwiftUI

/// The parts every court shares: a pale face with its features drawn fine, hands, robes
/// brocaded in gold, bands of leaf, a crown, ermine, and the suit held up.
extension TarocchiPanel {
    /// A face `rx` by `ry` card widths: flesh in its line, eyes and brows in ink, the nose
    /// in the flesh's shade, a vermilion mouth and a touch of rose on each cheek.
    func face(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, mouth: Bool = true) {
        paint(oval(x, y, rx, ry), TarocchiPigment.flesh.body)
        var eyes = Path()
        for side in [-1, 1] as [CGFloat] {
            let ex = x + side * rx * 0.40, ey = y - ry * 0.05
            if fine {
                context.fill(oval(ex + side * rx * 0.06, y + ry * 0.26, rx * 0.22, ry * 0.13), with: .color(Tempera.cheek))
                draw([(ex - rx * 0.24, ey - ry * 0.17), (ex, ey - ry * 0.27), (ex + rx * 0.24, ey - ry * 0.17)],
                     TarocchiPigment.chestnut.shade, rx * 0.055)
            }
            eyes.addPath(oval(ex, ey, rx * 0.16, ry * 0.07))
        }
        context.fill(eyes, with: .color(Tempera.ink))
        if fine {
            draw([(x + rx * 0.04, y - ry * 0.12), (x + rx * 0.10, y + ry * 0.22), (x - rx * 0.07, y + ry * 0.28)],
                 TarocchiPigment.flesh.shade, rx * 0.05)
        }
        if mouth { context.fill(oval(x, y + ry * 0.52, rx * 0.20, ry * 0.065), with: .color(TarocchiPigment.vermilion.body)) }
    }

    func hand(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 0.034) {
        paint(oval(x, y, r, r * 0.9), TarocchiPigment.flesh.body, line: 0.8)
    }

    /// A robe in `pigment`, brocaded in gold if asked, folds falling down it in its shade.
    func robe(_ piece: Path, _ pigment: TarocchiPigment, brocade: Bool = false, folds: [[(CGFloat, CGFloat)]] = []) {
        context.fill(piece, with: .color(pigment.body))
        if brocade { self.brocade(piece) }
        if fine { for fold in folds { draw(fold, pigment.shade, 0.0055) } }
        context.stroke(piece, with: .color(Tempera.ink), lineWidth: hair)
    }

    /// Gold woven through a cloth: small fleurons in a half-drop repeat, clipped to the piece.
    func brocade(_ piece: Path, pitch: CGFloat = 0.07) {
        guard fine else { return }
        let box = piece.boundingRect, step = pitch * w
        let (dx, dy) = (w * 0.011, w * 0.017)
        var motifs = Path()
        var row = 0
        var y = box.minY + step * 0.45
        while y < box.maxY {
            var x = box.minX + (row.isMultiple(of: 2) ? step * 0.3 : step * 0.8)
            while x < box.maxX {
                motifs.addLines([CGPoint(x: x, y: y - dy), CGPoint(x: x + dx, y: y), CGPoint(x: x, y: y + dy),
                                 CGPoint(x: x - dx, y: y)])
                motifs.closeSubpath()
                motifs.addEllipse(in: CGRect(x: x - dx * 0.5, y: y - dy * 2.1, width: dx, height: dx))
                x += step
            }
            y += step * 0.9
            row += 1
        }
        within(piece).context.fill(motifs, with: .color(Tempera.gold))
    }

    /// A band of leaf along a spine: a hem, a girdle, a cuff, punched along its length.
    func gilt(_ spine: [(CGFloat, CGFloat)], _ width: CGFloat) {
        paint(limb(spine, Array(repeating: width, count: spine.count)), Tempera.gold, line: 0.8)
        if fine && width >= 0.022 { punchRow(curve(spine), radius: w * 0.0048, pitch: w * 0.017) }
    }

    /// A pointed shoe, its heel at (x, y), its toe out to one side.
    func shoe(_ x: CGFloat, _ y: CGFloat, toward side: CGFloat) {
        paint(outline([(x - side * 0.025, y - 0.015), (x + side * 0.02, y - 0.012), (x + side * 0.09, y + 0.016),
                       (x - side * 0.02, y + 0.018)]), Tempera.sable, line: 0.6)
    }

    /// A crown of leaf `width` across on a band centred at (x, y): three fleurons over a band
    /// punched along its length and set with stones, a pearl on every point.
    func crown(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat) {
        paint(cut(KingCrown(), x, y - width * 0.23, width, width * 0.44), Tempera.gold)
        paint(cut(Rectangle(), x, y, width * 1.04, width * 0.2), Tempera.gold)
        let stones: [(CGFloat, TarocchiPigment)] = [(-0.3, .vermilion), (0, .ultramarine), (0.3, .vermilion)]
        for (dx, stone) in stones { paint(oval(x + dx * width, y, width * 0.07, width * 0.065), stone.body, line: 0.5) }
        let top = y - width * 0.45
        let pearls: [(CGFloat, CGFloat)] = [(-0.18, top), (0.18, top), (-0.5, top + width * 0.185),
                                            (0.5, top + width * 0.185)]
        punch(pearls.map { p(x + $0.0 * width, $0.1) }, radius: w * width * 0.06, TarocchiPigment.biacca.body)
    }

    /// A cape of ermine over the shoulders, `half` card widths either side of (x, y), its
    /// tails in sable.
    func ermine(_ x: CGFloat, _ y: CGFloat, half: CGFloat = 0.21) {
        let cape: [(CGFloat, CGFloat)] = [(x - half, y + 0.045), (x - half * 0.68, y - 0.055), (x, y - 0.07),
                                          (x + half * 0.68, y - 0.055), (x + half, y + 0.045), (x + half * 0.7, y + 0.095),
                                          (x, y + 0.11), (x - half * 0.7, y + 0.095)]
        paint(outline(cape), TarocchiPigment.biacca.body)
        let tails: [(CGFloat, CGFloat)] = [(-0.7, 0.04), (-0.35, 0.065), (0, 0.075), (0.35, 0.065), (0.7, 0.04),
                                           (-0.5, -0.01), (0.5, -0.01)]
        var marks = Path()
        for (dx, dy) in tails {
            let at = p(x + dx * half, y + dy)
            marks.addLines([CGPoint(x: at.x, y: at.y - w * 0.018), CGPoint(x: at.x + w * 0.009, y: at.y + w * 0.01),
                            CGPoint(x: at.x - w * 0.009, y: at.y + w * 0.01)])
            marks.closeSubpath()
        }
        context.fill(marks, with: .color(Tempera.sable))
    }

    /// The suit held up in a hand at (x, y), the hand on the part a hand would hold: under
    /// a coin, round a cup's stem, on a sword's grip or a baton's shaft.
    func held(_ suit: Suit, hand x: CGFloat, _ y: CGFloat, size: CGFloat) {
        let size = size * (suit == .swords || suit == .clubs ? 1.38 : suit == .cups ? 1.05 : 1)
        let grip: CGFloat = switch suit {
        case .coins: 0.44
        case .cups: 0.28
        case .swords: 0.30
        case .clubs: 0.29
        }
        // A baton leans, so its foot sits off its centre.
        let lean: CGFloat = suit == .clubs ? -0.065 : 0
        sign(suit, at: p(x + lean * size, y - grip * size), size: size * w)
        hand(x, y)
    }
}
