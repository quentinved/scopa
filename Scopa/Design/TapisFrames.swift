import SwiftUI

// MARK: Campo

extension TapisWeave {
    /// A playing field: a gold rule and a cream one inside it, both notched at the corners
    /// the way a court or a board is, with a jewel set into the rail at the middle of each
    /// side and a lozenge just inside each notch. Nothing crosses the middle of the table.
    func campo(_ context: inout GraphicsContext, whole: CGRect, in rect: CGRect) {
        let outer = rect.insetBy(dx: pt(16), dy: pt(16))
        let gap = pt(5)
        let notch = pt(30)
        let inner = outer.insetBy(dx: gap, dy: gap)
        guard inner.width > notch * 2, inner.height > notch * 2 else { return }

        // The rail outside the rule is a darker stuff than the field inside it, the way a
        // card table's leather rail frames its baize.
        var rail = Path(whole)
        rail.addPath(notched(outer, notch: notch))
        context.fill(rail, with: .color(.black.opacity(0.13)), style: FillStyle(eoFill: true))
        raise(notched(outer, notch: notch), in: &context, with: gilt(in: rect, 0.6), width: 1.3)
        // A smaller notch on the inner rule keeps the two a gap apart on the diagonal too.
        raise(notched(inner, notch: notch - gap * 0.414), in: &context,
              with: Self.cream(0.2), width: 0.7, height: 0.6)
        campoJewels(&context, outer: outer, gap: gap, notch: notch, light: rect)
    }

    /// The jewel at the middle of each side and the lozenge inside each corner.
    private func campoJewels(_ context: inout GraphicsContext, outer: CGRect, gap: CGFloat,
                             notch: CGFloat, light: CGRect) {
        let rail = outer.insetBy(dx: gap / 2, dy: gap / 2)
        var jewels = Path()
        for (point, axis) in [(CGPoint(x: rail.midX, y: rail.minY), CGPoint(x: 1, y: 0)),
                              (CGPoint(x: rail.midX, y: rail.maxY), CGPoint(x: 1, y: 0)),
                              (CGPoint(x: rail.minX, y: rail.midY), CGPoint(x: 0, y: 1)),
                              (CGPoint(x: rail.maxX, y: rail.midY), CGPoint(x: 0, y: 1))] {
            jewels.addPath(lozenge(at: point, long: pt(16), wide: pt(7), axis: axis))
        }
        raiseFill(jewels, in: &context, with: gilt(in: light, 0.75))

        // In each corner a thread echoing the notch, ended on the inner rule, and a lozenge
        // set just beyond it on the diagonal.
        var outlines = Path(), hearts = Path(), echoes = Path()
        let reach = notch + gap * 2.6
        let spread = Double.pi / 4 - asin(Double(gap / reach))
        for (corner, inward) in corners(of: outer) {
            let facing = atan2(Double(inward.y), Double(inward.x))
            arc(&echoes, centre: corner, radius: reach, from: facing - spread, to: facing + spread, joined: false)
            let centre = offset(corner, by: inward, reach + pt(14))
            outlines.addPath(lozenge(at: centre, long: pt(15), wide: pt(15)))
            hearts.addPath(lozenge(at: centre, long: pt(5.5), wide: pt(5.5)))
        }
        raise(echoes, in: &context, with: gilt(in: light, 0.4), width: 0.7, height: 0.6)
        raise(outlines, in: &context, with: gilt(in: light, 0.55), width: 0.9)
        raiseFill(hearts, in: &context, with: gilt(in: light, 0.6))
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

    /// The four corners of a rectangle, each with the diagonal that leads into it.
    func corners(of rect: CGRect) -> [(CGPoint, CGPoint)] {
        let d: CGFloat = 0.707_106_78
        return [(CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: d, y: d)),
                (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: -d, y: d)),
                (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: -d, y: -d)),
                (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: d, y: -d))]
    }
}

// MARK: Ventaglio

extension TapisWeave {
    /// Art deco: a field of scales inside a double rule, a pleated fan opening out of each
    /// rounded corner and a half fan let into the middle of each side.
    ///
    /// The corner of the rule is the fan's own rim, so the frame and the fans are one
    /// drawing rather than ornaments stood on a border.
    func ventaglio(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        let frame = visible.insetBy(dx: pt(16), dy: pt(16))
        let radius = pt(74)
        let gap = pt(5)
        let inner = frame.insetBy(dx: gap, dy: gap)
        guard inner.width > radius * 2, inner.height > radius * 2 else { return }

        var field = context
        field.clip(to: roundedPath(inner.insetBy(dx: pt(3), dy: pt(3)), radius: radius - gap - pt(3)))
        scales(&field, in: inner)

        raise(roundedPath(frame, radius: radius), in: &context, with: gilt(in: visible, 0.6), width: 1.3)
        raise(roundedPath(inner, radius: radius - gap), in: &context,
              with: Self.cream(0.2), width: 0.7, height: 0.6)
        ventaglioFans(&context, frame: frame, radius: radius, gap: gap, light: visible)
    }

