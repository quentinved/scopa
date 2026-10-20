import ScopaCore
import SwiftUI

/// The four suit signs cut in veneer, each `s` points across and centred on `c`.
extension IntarsioPanel {
    /// `rich` is the settebello's: a coin with pearl at its heart and its rim in two woods.
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

    /// A rim of olive in segments, the grain running round it, inside a brass string; a
    /// box boss inlaid with the compass rosette, six walnut petals.
    private func coin(_ c: CGPoint, _ s: CGFloat, rich: Bool) {
        let outer = s * 0.47, inner = s * 0.33
        let count = rich ? 12 : 8
        for k in 0..<count {
            let from = CGFloat(k) / CGFloat(count) * 2 * .pi, to = CGFloat(k + 1) / CGFloat(count) * 2 * .pi
            var segment = Path()
            segment.addArc(center: c, radius: outer, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
            segment.addArc(center: c, radius: inner, startAngle: .radians(to), endAngle: .radians(from), clockwise: true)
            segment.closeSubpath()
            let wood: IntarsioWood = rich && k.isMultiple(of: 2) ? .walnut : .olive
            lay(segment, wood, grain: (from + to) / 2 + .pi / 2, scorch: .none)
        }
        let boss = Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2))
        lay(boss, .box, grain: .pi / 2, scorch: .rim)
        context.stroke(boss, with: .color(IntarsioWood.brass.face), lineWidth: max(0.5, s * 0.045))
        for k in 0..<6 {
            petal(c, length: s * 0.265, breadth: s * 0.165, angle: CGFloat(k) * .pi / 3,
                  rich && k.isMultiple(of: 2) ? .padauk : .walnut)
        }
        let heart = rich ? s * 0.07 : s * 0.045
        lay(Path(ellipseIn: CGRect(x: c.x - heart, y: c.y - heart, width: heart * 2, height: heart * 2)),
            rich ? .pearl : .ebony, scorch: .none)
    }

    /// A pointed petal or leaf, its stalk at `base`, laid outward at `angle` (0 is up).
    func petal(_ base: CGPoint, length: CGFloat, breadth: CGFloat, angle: CGFloat, _ wood: IntarsioWood,
               rib: Bool = false) {
        let shape = Leaf().path(in: CGRect(x: -breadth / 2, y: -length, width: breadth, height: length))
        let place = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y))
        lay(shape.applying(place), wood, grain: angle - .pi / 2, scorch: .side(angle + .pi / 2))
        guard rib, fine else { return }
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -length * 0.08).applying(place))
        vein.addLine(to: CGPoint(x: 0, y: -length * 0.82).applying(place))
        context.stroke(vein, with: .color(IntarsioWood.mastic.opacity(0.75)), lineWidth: max(0.3, w * 0.004))
    }

    // MARK: Coppe

    /// A padauk bowl in two leaves whose grain meets at the middle, on a walnut stem between
    /// a box knop and foot, under a box lip.
    private func cup(_ c: CGPoint, _ s: CGFloat) {
        lay(Trapezoid(topRatio: 0.32).path(in: box(c, s, 0, 0.375, 0.56, 0.13)), .box, grain: 0, scorch: .down)
        lay(Path(box(c, s, 0, 0.255, 0.11, 0.15)), .walnut, grain: .pi / 2, scorch: .right)
        lay(Path(ellipseIn: box(c, s, 0, 0.175, 0.27, 0.10)), .box, grain: 0, scorch: .down)
        let bowl = box(c, s, 0, -0.10, 0.76, 0.46)
        lay(bowlHalf(bowl, left: true), .padauk, grain: .pi * 0.64, scorch: .lowerLeft)
        lay(bowlHalf(bowl, left: false), .padauk, grain: .pi * 0.36, scorch: .lowerRight)
        if s >= 16 {
            var band = Path()
            band.move(to: CGPoint(x: bowl.minX + bowl.width * 0.06, y: bowl.minY + bowl.height * 0.30))
            band.addQuadCurve(to: CGPoint(x: bowl.maxX - bowl.width * 0.06, y: bowl.minY + bowl.height * 0.30),
                              control: CGPoint(x: bowl.midX, y: bowl.minY + bowl.height * 0.42))
            string(band, .holly, 0.006)
        }
        lay(Capsule().path(in: box(c, s, 0, -0.33, 0.84, 0.11)), .box, grain: 0, scorch: .down)
    }

    private func bowlHalf(_ r: CGRect, left: Bool) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY), control1: CGPoint(x: r.midX - r.width * 0.30, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.95))
        p.closeSubpath()
        return left ? p : p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * r.midX, ty: 0))
    }

    // MARK: Spade

    /// The blade in two leaves, harewood lit and harewood shaded, so it reads as ridged; a
    /// walnut guard and pommel, an ebony grip.
    private func sword(_ c: CGPoint, _ s: CGFloat) {
        let blade = box(c, s, 0, -0.17, 0.22, 0.66)
        lay(bladeHalf(blade, left: true), .harewood, grain: .pi / 2, scorch: .none)
        lay(bladeHalf(blade, left: false), .steel, grain: .pi / 2, scorch: .none)
        lay(Path(box(c, s, 0, 0.31, 0.10, 0.16)), .ebony, grain: .pi / 2, scorch: .none)
        lay(Capsule().path(in: box(c, s, 0, 0.185, 0.70, 0.10)), .walnut, grain: 0, scorch: .down)
        lay(Path(ellipseIn: box(c, s, 0, 0.44, 0.15, 0.15)), .walnut, scorch: .rim)
    }

    private func bladeHalf(_ r: CGRect, left: Bool) -> Path {
        let edge = left ? r.minX : r.maxX
        var p = Path()
        p.addLines([CGPoint(x: r.midX, y: r.minY), CGPoint(x: edge, y: r.minY + r.height * 0.2),
                    CGPoint(x: edge, y: r.maxY), CGPoint(x: r.midX, y: r.maxY)])
        p.closeSubpath()
        return p
    }

    // MARK: Bastoni

    /// A lopped walnut cudgel, its knots set in olive, the cut stubs of two branches showing
    /// pale end grain, two leaves in green. Drawn upright on a panel already turned.
    fileprivate func club(_ c: CGPoint, _ s: CGFloat) {
        petal(CGPoint(x: c.x - s * 0.08, y: c.y + s * 0.12), length: s * 0.30, breadth: s * 0.15,
              angle: -.pi * 0.30, .green, rib: s >= 16)
        petal(CGPoint(x: c.x + s * 0.07, y: c.y - s * 0.10), length: s * 0.28, breadth: s * 0.14,
              angle: .pi * 0.28, .green, rib: s >= 16)
        stub(CGPoint(x: c.x - s * 0.05, y: c.y - s * 0.02), length: s * 0.17, thickness: s * 0.075, angle: -.pi * 0.22)
        stub(CGPoint(x: c.x + s * 0.04, y: c.y + s * 0.20), length: s * 0.15, thickness: s * 0.065, angle: .pi * 0.25)
        lay(Cudgel().path(in: box(c, s, 0, 0, 0.36, 0.94)), .walnut, grain: .pi / 2, scorch: .right)
        for (x, y, rx) in [(0.06, -0.26, 0.04), (-0.04, -0.05, 0.035), (0.025, 0.30, 0.025)] as [(CGFloat, CGFloat, CGFloat)] {
            let knot = CGRect(x: c.x + (x - rx) * s, y: c.y + (y - rx * 0.7) * s, width: rx * 2 * s, height: rx * 1.4 * s)
            lay(Path(ellipseIn: knot), .olive, grain: 0, scorch: .rim)
        }
    }

    /// A lopped branch from `base` outward at `angle` (0 is up), its cut end in box.
    private func stub(_ base: CGPoint, length: CGFloat, thickness: CGFloat, angle: CGFloat) {
        let place = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y))
        let branch = Path(CGRect(x: -thickness / 2, y: -length, width: thickness, height: length)).applying(place)
        lay(branch, .walnut, grain: angle - .pi / 2, scorch: .none)
        let end = Path(ellipseIn: CGRect(x: -thickness * 0.55, y: -length - thickness * 0.28, width: thickness * 1.1,
                                         height: thickness * 0.56))
        lay(end.applying(place), .box, grain: angle, scorch: .rim)
    }
}
