import SwiftUI

/// Burano needle lace worked round a badge: a scalloped edge with a picot on each scallop,
/// a band of net held between two cords, and a flower worked solid in the net under every
/// other scallop. Ivory thread over the velvet `SeatLivery.trina` strikes the circle in.
///
/// Kept to the outer third of the circle, so the mark in the middle is never under thread.
/// Drawn once per badge and never moves.
struct LaceRing: View {
    let size: CGFloat

    /// The velvet the lace is laid on: Burano's aubergine, lit from the top left.
    static let velvetLight = Color(red: 0.302, green: 0.184, blue: 0.318)
    static let velvet = Color(red: 0.188, green: 0.110, blue: 0.200)
    static let velvetDeep = Color(red: 0.090, green: 0.051, blue: 0.098)
    /// Linen thread, a shade off white so it reads as thread rather than paint.
    static let thread = Color(red: 0.965, green: 0.945, blue: 0.886)

    /// The band the net fills, as fractions of the radius.
    private static let inner: CGFloat = 0.70
    private static let outer: CGFloat = 0.89
    private static let scallops = 14

    var body: some View {
        Canvas { context, canvas in
            let r = canvas.width / 2
            let centre = CGPoint(x: r, y: r)
            net(&context, centre, r)
            scallops(&context, centre, r)
            cords(&context, centre, r)
            flowers(&context, centre, r)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func point(_ centre: CGPoint, _ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
    }

    /// Diagonals crossing the band both ways, which is how a net reads at a badge's size.
    private func net(_ context: inout GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        var band = Path()
        band.addEllipse(in: CGRect(x: centre.x - r * Self.outer, y: centre.y - r * Self.outer,
                                   width: r * Self.outer * 2, height: r * Self.outer * 2))
        band.addEllipse(in: CGRect(x: centre.x - r * Self.inner, y: centre.y - r * Self.inner,
                                   width: r * Self.inner * 2, height: r * Self.inner * 2))
        var inside = context
        inside.clip(to: band, style: FillStyle(eoFill: true))
        let count = Self.scallops * 3
        let lean = 2 * CGFloat.pi / CGFloat(count) * 1.4
        var mesh = Path()
        for index in 0..<count {
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(count)
            for twist in [lean, -lean] {
                mesh.move(to: point(centre, r * (Self.inner - 0.04), angle))
                mesh.addLine(to: point(centre, r * (Self.outer + 0.04), angle + twist))
            }
        }
        inside.stroke(mesh, with: .color(Self.thread.opacity(0.55)), lineWidth: max(0.3, r * 0.016))
    }

    /// The edge: a scallop between every two stitches of the outer cord, filled thin, its
    /// rim corded, and a picot at the crown of each.
    private func scallops(_ context: inout GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        let step = 2 * CGFloat.pi / CGFloat(Self.scallops)
        var rims = Path(), picots = Path()
        for index in 0..<Self.scallops {
            let start = step * CGFloat(index) - .pi / 2
            var rim = Path()
            rim.move(to: point(centre, r * Self.outer, start))
            rim.addQuadCurve(to: point(centre, r * Self.outer, start + step),
                             control: point(centre, r * 1.06, start + step / 2))
            rims.addPath(rim)
            let crown = point(centre, r * 0.945, start + step / 2)
            let dot = r * 0.028
            picots.addEllipse(in: CGRect(x: crown.x - dot, y: crown.y - dot, width: dot * 2, height: dot * 2))
        }
        context.fill(rims, with: .color(Self.thread.opacity(0.22)))
        context.stroke(rims, with: .color(Self.thread), lineWidth: max(0.4, r * 0.03))
        context.fill(picots, with: .color(Self.velvetDeep))
        context.stroke(picots, with: .color(Self.thread), lineWidth: max(0.3, r * 0.018))
    }

    /// The raised cord either side of the net, the outline Burano works every motif in.
    private func cords(_ context: inout GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        for (radius, weight) in [(Self.inner, 0.040), (Self.outer, 0.034)] {
            let ring = Path(ellipseIn: CGRect(x: centre.x - r * radius, y: centre.y - r * radius,
                                              width: r * radius * 2, height: r * radius * 2))
            context.stroke(ring, with: .color(Self.thread), lineWidth: max(0.5, r * weight))
        }
    }

    /// Five petals worked solid, with the eye left open, under every other scallop.
    private func flowers(_ context: inout GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        let step = 2 * CGFloat.pi / CGFloat(Self.scallops)
        let middle = (Self.inner + Self.outer) / 2
        var petals = Path(), eyes = Path()
        for index in stride(from: 0, to: Self.scallops, by: 2) {
            let at = point(centre, r * middle, step * CGFloat(index) - .pi / 2 + step / 2)
            for petal in 0..<5 {
                let angle = 2 * CGFloat.pi * CGFloat(petal) / 5
                let tip = CGPoint(x: at.x + cos(angle) * r * 0.052, y: at.y + sin(angle) * r * 0.052)
                let leaf = r * 0.036
                petals.addEllipse(in: CGRect(x: tip.x - leaf, y: tip.y - leaf, width: leaf * 2, height: leaf * 2))
            }
            let eye = r * 0.022
            eyes.addEllipse(in: CGRect(x: at.x - eye, y: at.y - eye, width: eye * 2, height: eye * 2))
        }
        context.fill(petals, with: .color(Self.thread))
        context.fill(eyes, with: .color(Self.velvet))
    }
}

#Preview("Trina") {
    HStack(spacing: 20) {
        ForEach([26.0, 46.0, 72.0, 120.0], id: \.self) { size in
            SeatBadge(name: "Q", tint: Palette.seat(0), size: size, livery: .trina)
        }
    }
    .padding(30)
    .background(Palette.table)
}
