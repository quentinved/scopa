import SwiftUI

// MARK: Velluto

extension TapisWeave {
    /// Velvet: a deeper pile than felt, crushed lighter and darker where hands have been
    /// across it, piped round the edge in a twisted gold cord that throws its shadow on the
    /// pile, with a beaded gimp inside it and a rose couched in gold thread in the middle.
    ///
    /// Everything the other cloths have, and the one thing none of them has: an object on
    /// the table that is solid metal rather than thread, lit from the lamp's corner.
    func velluto(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        pile(&context, in: whole, visible: visible)
        let cord = visible.insetBy(dx: pt(15), dy: pt(15))
        let radius = pt(46)
        rose(&context, at: CGPoint(x: visible.midX, y: visible.midY),
             radius: min(pt(118), visible.width * 0.36), light: visible)
        gimp(&context, along: cord.insetBy(dx: pt(12), dy: pt(12)), radius: radius - pt(12), light: visible)
        piping(&context, along: cord, radius: radius)
    }

    /// The pile: a shade deeper all over, crushed in soft patches, and pressed darker just
    /// inside the cord where the cord sits on it.
    private func pile(_ context: inout GraphicsContext, in rect: CGRect, visible: CGRect) {
        context.fill(Path(rect), with: .color(.black.opacity(0.2)))
        var dice = TapisDice(state: 0x7E1_7E70_0BAD)
        let patches = max(18, Int(rect.width * rect.height / (pt(120) * pt(120))))
        for index in 0..<patches {
            let centre = CGPoint(x: rect.minX + dice.unit() * rect.width, y: rect.minY + dice.unit() * rect.height)
            let reach = pt(50 + dice.unit() * 110)
            let tone = index.isMultiple(of: 3) ? Color.black.opacity(0.16) : Palette.cream.opacity(0.055)
            context.fill(disc(at: centre, radius: reach),
                         with: .radialGradient(Gradient(colors: [tone, tone.opacity(0)]),
                                               center: centre, startRadius: 0, endRadius: reach))
        }
        let pressed = roundedPath(visible.insetBy(dx: pt(22), dy: pt(22)), radius: pt(40))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: pt(9)))
            layer.stroke(pressed, with: .color(.black.opacity(0.4)), lineWidth: pt(14))
        }
    }

    /// The cord: a dark core, then strands laid at a slant all the way round, each lit on
    /// whichever side of the cord faces the lamp — the top on the top edge, the inside on
    /// the right — so the cord turns in the light as it goes round the table.
    private func piping(_ context: inout GraphicsContext, along rect: CGRect, radius: CGFloat) {
        let path = roundedPath(rect, radius: radius)
        let thick = max(pt(6.5), 1.6)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(pt(2.2), 0.6)))
            layer.stroke(path.offsetBy(dx: pt(1.4), dy: pt(2.4)),
                         with: .color(.black.opacity(0.6)), lineWidth: thick + pt(1.5))
        }
        context.stroke(path, with: .color(Palette.goldDeep), lineWidth: thick)

        var strands = Path(), lit = Path(), dark = Path()
        for stitch in walk(rect, radius: radius, step: thick * 0.52) {
            let towards: CGFloat = (stitch.inward.x * Self.lamp.x + stitch.inward.y * Self.lamp.y) > 0 ? 1 : -1
            let a = offset(offset(stitch.point, by: stitch.inward, -thick / 2), by: stitch.along, -thick * 0.42)
            let b = offset(offset(stitch.point, by: stitch.inward, thick / 2), by: stitch.along, thick * 0.42)
            strands.addPath(leaf(from: a, to: b, width: thick * 0.2))
            let bright = towards > 0 ? b : a
            let dim = towards > 0 ? a : b
            lit.move(to: mix(stitch.point, bright, 0.1))
            lit.addLine(to: mix(stitch.point, bright, 0.7))
            dark.move(to: mix(stitch.point, dim, 0.3))
            dark.addLine(to: mix(stitch.point, dim, 0.9))
        }
        context.fill(strands, with: .color(Palette.gold))
        context.stroke(dark, with: .color(Palette.goldDeep.opacity(0.9)),
                       style: StrokeStyle(lineWidth: max(thick * 0.16, 0.4), lineCap: .round))
        context.stroke(lit, with: .color(Palette.goldLight),
                       style: StrokeStyle(lineWidth: max(thick * 0.14, 0.4), lineCap: .round))
    }

    /// A gold line with beads strung along it, a finger inside the cord.
    private func gimp(_ context: inout GraphicsContext, along rect: CGRect, radius: CGFloat, light: CGRect) {
        raise(roundedPath(rect, radius: radius), in: &context, with: gilt(in: light, 0.45), width: 0.8)
        var beads = Path()
        for stitch in walk(rect, radius: radius, step: max(pt(11), 3)) {
            beads.addPath(disc(at: stitch.point, radius: max(pt(1.5), 0.45)))
        }
        raiseFill(beads, in: &context, with: gilt(in: light, 0.75))
    }

    /// Point `t` of the way from `a` to `b`.
    private func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: The rose

extension TapisWeave {
    /// A rose window couched in gold thread: a beaded double ring, twelve pointed petals
    /// with a vein down each and a smaller leaf between, and a knot at the heart. Drawn
    /// thin and pale so the cards dealt onto it read first.
    private func rose(_ context: inout GraphicsContext, at centre: CGPoint, radius: CGFloat,
                          light: CGRect) {
        var rings = Path(), petals = Path(), veins = Path(), beads = Path()
        rings.addPath(disc(at: centre, radius: radius))
        rings.addPath(disc(at: centre, radius: radius * 0.93))
        rings.addPath(disc(at: centre, radius: radius * 0.26))
        for index in 0..<48 {
            let angle = Double(index) * .pi / 24
            beads.addPath(disc(at: offset(centre, by: unit(angle), radius * 0.965), radius: radius * 0.011))
        }
        for index in 0..<12 {
            let angle = Double(index) * .pi / 6 - .pi / 2
            let base = offset(centre, by: unit(angle), radius * 0.3)
            let tip = offset(centre, by: unit(angle), radius * 0.86)
            petals.addPath(leaf(from: base, to: tip, width: radius * 0.13))
            veins.move(to: offset(centre, by: unit(angle), radius * 0.36))
            veins.addLine(to: offset(centre, by: unit(angle), radius * 0.74))
            let between = angle + .pi / 12
            petals.addPath(leaf(from: offset(centre, by: unit(between), radius * 0.6),
                                to: offset(centre, by: unit(between), radius * 0.84), width: radius * 0.05))
        }
        context.fill(petals, with: gilt(in: light, 0.06))
        raise(petals, in: &context, with: gilt(in: light, 0.3), width: 0.9)
        context.stroke(veins, with: gilt(in: light, 0.22), lineWidth: hair(0.6))
        raise(rings, in: &context, with: gilt(in: light, 0.32), width: 0.9)
        context.fill(beads, with: gilt(in: light, 0.42))
        raiseFill(knot(at: centre, reach: radius * 0.17), in: &context, with: gilt(in: light, 0.42))
    }

    /// An eight-pointed knot with hollow flanks.
    private func knot(at centre: CGPoint, reach: CGFloat) -> Path {
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let point = offset(centre, by: unit(angle), index.isMultiple(of: 2) ? reach : reach * 0.62)
            let waist = offset(centre, by: unit(angle + .pi / 8), reach * 0.28)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            path.addLine(to: waist)
        }
        path.closeSubpath()
        return path
    }
}
