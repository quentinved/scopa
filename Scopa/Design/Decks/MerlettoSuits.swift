import ScopaCore
import SwiftUI

/// The four suit signs worked as lace motifs, each `s` points across and centred on `c`.
/// Every part is cut clear of the next, so a sign reads by its gaps as well as its cords.
extension MerlettoPillow {
    /// `rich` is the settebello's: gold at the cord, the wheel and the picots.
    func suit(_ suit: Suit, at c: CGPoint, size s: CGFloat, rich: Bool = false) {
        switch suit {
        case .coins: coin(c, s, rich: rich)
        case .cups: cup(c, s)
        case .swords: sword(c, s)
        case .clubs: turned(-.pi * 0.078, about: c).club(c, s)
        }
    }

    /// A rect `pw` by `ph` of the sign's size, its centre (x, y) of it from `c`.
    private func box(_ c: CGPoint, _ s: CGFloat, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat) -> CGRect {
        CGRect(x: c.x + (x - pw / 2) * s, y: c.y + (y - ph / 2) * s, width: pw * s, height: ph * s)
    }

    // MARK: Denari

    /// A ring of toile with a scalloped rim on a raised cord; inside it réseau and a rosette
    /// of six toile petals round a hub in the suit's yellow. The settebello's ring is worked
    /// in gold thread and eyeleted round.
    private func coin(_ c: CGPoint, _ s: CGFloat, rich: Bool) {
        let (outer, inner, hub) = (s * 0.46, s * 0.30, s * 0.10)
        let accent: MerlettoThread = rich ? .gold : .linen
        let edge = rim(c, outer, scallops: rich ? 12 : 10)
        part(edge)
        context.fill(edge, with: .color(velvet))
        net(circle(c, inner), cell: max(0.012, s / w * 0.06), cord: nil, parted: false)
        for k in 0..<6 {
            leaf(c, length: s * 0.26, breadth: s * 0.14, angle: CGFloat(k) * .pi / 3, .linen, veined: false)
        }
        toile(circle(c, hub), rich ? .gold : .house(.coins), rows: 0, cord: accent)
        var ring = edge
        ring.addPath(circle(c, inner))
        toile(ring, accent, rows: .pi / 4, cord: accent, parted: false, eo: true)
        if fine && s >= w * (rich ? 0.12 : 0.2) {
            eyelets(around(c, (outer + inner) / 2 - s * 0.01, nil, rich ? 12 : 10, phase: .pi / 10),
                    r: (outer - inner) / w * 0.2, accent)
        }
    }

    /// A circle `r` about `c` whose edge swells into `scallops` shallow lobes.
    private func rim(_ c: CGPoint, _ r: CGFloat, scallops: Int) -> Path {
        var path = Path()
        func at(_ angle: CGFloat, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
        }
        let step = 2 * .pi / CGFloat(scallops)
        path.move(to: at(0, r * 0.93))
        for k in 0..<scallops {
            let a = CGFloat(k) * step
            path.addQuadCurve(to: at(a + step, r * 0.93), control: at(a + step / 2, r * 1.12))
        }
        path.closeSubpath()
        return path
    }

    // MARK: Coppe

    /// A chalice in toile, each part cut clear of the next: foot, stem, knop, a bowl with a
    /// band of the suit's red round it, and a lip picoted at its ends.
    private func cup(_ c: CGPoint, _ s: CGFloat) {
        toile(Trapezoid(topRatio: 0.34).path(in: box(c, s, 0, 0.395, 0.54, 0.12)))
        picots([0.25, 0.5, 0.75].map { CGPoint(x: c.x + ($0 - 0.5) * 0.54 * s, y: c.y + 0.455 * s + picot * 1.2) })
        toile(Path(box(c, s, 0, 0.27, 0.10, 0.15)), rows: .pi / 2)
        toile(Path(ellipseIn: box(c, s, 0, 0.19, 0.26, 0.085)))
        let bowl = Bowl(roundness: 0.95).path(in: box(c, s, 0, -0.06, 0.76, 0.42))
        toile(bowl)
        let band = bowl.intersection(Path(box(c, s, 0, -0.135, 0.9, 0.12)))
        toile(band, .house(.cups), rows: 0, parted: false)
        toile(Capsule().path(in: box(c, s, 0, -0.30, 0.86, 0.10)))
        picots([CGPoint(x: c.x - 0.43 * s - picot * 1.2, y: c.y - 0.30 * s),
                CGPoint(x: c.x + 0.43 * s + picot * 1.2, y: c.y - 0.30 * s)])
    }

    // MARK: Spade

