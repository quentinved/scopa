import SwiftUI

// MARK: Campo

extension TapisWeave {
    /// A floor of panels laid on the diagonal, each ruled in gold and notched at its
    /// corners, with a jewel in the round where four notches meet. On the diagonal so the
    /// floor never lines up with the cards or the panels of glass over it into a grid of
    /// boxes.
    func campo(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        let size = pt(56)
        let gap = pt(2.5)
        let turn = CGAffineTransform(translationX: visible.midX, y: visible.midY).rotated(by: .pi / 4)
        let count = Int((hypot(whole.width, whole.height) / 2 / size).rounded(.up))
        var rules = Path(), jewels = Path()
        for row in -count..<count {
            for column in -count..<count {
                let cell = CGRect(x: CGFloat(column) * size, y: CGFloat(row) * size, width: size, height: size)
                rules.addPath(notched(cell.insetBy(dx: gap, dy: gap), notch: pt(11)))
                jewels.addPath(lozenge(at: cell.origin.applying(turn), long: pt(7), wide: pt(7)))
            }
        }
        rules = rules.applying(turn)
        context.stroke(rules.offsetBy(dx: pt(0.5), dy: pt(0.8)), with: .color(.black.opacity(0.14)),
                       lineWidth: hair(0.7))
        context.stroke(rules, with: gilt(in: visible, 0.24), lineWidth: hair(0.7))
        raiseFill(jewels, in: &context, with: gilt(in: visible, 0.42))
    }

    /// A rectangle with a quarter circle bitten out of each corner.
    func notched(_ rect: CGRect, notch: CGFloat) -> Path {
        let k = 0.552_284_75 * notch
        let (left, right, top, bottom) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        var path = Path()
        path.move(to: CGPoint(x: left + notch, y: top))
        path.addLine(to: CGPoint(x: right - notch, y: top))
        path.addCurve(to: CGPoint(x: right, y: top + notch),
                      control1: CGPoint(x: right - notch, y: top + k), control2: CGPoint(x: right - k, y: top + notch))
        path.addLine(to: CGPoint(x: right, y: bottom - notch))
        path.addCurve(to: CGPoint(x: right - notch, y: bottom),
                      control1: CGPoint(x: right - k, y: bottom - notch), control2: CGPoint(x: right - notch, y: bottom - k))
        path.addLine(to: CGPoint(x: left + notch, y: bottom))
        path.addCurve(to: CGPoint(x: left, y: bottom - notch),
                      control1: CGPoint(x: left + notch, y: bottom - k), control2: CGPoint(x: left + k, y: bottom - notch))
        path.addLine(to: CGPoint(x: left, y: top + notch))
        path.addCurve(to: CGPoint(x: left + notch, y: top),
                      control1: CGPoint(x: left + k, y: top + notch), control2: CGPoint(x: left + notch, y: top + k))
        path.closeSubpath()
        return path
    }
}

// MARK: Ventaglio

extension TapisWeave {
    /// Art deco: fish scales all over, and here and there a pleated fan laid open on them.
    func ventaglio(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        scales(&context, in: whole) { row, column in
            row.isMultiple(of: 8) && (column + row / 8 * 3).isMultiple(of: 6)
        } fan: { context, hub, radius in
            pleats(&context, hub: hub, radius: radius * 1.1, light: visible)
        }
    }