    private func ventaglioFans(_ context: inout GraphicsContext, frame: CGRect, radius: CGFloat,
                               gap: CGFloat, light: CGRect) {
        let reach = radius - gap - pt(10)
        let hubs = [(CGPoint(x: frame.minX + radius, y: frame.minY + radius), Double.pi),
                    (CGPoint(x: frame.maxX - radius, y: frame.minY + radius), Double.pi * 1.5),
                    (CGPoint(x: frame.maxX - radius, y: frame.maxY - radius), 0),
                    (CGPoint(x: frame.minX + radius, y: frame.maxY - radius), Double.pi / 2)]
        for (hub, start) in hubs {
            fan(&context, hub: hub, radius: reach, from: start, sweep: .pi / 2, blades: 7, light: light)
        }
        let rail = frame.insetBy(dx: gap / 2, dy: gap / 2)
        let sides = [(CGPoint(x: rail.minX, y: rail.midY), -Double.pi / 2),
                     (CGPoint(x: rail.maxX, y: rail.midY), Double.pi / 2),
                     (CGPoint(x: rail.midX, y: rail.minY), 0),
                     (CGPoint(x: rail.midX, y: rail.maxY), Double.pi)]
        for (hub, start) in sides {
            fan(&context, hub: hub, radius: pt(34), from: start, sweep: .pi, blades: 9, light: light)
        }
    }

    /// One fan: pleats alternately gilt and bare, a rib between each, a scalloped rim, two
    /// bands of thread across it and a gold boss at the hub. The cloth under it is cleared
    /// first, so the rule and the scales stop at its edge rather than showing through.
    private func fan(_ context: inout GraphicsContext, hub: CGPoint, radius: CGFloat, from start: Double,
                     sweep: Double, blades: Int, light: CGRect) {
        let angles = (0...blades).map { start + sweep * Double($0) / Double(blades) }
        var clearing = Path()
        clearing.move(to: hub)
        arc(&clearing, centre: hub, radius: radius * 1.1 + pt(2), from: start, to: start + sweep, joined: true)
        clearing.closeSubpath()
        context.blendMode = .clear
        context.fill(clearing, with: .color(.black))
        context.blendMode = .normal

        var gilded = Path(), bare = Path(), rim = Path(), ribs = Path()
        for index in 0..<blades {
            let (a, b) = (angles[index], angles[index + 1])
            let from = offset(hub, by: unit(a), radius)
            let to = offset(hub, by: unit(b), radius)
            let crest = offset(hub, by: unit((a + b) / 2), radius * 1.16)
            var pleat = Path()
            pleat.move(to: hub)
            pleat.addLine(to: from)
            pleat.addQuadCurve(to: to, control: crest)
            pleat.closeSubpath()
            if index.isMultiple(of: 2) { gilded.addPath(pleat) } else { bare.addPath(pleat) }
            rim.move(to: from)
            rim.addQuadCurve(to: to, control: crest)
        }
        for angle in angles {
            ribs.move(to: offset(hub, by: unit(angle), pt(5)))
            ribs.addLine(to: offset(hub, by: unit(angle), radius))
        }
        context.fill(gilded, with: gilt(in: light, 0.16))
        context.fill(bare, with: .color(.black.opacity(0.08)))
        raise(ribs, in: &context, with: gilt(in: light, 0.5), width: 0.8, height: 0.6)
        fanBands(&context, hub: hub, radius: radius, angles: angles)
        raise(rim, in: &context, with: gilt(in: light, 0.65), width: 1.1)
        raiseFill(disc(at: hub, radius: pt(5.5)), in: &context, with: gilt(in: light, 0.8))
    }

    /// The two arcs of thread across a fan, and a gold bead in each pleat between them.
    private func fanBands(_ context: inout GraphicsContext, hub: CGPoint, radius: CGFloat, angles: [Double]) {
        guard let first = angles.first, let last = angles.last else { return }
        var bands = Path()
        arc(&bands, centre: hub, radius: radius * 0.4, from: first, to: last, joined: false)
        arc(&bands, centre: hub, radius: radius * 0.7, from: first, to: last, joined: false)
        context.stroke(bands, with: Self.cream(0.3), lineWidth: hair(0.7))
        var beads = Path()
        for index in 0..<(angles.count - 1) {
            let middle = (angles[index] + angles[index + 1]) / 2
            beads.addPath(disc(at: offset(hub, by: unit(middle), radius * 0.55), radius: pt(1.3)))
        }
        context.fill(beads, with: .color(Palette.goldLight.opacity(0.6)))
    }

    /// Fish scales, each three rings deep, laid a row at a time so every row covers the
    /// foot of the one before it — the way scales lie.
    private func scales(_ context: inout GraphicsContext, in rect: CGRect) {
        let r = pt(19)
        var y = rect.minY - r
        var row = 0
        while y < rect.maxY + r {
            var discs = Path()
            var rings = Path()
            var x = rect.minX - r * 2 + (row.isMultiple(of: 2) ? 0 : r)
            while x < rect.maxX + r * 2 {
                let centre = CGPoint(x: x, y: y)
                discs.addPath(disc(at: centre, radius: r))
                for ring in [1.0, 0.68, 0.36] { rings.addPath(disc(at: centre, radius: r * ring)) }
                x += r * 2
            }
            context.blendMode = .clear
            context.fill(discs, with: .color(.black))
            context.blendMode = .normal
            context.stroke(rings, with: Self.cream(0.075), lineWidth: hair(0.8))
            y += r / 2
            row += 1
        }
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
