import ScopaCore
import SwiftUI

/// The four signs as the workshop painted them, each `s` points across and centred on `c`:
/// coins and cups in leaf tooled like the ground, blades in silver, batons of turned wood.
extension TarocchiPanel {
    /// `rich` is the settebello's coin: set in pearls, its petals painted, its heart ultramarine.
    func sign(_ suit: Suit, at c: CGPoint, size s: CGFloat, rich: Bool = false) {
        switch suit {
        case .coins: coin(c, s, rich: rich)
        case .cups: cup(c, s)
        case .swords: sword(c, s)
        case .clubs: turned(-.pi * 0.07, about: c).club(c, s)
        }
    }

    /// A rect `pw` by `ph` of the sign's size, its centre (x, y) of it from `c`.
    private func box(_ c: CGPoint, _ s: CGFloat, _ x: CGFloat, _ y: CGFloat, _ pw: CGFloat, _ ph: CGFloat) -> CGRect {
        CGRect(x: c.x + (x - pw / 2) * s, y: c.y + (y - ph / 2) * s, width: pw * s, height: ph * s)
    }

    private func ring(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// Tooling on a sign, in points: lines and punches too fine to strike below this.
    private func tooled(_ s: CGFloat) -> Bool { s >= 12 }

    // MARK: Denari

    /// A disc of leaf: a punched row round its rim inside an incised line, a rosette of six
    /// petals incised round a heart of vermilion.
    private func coin(_ c: CGPoint, _ s: CGFloat, rich: Bool) {
        if rich && tooled(s) {
            punchRow(ring(c, s * 0.505), radius: s * 0.026, pitch: s * 0.082, TarocchiPigment.biacca.body)
        }
        paint(ring(c, s * 0.47), Tempera.gold)
        context.stroke(ring(c, s * 0.345), with: .color(Tempera.tool), lineWidth: max(0.3, s * 0.026))
        if tooled(s) {
            punchRow(ring(c, s * 0.405), radius: s * 0.023, pitch: s * 0.082)
            rosette(c, s, rich: rich)
        }
        let heart = ring(c, s * (rich ? 0.095 : 0.075))
        paint(heart, rich ? TarocchiPigment.ultramarine.body : TarocchiPigment.vermilion.body, line: tooled(s) ? 0.6 : 0)
        if rich && tooled(s) { punch([c], radius: s * 0.03, Tempera.gold) }
    }

    private func rosette(_ c: CGPoint, _ s: CGFloat, rich: Bool) {
        var petals = Path()
        let petal = Leaf().path(in: CGRect(x: -s * 0.06, y: -s * 0.30, width: s * 0.12, height: s * 0.30))
        for k in 0..<6 {
            petals.addPath(petal, transform: CGAffineTransform(rotationAngle: CGFloat(k) * .pi / 3)
                .concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
        }
        if rich {
            context.fill(petals, with: .color(TarocchiPigment.vermilion.body))
            let between = (0..<6).map { k -> CGPoint in
                let angle = (CGFloat(k) + 0.5) * .pi / 3 - .pi / 2
                return CGPoint(x: c.x + cos(angle) * s * 0.24, y: c.y + sin(angle) * s * 0.24)
            }
            punch(between, radius: s * 0.022)
        }
        context.stroke(petals, with: .color(rich ? Tempera.ink : Tempera.tool), lineWidth: max(0.3, s * 0.02))
    }

    // MARK: Coppe

    /// A cup of leaf on a stem: a vermilion knop, a band of ultramarine round the bowl set
    /// with gold, and the bowl gadrooned below it.
    private func cup(_ c: CGPoint, _ s: CGFloat) {
        paint(Trapezoid(topRatio: 0.3).path(in: box(c, s, 0, 0.405, 0.56, 0.13)), Tempera.gold)
        paint(Path(box(c, s, 0, 0.275, 0.09, 0.15)), Tempera.gold)
        paint(Path(ellipseIn: box(c, s, 0, 0.195, 0.24, 0.10)), TarocchiPigment.vermilion.body)
        let bowl = Bowl(roundness: 0.85).path(in: box(c, s, 0, -0.07, 0.74, 0.44))
        paint(bowl, Tempera.gold)
        if s >= 9 { enamel(bowl, c, s) }
        paint(Capsule().path(in: box(c, s, 0, -0.30, 0.82, 0.08)), Tempera.gold)
    }

    private func enamel(_ bowl: Path, _ c: CGPoint, _ s: CGFloat) {
        var inside = context
        inside.clip(to: bowl)
        let band = box(c, s, 0, -0.19, 0.80, 0.085)
        inside.fill(Path(band), with: .color(TarocchiPigment.ultramarine.body))
        guard tooled(s) else { return }
        inside.stroke(Path(band), with: .color(Tempera.ink), lineWidth: max(0.3, s * 0.016))
        punch((0..<5).map { CGPoint(x: c.x + (CGFloat($0) - 2) * s * 0.13, y: band.midY) }, radius: s * 0.022, Tempera.gold)
        var gadroons = Path()
        for k in -2...2 {
            gadroons.move(to: CGPoint(x: c.x + CGFloat(k) * s * 0.12, y: band.maxY))
            gadroons.addQuadCurve(to: CGPoint(x: c.x + CGFloat(k) * s * 0.04, y: c.y + s * 0.13),
                                  control: CGPoint(x: c.x + CGFloat(k) * s * 0.12, y: c.y + s * 0.04))
        }
        inside.stroke(gadroons, with: .color(Tempera.tool), lineWidth: max(0.3, s * 0.018))
    }

    // MARK: Spade

    /// A broad silver blade, one side of its ridge in shade, a gold guard curled at both
    /// ends, a vermilion grip bound in gold and a gold pommel.
    private func sword(_ c: CGPoint, _ s: CGFloat) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * s, y: c.y + y * s) }
        let blade = Path { path in
            path.addLines([at(0, -0.49), at(0.10, -0.36), at(0.095, 0.17), at(-0.095, 0.17), at(-0.10, -0.36)])
            path.closeSubpath()
        }
        context.fill(blade, with: .color(TarocchiPigment.silver.body))
        if s >= 9 {
            let shaded = Path { path in
                path.addLines([at(0, -0.49), at(0.10, -0.36), at(0.095, 0.17), at(0, 0.17)])
                path.closeSubpath()
            }
            context.fill(shaded, with: .color(TarocchiPigment.silver.shade.opacity(0.5)))
        }
        context.stroke(blade, with: .color(Tempera.ink), lineWidth: hair)
        for side in [-1, 1] as [CGFloat] { paint(ring(at(side * 0.29, 0.15), s * 0.05), Tempera.gold) }
        paint(Capsule().path(in: box(c, s, 0, 0.19, 0.58, 0.075)), Tempera.gold)
        paint(Path(box(c, s, 0, 0.30, 0.085, 0.15)), TarocchiPigment.vermilion.body)
        if tooled(s) {
            for y in [0.265, 0.335] as [CGFloat] { paint(Path(box(c, s, 0, y, 0.105, 0.024)), Tempera.gold, line: 0.5) }
        }
        paint(ring(at(0, 0.42), s * 0.07), Tempera.gold)
    }

    // MARK: Bastoni

    /// A lopped branch thickening from the grip to a blunt head, its two stubs showing pale
    /// end grain, bound in gold under the head and at the foot, a sprig of two leaves on it.
    /// Drawn upright on a panel already turned.
    fileprivate func club(_ c: CGPoint, _ s: CGFloat) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * s, y: c.y + y * s) }
        let leaf = Leaf().path(in: CGRect(x: -s * 0.065, y: -s * 0.26, width: s * 0.13, height: s * 0.26))
        for (x, y, angle) in [(-0.07, 0.10, -0.95), (0.07, -0.08, 0.95)] as [(CGFloat, CGFloat, CGFloat)] {
            let base = at(x, y)
            paint(leaf.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y))),
                  TarocchiPigment.verde.body, line: 0.8)
        }
        stub(at(-0.07, -0.02), s, angle: -0.8)
        stub(at(0.055, 0.22), s, angle: 0.8)
        let body = Path { path in
            path.move(to: at(-0.06, 0.47))
            path.addQuadCurve(to: at(-0.12, -0.36), control: at(-0.075, 0))
            path.addQuadCurve(to: at(0.12, -0.36), control: at(0, -0.56))
            path.addQuadCurve(to: at(0.06, 0.47), control: at(0.075, 0))
            path.addQuadCurve(to: at(-0.06, 0.47), control: at(0, 0.50))
        }
        paint(body, TarocchiPigment.wood.body)
        if s >= 12 {
            for (x, y) in [(0.035, -0.10), (-0.03, 0.15)] as [(CGFloat, CGFloat)] {
                paint(Path(ellipseIn: box(c, s, x, y, 0.05, 0.035)), TarocchiPigment.wood.shade, line: 0.5)
            }
        }
        paint(Path(box(c, s, 0, -0.27, 0.26, 0.05)), Tempera.gold, line: 0.7)
        paint(Path(box(c, s, 0, 0.39, 0.15, 0.05)), Tempera.gold, line: 0.7)
    }

    /// A lopped branch from `base` outward at `angle` (0 is up), its cut end pale.
    private func stub(_ base: CGPoint, _ s: CGFloat, angle: CGFloat) {
        let place = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: base.x, y: base.y))
        paint(Path(CGRect(x: -s * 0.035, y: -s * 0.13, width: s * 0.07, height: s * 0.13)).applying(place),
              TarocchiPigment.wood.body, line: 0.8)
        paint(Path(ellipseIn: CGRect(x: -s * 0.04, y: -s * 0.15, width: s * 0.08, height: s * 0.04)).applying(place),
              TarocchiPigment.flaxen.body, line: 0.6)
    }
}