    /// A pointed blade in toile with its fuller run in the suit's blue, a guard picoted at
    /// both ends, a blue grip, and a pommel with an eyelet at its heart.
    private func sword(_ c: CGPoint, _ s: CGFloat) {
        let blade = Path { path in
            path.addLines([CGPoint(x: c.x, y: c.y - 0.50 * s), CGPoint(x: c.x + 0.11 * s, y: c.y - 0.33 * s),
                           CGPoint(x: c.x + 0.11 * s, y: c.y + 0.14 * s), CGPoint(x: c.x - 0.11 * s, y: c.y + 0.14 * s),
                           CGPoint(x: c.x - 0.11 * s, y: c.y - 0.33 * s)])
            path.closeSubpath()
        }
        toile(blade, rows: .pi / 2)
        var fuller = Path()
        fuller.move(to: CGPoint(x: c.x, y: c.y - 0.36 * s))
        fuller.addLine(to: CGPoint(x: c.x, y: c.y + 0.10 * s))
        thread(fuller, .house(.swords), weight: max(0.9, s / w * 2.2))
        toile(Capsule().path(in: box(c, s, 0, 0.185, 0.66, 0.09)))
        picots([-1, 1].flatMap { side -> [CGPoint] in
            let x = c.x + side * (0.33 * s + picot * 1.2)
            return [CGPoint(x: x, y: c.y + 0.185 * s), CGPoint(x: x - side * picot, y: c.y + 0.185 * s - picot * 2)]
        })
        toile(Path(box(c, s, 0, 0.305, 0.10, 0.15)), .house(.swords), rows: 0)
        let pommel = box(c, s, 0, 0.43, 0.16, 0.16)
        toile(Path(ellipseIn: pommel))
        eyelets([CGPoint(x: pommel.midX, y: pommel.midY)], r: 0.028 * s / w)
    }

    // MARK: Bastoni

    /// A knobbly cudgel in toile laid on the slant, a lopped branch at its shoulder, its
    /// knots raised in rings of cord, two leaves in the suit's green veined in linen. Drawn
    /// upright on a pillow already turned.
    fileprivate func club(_ c: CGPoint, _ s: CGFloat) {
        leaf(CGPoint(x: c.x - s * 0.09, y: c.y + s * 0.10), length: s * 0.34, breadth: s * 0.17, angle: -.pi * 0.32)
        leaf(CGPoint(x: c.x + s * 0.08, y: c.y - s * 0.02), length: s * 0.30, breadth: s * 0.15, angle: .pi * 0.30)
        let knobs: [(CGFloat, CGFloat, CGFloat)] = [(-0.155, -0.19, 0.068), (0.15, -0.03, 0.062), (-0.115, 0.13, 0.054),
                                                    (0.085, 0.27, 0.046)]
        var cudgel = Cudgel().path(in: box(c, s, 0, 0, 0.32, 0.94))
        for (x, y, r) in knobs { cudgel = cudgel.union(circle(CGPoint(x: c.x + x * s, y: c.y + y * s), r * s)) }
        let lop = CGAffineTransform(rotationAngle: .pi * 0.27).concatenating(CGAffineTransform(translationX: c.x + s * 0.10,
                                                                                              y: c.y - s * 0.20))
        cudgel = cudgel.union(Path(CGRect(x: -0.04 * s, y: -0.17 * s, width: 0.08 * s, height: 0.17 * s)).applying(lop))
        toile(cudgel, rows: .pi * 0.32)
        if fine && s >= w * 0.15 {
            var rings = Path()
            for (x, y, r) in knobs.prefix(3) { rings.addPath(circle(CGPoint(x: c.x + x * s * 0.9, y: c.y + y * s), r * s * 0.45)) }
            cordonnet(rings, weight: 0.5)
        }
        eyelets([CGPoint(x: 0, y: -0.15 * s).applying(lop)], r: 0.026 * s / w)
        let head = CGPoint(x: c.x, y: c.y - 0.34 * s), reach = 0.16 * s + picot * 1.2
        picots([-0.74, -0.5, -0.26].map { CGPoint(x: head.x + cos($0 * .pi) * reach, y: head.y + sin($0 * .pi) * reach) })
    }

    /// A pointed leaf of coloured toile on its stalk at `base`, laid outward at `angle`
    /// (0 is up), with a linen vein.
    func leaf(_ base: CGPoint, length: CGFloat, breadth: CGFloat, angle: CGFloat,
              _ thread: MerlettoThread = .house(.clubs), veined: Bool = true) {
        let place = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y))
        let shape = Leaf().path(in: CGRect(x: -breadth / 2, y: -length, width: breadth, height: length))
        toile(shape.applying(place), thread, rows: angle)
        guard fine, veined else { return }
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -length * 0.1).applying(place))
        vein.addLine(to: CGPoint(x: 0, y: -length * 0.8).applying(place))
        self.thread(vein, .linen, weight: 0.45)
    }
}
