import SwiftUI

/// The Pergamena album's flourish: a wax seal pressed onto the cloth where the sweep was.
///
/// Stamped rather than thrown. The seal comes down out of the room, lands with a
/// ripple of wax, sits long enough to be read and lifts away — a flourish for an album
/// printed on parchment, where the others are paper, fire and gold.
///
/// One `Canvas` on its own clock, like the rest of them, so it costs one layer and plays
/// its own curves instead of SwiftUI's two-ended interpolation.
struct Sigillo: View {
    var origin: UnitPoint

    @State private var start = Date.now
    @State private var isDone = false

    private static let length: TimeInterval = 2.0
    /// When the seal lands, as a share of the whole.
    private static let impact: CGFloat = 0.16

    private static let wax = Color(red: 0.659, green: 0.196, blue: 0.165)
    private static let waxLight = Color(red: 0.851, green: 0.404, blue: 0.353)
    private static let waxDeep = Color(red: 0.431, green: 0.106, blue: 0.086)

    var body: some View {
        TimelineView(.animation(paused: isDone)) { timeline in
            let phase = CGFloat(min(timeline.date.timeIntervalSince(start) / Self.length, 1))
            Canvas { context, size in
                paint(&context, size: size, phase: phase)
            }
        }
        // Stops the clock once it has lifted, so a banner that lingers costs nothing.
        .task {
            try? await Task.sleep(for: .seconds(Self.length + 0.1))
            isDone = true
        }
    }

    private func paint(_ context: inout GraphicsContext, size: CGSize, phase: CGFloat) {
        guard phase < 1 else { return }
        // A seal the size of a coin on the table, and a third of the tile on the shop's shelf.
        let side = min(size.width, size.height)
        let radius = min(side * 0.34, max(side * 0.14, 34), 78)
        let centre = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        ripple(&context, at: centre, radius: radius, phase: phase)

        var seal = context
        seal.opacity = Double(presence(phase))
        seal.translateBy(x: centre.x, y: centre.y)
        let scale = scale(phase)
        seal.scaleBy(x: scale, y: scale)
        shadow(&seal, radius: radius, phase: phase)
        disc(&seal, radius: radius)
        emblem(&seal, radius: radius)
    }

    // MARK: Timing

    /// Big and faint while it is still in the air, full size on landing, a breath wider as
    /// the wax gives, and a touch smaller as it is lifted off.
    private func scale(_ phase: CGFloat) -> CGFloat {
        let landing = Self.impact
        if phase < landing {
            let fall = phase / landing
            return 1.9 - 0.9 * fall * fall
        }
        let after = phase - landing
        if after < 0.1 { return 1 + 0.06 * sin(after / 0.1 * .pi) }
        return phase > 0.8 ? 1 - (phase - 0.8) * 0.2 : 1
    }

    private func presence(_ phase: CGFloat) -> CGFloat {
        if phase < Self.impact { return phase / Self.impact }
        if phase > 0.8 { return max(0, 1 - (phase - 0.8) / 0.2) }
        return 1
    }

    // MARK: Drawing

    /// The give of the wax, run out across the cloth once on landing.
    private func ripple(_ context: inout GraphicsContext, at centre: CGPoint, radius: CGFloat, phase: CGFloat) {
        let age = (phase - Self.impact) / 0.4
        guard age > 0, age < 1 else { return }
        let spread = radius * (1.05 + 1.5 * (1 - pow(1 - age, 2.4)))
        let ring = CGRect(x: centre.x - spread, y: centre.y - spread, width: spread * 2, height: spread * 2)
        context.stroke(Circle().path(in: ring),
                       with: .color(Self.waxLight.opacity(Double(0.55 * (1 - age)))),
                       lineWidth: 3 + 6 * (1 - age))
    }

