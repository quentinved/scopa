import SwiftUI

/// What the workshop strewed over its grounds: a meadow under every court, sprigs on a
/// numeral's gesso wherever the pips leave room, and the banderole a motto is lettered on.
extension TarocchiPanel {
    // MARK: Meadow

    /// The flowered meadow a court stands on, across the foot of the field.
    func meadow(top: CGFloat = 1.30) {
        let ground: [(CGFloat, CGFloat)] = [(-0.1, top + 0.03), (0.2, top - 0.005), (0.5, top + 0.012), (0.8, top - 0.005),
                                            (1.1, top + 0.03), (1.1, 1.62), (-0.1, 1.62)]
        paint(outline(ground), TarocchiPigment.meadow.body)
        guard fine else { return }
        var blades = Path()
        for k in 0..<14 {
            let x = 0.05 + CGFloat(k) * 0.068, y = top + (k.isMultiple(of: 2) ? 0.06 : 0.13)
            blades.move(to: p(x - 0.014, y))
            blades.addLine(to: p(x - 0.004, y - 0.03))
            blades.move(to: p(x + 0.012, y))
            blades.addLine(to: p(x + 0.006, y - 0.034))
        }
        stroke(blades, TarocchiPigment.meadow.shade, 0.0045)
        let flowers: [(CGFloat, CGFloat)] = [(0.10, top + 0.075), (0.25, top + 0.145), (0.37, top + 0.06),
                                             (0.63, top + 0.15), (0.77, top + 0.065), (0.91, top + 0.14)]
        blossoms(flowers.map { p($0.0, $0.1) }, radius: 0.018, coloured: false)
    }

    /// Five-petalled flowers, each with a gold heart: biacca on the meadow, ultramarine and
    /// vermilion by turns on gesso.
    private func blossoms(_ centres: [CGPoint], radius: CGFloat, coloured: Bool) {
        var petals = [Path(), Path()]
        let r = radius * w
        for (k, c) in centres.enumerated() {
            for petal in 0..<5 {
                let angle = CGFloat(petal) * 2 * .pi / 5 - .pi / 2
                let at = CGPoint(x: c.x + cos(angle) * r * 0.6, y: c.y + sin(angle) * r * 0.6)
                petals[coloured ? k % 2 : 0].addEllipse(in: CGRect(x: at.x - r * 0.45, y: at.y - r * 0.45,
                                                                   width: r * 0.9, height: r * 0.9))
            }
        }
        context.fill(petals[0], with: .color(coloured ? TarocchiPigment.ultramarine.body : TarocchiPigment.biacca.body))
        context.fill(petals[1], with: .color(TarocchiPigment.vermilion.body))
        punch(centres, radius: r * 0.34, Tempera.gold)
    }

    // MARK: Sprigs

    /// Sprigs of flowers on the gesso wherever the pips leave room. Spots on a grid are kept
    /// in pairs turned about the card's centre, as long as both clear every mark, the
    /// indices and the sprigs already set.
    func sprigs(avoiding marks: [(CGPoint, CGFloat)]) {
        var spots: [CGPoint] = []
        for row in 0..<5 {
            for column in 0..<5 {
                let spot = p(0.22 + CGFloat(column) * 0.14, 0.33 + CGFloat(row) * 0.0935)
                let other = CGPoint(x: w - spot.x, y: w * 1.5 - spot.y)
                guard hypot(other.x - spot.x, other.y - spot.y) > w * 0.15,
                      clear(spot, marks, spots), clear(other, marks, spots) else { continue }
                spots += [spot, other]
            }
        }
        sprig(spots)
    }

    private func clear(_ spot: CGPoint, _ marks: [(CGPoint, CGFloat)], _ spots: [CGPoint]) -> Bool {
        let x = spot.x / w, y = spot.y / w
        if (x < 0.33 && y < 0.37) || (x > 0.67 && y > 1.13) { return false }
        if spots.contains(where: { hypot($0.x - spot.x, $0.y - spot.y) < w * 0.15 }) { return false }
        return marks.allSatisfy { hypot($0.0.x - spot.x, $0.0.y - spot.y) > $0.1 + w * 0.06 }
    }

    /// A curved stem with two leaves and a flower at its tip, the whole set as a few fills.
    private func sprig(_ tips: [CGPoint]) {
        guard !tips.isEmpty else { return }
        var stems = Path(), leaves = Path()
        let leaf = Leaf().path(in: CGRect(x: -w * 0.014, y: -w * 0.05, width: w * 0.028, height: w * 0.05))
        for (k, tip) in tips.enumerated() {
            let lean: CGFloat = k.isMultiple(of: 2) ? 1 : -1
            let foot = CGPoint(x: tip.x - lean * w * 0.04, y: tip.y + w * 0.08)
            stems.move(to: foot)
            stems.addQuadCurve(to: tip, control: CGPoint(x: tip.x + lean * w * 0.022, y: tip.y + w * 0.05))
            for (t, side) in [(0.35, -1.0), (0.62, 1.0)] as [(CGFloat, CGFloat)] {
                let at = CGPoint(x: foot.x + (tip.x - foot.x) * t, y: foot.y + (tip.y - foot.y) * t)
                leaves.addPath(leaf, transform: CGAffineTransform(rotationAngle: side * 1.05)
                    .concatenating(CGAffineTransform(translationX: at.x, y: at.y)))
            }
        }
        stroke(stems, TarocchiPigment.verde.shade, 0.005)
        context.fill(leaves, with: .color(TarocchiPigment.verde.body))
        context.stroke(leaves, with: .color(Tempera.ink), lineWidth: hair * 0.55)
        blossoms(tips, radius: 0.027, coloured: true)
    }

    // MARK: Banderole

    /// A ribbon across the card at `y` from `left` to `right`, its ends forked and turned
    /// back, as the Visconti cards carry their mottoes.
    func banderole(y: CGFloat, from left: CGFloat, to right: CGFloat, depth: CGFloat = 0.068) {
        let tail = depth * 0.8, half = depth / 2, drop = depth * 0.2
        for (edge, out) in [(left, -1.0), (right, 1.0)] as [(CGFloat, CGFloat)] {
            let end = polygon([(edge - out * 0.02, y - half + drop), (edge + out * tail, y - half + drop),
                               (edge + out * tail * 0.6, y + drop), (edge + out * tail, y + half + drop),
                               (edge - out * 0.02, y + half + drop)])
            paint(end, TarocchiPigment.biacca.shade)
        }
        let middle = (left + right) / 2
        paint(limb([(left, y), (middle, y + drop * 0.6), (right, y)], [depth, depth, depth]), TarocchiPigment.biacca.body)
        guard fine else { return }
        for edge in [-half * 0.62, half * 0.62] {
            draw([(left + 0.015, y + edge), (middle, y + edge + drop * 0.6), (right - 0.015, y + edge)],
                 Tempera.sinopia.opacity(0.5), 0.0028)
        }
    }
}