    /// A fan opening upwards from a scale's hub: seven pleats, alternately gilt and bare,
    /// ribbed and scalloped in gold, standing on a gold guard. The scales under it are
    /// cleared first, so they stop at its edge rather than showing through.
    private func pleats(_ context: inout GraphicsContext, hub: CGPoint, radius: CGFloat, light: CGRect) {
        let blades = 7
        let angles = (0...blades).map { Double.pi + .pi * Double($0) / Double(blades) }
        clearFan(&context, hub: hub, radius: radius * 1.14 + pt(1.5))
        var gilded = Path(), rim = Path(), ribs = Path(), guardRail = Path()
        for index in 0..<blades {
            let (a, b) = (angles[index], angles[index + 1])
            let from = offset(hub, by: unit(a), radius)
            let to = offset(hub, by: unit(b), radius)
            let crest = offset(hub, by: unit((a + b) / 2), radius * 1.14)
            if index.isMultiple(of: 2) {
                gilded.move(to: hub)
                gilded.addLine(to: from)
                gilded.addQuadCurve(to: to, control: crest)
                gilded.closeSubpath()
            }
            rim.move(to: from)
            rim.addQuadCurve(to: to, control: crest)
            if index > 0 {
                ribs.move(to: offset(hub, by: unit(a), pt(3)))
                ribs.addLine(to: from)
            }
        }
        guardRail.move(to: CGPoint(x: hub.x - radius * 1.25, y: hub.y))
        guardRail.addLine(to: CGPoint(x: hub.x + radius * 1.25, y: hub.y))
        context.fill(gilded, with: gilt(in: light, 0.14))
        context.stroke(ribs, with: gilt(in: light, 0.3), lineWidth: hair(0.6))
        raise(rim, in: &context, with: gilt(in: light, 0.45), width: 0.8, height: 0.5)
        raise(guardRail, in: &context, with: gilt(in: light, 0.4), width: 0.8, height: 0.5)
        raiseFill(disc(at: hub, radius: pt(2.6)), in: &context, with: gilt(in: light, 0.55))
    }

    /// Clears the half disc a fan stands in.
    private func clearFan(_ context: inout GraphicsContext, hub: CGPoint, radius: CGFloat) {
        var clearing = Path()
        clearing.move(to: hub)
        arc(&clearing, centre: hub, radius: radius, from: .pi, to: 2 * .pi, joined: true)
        clearing.closeSubpath()
        context.blendMode = .clear
        context.fill(clearing, with: .color(.black))
        context.blendMode = .normal
    }

    /// Fish scales, each three rings deep, laid a row at a time so every row covers the
    /// foot of the one before it — the way scales lie.
    ///
    /// `opens` picks, by row and column, the scales a fan is laid on once every row is
    /// down, which `fan` draws from that scale's hub at the scale's radius.
    func scales(_ context: inout GraphicsContext, in rect: CGRect,
                opens: (Int, Int) -> Bool = { _, _ in false },
                fan: (inout GraphicsContext, CGPoint, CGFloat) -> Void = { _, _, _ in }) {
        let r = pt(19)
        var y = rect.minY - r
        var row = 0
        var hubs: [CGPoint] = []
        while y < rect.maxY + r {
            var discs = Path(), rings = Path()
            var x = rect.minX - r * 2 + (row.isMultiple(of: 2) ? 0 : r)
            var column = 0
            while x < rect.maxX + r * 2 {
                let centre = CGPoint(x: x, y: y)
                discs.addPath(disc(at: centre, radius: r))
                for ring in [1.0, 0.68, 0.36] { rings.addPath(disc(at: centre, radius: r * ring)) }
                if opens(row, column) { hubs.append(centre) }
                x += r * 2
                column += 1
            }
            context.blendMode = .clear
            context.fill(discs, with: .color(.black))
            context.blendMode = .normal
            context.stroke(rings, with: Self.cream(0.075), lineWidth: hair(0.8))
            y += r / 2
            row += 1
        }
        for hub in hubs { fan(&context, hub, r) }
    }

    /// An arc as cubics no more than a quarter turn long, so it holds its shape at any
    /// size. Angles are in radians, measured the way the screen turns.
    func arc(_ path: inout Path, centre: CGPoint, radius: CGFloat, from start: Double, to end: Double,
             joined: Bool) {
        let segments = max(1, Int((abs(end - start) / (.pi / 2)).rounded(.up)))
        let step = (end - start) / Double(segments)
        let k = radius * 4 / 3 * tan(step / 4)
        let first = offset(centre, by: unit(start), radius)
        if joined { path.addLine(to: first) } else { path.move(to: first) }
        var angle = start
        for _ in 0..<segments {
            let next = angle + step
            let p1 = offset(centre, by: unit(angle), radius)
            let p2 = offset(centre, by: unit(next), radius)
            path.addCurve(to: p2,
                          control1: CGPoint(x: p1.x - sin(angle) * k, y: p1.y + cos(angle) * k),
                          control2: CGPoint(x: p2.x + sin(next) * k, y: p2.y - cos(next) * k))
            angle = next
        }
    }
}