    /// Soft under the seal while it hangs, tight once it is down.
    private func shadow(_ context: inout GraphicsContext, radius: CGFloat, phase: CGFloat) {
        let lift = phase < Self.impact ? 1 - phase / Self.impact : 0
        let spread = radius * (1.05 + 0.25 * lift)
        let drop = radius * (0.06 + 0.3 * lift)
        let rect = CGRect(x: -spread, y: -spread + drop, width: spread * 2, height: spread * 2)
        context.fill(Circle().path(in: rect),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.35), .black.opacity(0)]),
                                           center: CGPoint(x: 0, y: drop), startRadius: radius * 0.6,
                                           endRadius: spread))
    }

    /// The pool of wax, never quite round, with the die's own ring pressed into it.
    private func disc(_ context: inout GraphicsContext, radius: CGFloat) {
        let pool = Self.pool(radius: radius)
        context.fill(pool, with: .radialGradient(Gradient(colors: [Self.waxLight, Self.wax, Self.waxDeep]),
                                                 center: CGPoint(x: -radius * 0.25, y: -radius * 0.3),
                                                 startRadius: 0, endRadius: radius * 1.25))
        let die = radius * 0.7
        let face = CGRect(x: -die, y: -die, width: die * 2, height: die * 2)
        context.fill(Circle().path(in: face), with: .color(Self.wax))
        context.stroke(Circle().path(in: face), with: .color(Self.waxDeep), lineWidth: max(1.5, radius * 0.04))
        context.stroke(Circle().path(in: face.insetBy(dx: -1.5, dy: -1.5)),
                       with: .color(Self.waxLight.opacity(0.6)), lineWidth: 1)
        // The beading a seal's die has round its edge.
        for index in 0..<24 {
            let angle = Double(index) / 24 * 2 * .pi
            let at = CGPoint(x: cos(angle) * die * 0.86, y: sin(angle) * die * 0.86)
            let bead = radius * 0.035
            context.fill(Circle().path(in: CGRect(x: at.x - bead, y: at.y - bead, width: bead * 2, height: bead * 2)),
                         with: .color(Self.waxLight.opacity(0.8)))
        }
        // The light off the top of the wax, which is what makes it wax and not paint.
        var gloss = Path()
        gloss.addArc(center: .zero, radius: radius * 0.86, startAngle: .degrees(200), endAngle: .degrees(250),
                     clockwise: false)
        context.stroke(gloss, with: .color(.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: radius * 0.07, lineCap: .round))
    }

    /// The house broom, struck into the middle: drawn once dark and once light, a hair
    /// apart, so it reads as pressed in rather than painted on.
    private func emblem(_ context: inout GraphicsContext, radius: CGFloat) {
        let broom = Self.broom(radius: radius)
        var sunk = context
        sunk.translateBy(x: radius * 0.02, y: radius * 0.035)
        sunk.fill(broom, with: .color(Self.waxDeep))
        context.fill(broom, with: .color(Self.waxLight))
    }

    // MARK: Shapes

    /// A circle with a wandering edge: eighteen points, each pushed in or out by two waves
    /// that do not line up, joined through their midpoints so the edge stays soft.
    private static func pool(radius: CGFloat) -> Path {
        let count = 18
        let points = (0..<count).map { index -> CGPoint in
            let angle = Double(index) / Double(count) * 2 * .pi
            let wobble = 1 + 0.07 * sin(Double(index) * 2.3) + 0.05 * cos(Double(index) * 3.7)
            return CGPoint(x: cos(angle) * radius * wobble, y: sin(angle) * radius * wobble)
        }
        func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: middle(points[count - 1], points[0]))
        for index in 0..<count {
            path.addQuadCurve(to: middle(points[index], points[(index + 1) % count]), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    /// A handle and a fan of straw, bound in the middle, as the app's icon draws it.
    private static func broom(radius: CGFloat) -> Path {
        let unit = radius * 0.42
        var path = Path()
        path.addRoundedRect(in: CGRect(x: -unit * 0.08, y: -unit * 1.05, width: unit * 0.16, height: unit * 1.05),
                            cornerSize: CGSize(width: unit * 0.08, height: unit * 0.08))
        path.addRect(CGRect(x: -unit * 0.26, y: -unit * 0.08, width: unit * 0.52, height: unit * 0.16))
        path.move(to: CGPoint(x: -unit * 0.24, y: unit * 0.1))
        path.addLine(to: CGPoint(x: unit * 0.24, y: unit * 0.1))
        path.addLine(to: CGPoint(x: unit * 0.62, y: unit * 1.0))
        path.addQuadCurve(to: CGPoint(x: -unit * 0.62, y: unit * 1.0), control: CGPoint(x: 0, y: unit * 1.14))
        path.closeSubpath()
        return path
    }
}

#Preview("Sigillo") {
    ZStack {
        TableGround()
        Sigillo(origin: .center)
    }
}
