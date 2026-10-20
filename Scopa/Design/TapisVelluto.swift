import SwiftUI

// MARK: Velluto

extension TapisWeave {
    /// Velvet: a deeper pile than felt, crushed lighter and darker where hands have been
    /// across it, powdered with small roses couched in gold, the way a brocaded velvet is
    /// woven.
    func velluto(_ context: inout GraphicsContext, whole: CGRect, visible: CGRect) {
        pile(&context, in: whole)
        var petals = Path(), knots = Path()
        for centre in halfDrop(in: whole, centredOn: visible, across: pt(96), down: pt(118)) {
            let radius = pt(15)
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4 - .pi / 2
                petals.addPath(leaf(from: offset(centre, by: unit(angle), radius * 0.34),
                                    to: offset(centre, by: unit(angle), radius), width: radius * 0.17))
            }
            knots.addPath(knot(at: centre, reach: radius * 0.3))
        }
        context.fill(petals, with: gilt(in: visible, 0.07))
        raise(petals, in: &context, with: gilt(in: visible, 0.3), width: 0.8)
        raiseFill(knots, in: &context, with: gilt(in: visible, 0.42))
    }

    /// The pile: a shade deeper all over, and crushed in soft patches.
    func pile(_ context: inout GraphicsContext, in rect: CGRect) {
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
    }

    /// An eight-pointed knot with hollow flanks.
    func knot(at centre: CGPoint, reach: CGFloat) -> Path {
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
