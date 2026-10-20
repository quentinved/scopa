import ScopaCore
import SwiftUI

/// The cavallo: a holly horse walking right across the foot of the card, its far legs in
/// harewood so they fall back, and the rider above in the suit's wood.
extension IntarsioPanel {
    func knight(_ suit: Suit, _ dress: IntarsioDress) {
        ground()
        horse(in: CGRect(x: 0.03 * w, y: 0.75 * w, width: 0.92 * w, height: 0.63 * w))
        rider(suit, dress)
        incise([(0.515, 0.785), (0.70, 0.86), (0.885, 0.925)], 0.006)
    }

    private func rider(_ suit: Suit, _ dress: IntarsioDress) {
        let cloak: [(CGFloat, CGFloat)] = [(0.41, 0.58), (0.31, 0.595), (0.21, 0.66), (0.14, 0.77), (0.12, 0.88),
                                           (0.20, 0.90), (0.29, 0.85), (0.37, 0.77), (0.41, 0.70)]
        lay(outline(cloak), dress.cloak, grain: .pi * 0.68, scorch: .lowerLeft)
        incise([(0.33, 0.63), (0.24, 0.72), (0.18, 0.85)], 0.005)
        incise([(0.37, 0.66), (0.30, 0.76), (0.25, 0.86)], 0.005)
        lay(outline([(0.29, 0.885), (0.56, 0.885), (0.575, 1.02), (0.43, 1.07), (0.30, 1.045)]), dress.gown,
            grain: 0, scorch: .down)
        layLimb([(0.30, 1.04), (0.43, 1.065), (0.57, 1.015)], [0.03, 0.03, 0.03], dress.trim, scorch: .none)
        lay(polygon([(0.37, 0.57), (0.51, 0.57), (0.53, 0.78), (0.55, 0.91), (0.33, 0.91), (0.35, 0.78)]),
            dress.gown, grain: .pi / 2, scorch: .right)
        lay(cut(Capsule(), 0.44, 0.80, 0.19, 0.035), dress.trim, grain: 0, scorch: .down)
        layLimb([(0.42, 0.885), (0.50, 0.915), (0.545, 0.96), (0.542, 1.03), (0.535, 1.095)],
                [0.10, 0.092, 0.085, 0.075, 0.065], dress.cloak, scorch: .right)
        layLimb([(0.53, 1.06), (0.535, 1.12), (0.585, 1.14)], [0.075, 0.07, 0.04], .ebony, scorch: .none)
        layLimb([(0.385, 0.60), (0.385, 0.72), (0.50, 0.78)], [0.085, 0.075, 0.065], dress.gown, scorch: .down)
        hand(0.515, 0.785, 0.036)
        layLimb([(0.49, 0.60), (0.60, 0.58), (0.67, 0.535)], [0.085, 0.075, 0.065], dress.gown, scorch: .down)
        held(suit, hand: 0.685, 0.525, size: 0.26)
        riderHead(dress)
    }

    private func riderHead(_ dress: IntarsioDress) {
        lay(polygon([(0.41, 0.53), (0.47, 0.53), (0.475, 0.58), (0.405, 0.58)]), .pear, scorch: .right)
        lay(cut(Capsule(), 0.44, 0.575, 0.18, 0.04), .holly, grain: 0, scorch: .down)
        lay(oval(0.44, 0.455, 0.10, 0.10), .walnut, grain: .pi / 2, scorch: .right)
        face(0.44, 0.475, 0.082, 0.098)
        layLimb([(0.465, 0.34), (0.475, 0.26), (0.53, 0.20)], [0.05, 0.055, 0.015], .holly, scorch: .right)
        lay(outline([(0.36, 0.385), (0.38, 0.31), (0.44, 0.295), (0.50, 0.31), (0.52, 0.385)]), dress.gown,
            grain: 0, scorch: .right)
        lay(oval(0.44, 0.39, 0.155, 0.032), dress.cloak, grain: 0, scorch: .down)
        lay(cut(Capsule(), 0.44, 0.365, 0.16, 0.025), dress.trim, grain: 0, scorch: .none)
    }

    // MARK: The horse

    // Leg spines, shoulder to hoof, against the horse's frame facing left; the near fore
    // lifted. The same walk Maiolica's horse takes.
    private static let nearFore: [CGPoint] = [
        CGPoint(x: 0.372, y: 0.470), CGPoint(x: 0.352, y: 0.560), CGPoint(x: 0.290, y: 0.622),
        CGPoint(x: 0.284, y: 0.700), CGPoint(x: 0.302, y: 0.744),
    ]
    private static let farFore: [CGPoint] = [
        CGPoint(x: 0.418, y: 0.478), CGPoint(x: 0.408, y: 0.596), CGPoint(x: 0.418, y: 0.706),
        CGPoint(x: 0.404, y: 0.848), CGPoint(x: 0.400, y: 0.944),
    ]
    private static let nearHind: [CGPoint] = [
        CGPoint(x: 0.818, y: 0.452), CGPoint(x: 0.788, y: 0.588), CGPoint(x: 0.842, y: 0.700),
        CGPoint(x: 0.850, y: 0.838), CGPoint(x: 0.852, y: 0.944),
    ]
    private static let farHind: [CGPoint] = [
        CGPoint(x: 0.756, y: 0.466), CGPoint(x: 0.728, y: 0.602), CGPoint(x: 0.780, y: 0.708),
        CGPoint(x: 0.792, y: 0.842), CGPoint(x: 0.794, y: 0.944),
    ]
    private static let foreWidths: [CGFloat] = [0.130, 0.096, 0.072, 0.058, 0.054]
    private static let hindWidths: [CGFloat] = [0.180, 0.118, 0.074, 0.058, 0.056]

    /// Drawn facing left in its own frame, on a panel turned over so it walks right.
    private func horse(in frame: CGRect) {
        var flipped = context
        flipped.translateBy(x: frame.maxX, y: frame.minY)
        flipped.scaleBy(x: -1, y: 1)
        let bench = IntarsioPanel(context: flipped, w: w, seed: seed &+ 5)
        let r = CGRect(origin: .zero, size: frame.size)
        bench.lay(HorseEar(offset: 0.044).path(in: r), .harewood, scorch: .none)
        bench.leg(Self.farHind, Self.hindWidths, .harewood, r)
        bench.leg(Self.farFore, Self.foreWidths, .harewood, r)
        let tail = [CGPoint(x: 0.878, y: 0.306), CGPoint(x: 0.952, y: 0.416), CGPoint(x: 0.984, y: 0.576), CGPoint(x: 0.940, y: 0.800)]
        bench.lay(Ribbon(spine: tail, widths: [0.078, 0.112, 0.086, 0.028]).path(in: r), .walnut, grain: .pi * 0.4, scorch: .none)
        bench.lay(HorseEar(offset: 0).path(in: r), .holly, scorch: .none)
        bench.lay(HorseBody().path(in: r), .holly, grain: 0.12, scorch: .down)
        let mane = [CGPoint(x: 0.236, y: 0.060), CGPoint(x: 0.318, y: 0.088), CGPoint(x: 0.390, y: 0.152), CGPoint(x: 0.452, y: 0.250)]
        bench.lay(Ribbon(spine: mane, widths: [0.050, 0.110, 0.120, 0.080]).path(in: r), .walnut, grain: .pi * 0.3, scorch: .none)
        bench.leg(Self.nearHind, Self.hindWidths, .holly, r)
        bench.leg(Self.nearFore, Self.foreWidths, .holly, r)
        bench.bridle(r)
    }

    /// A leg with its hoof in ebony.
    private func leg(_ spine: [CGPoint], _ widths: [CGFloat], _ wood: IntarsioWood, _ r: CGRect) {
        lay(Ribbon(spine: spine, widths: widths).path(in: r), wood, grain: .pi / 2, scorch: .side(0))
        let hoof = Ribbon(spine: Array(spine.suffix(2)), widths: [widths[3] * 1.05, widths[4] * 1.45])
        lay(hoof.path(in: r), .ebony, scorch: .none)
    }

    /// Eye, nostril and a brass-studded bridle on the horse's head.
    private func bridle(_ r: CGRect) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var straps = Path()
        straps.move(to: at(0.092, 0.212)); straps.addQuadCurve(to: at(0.130, 0.312), control: at(0.118, 0.268))
        straps.move(to: at(0.164, 0.126)); straps.addQuadCurve(to: at(0.226, 0.322), control: at(0.196, 0.226))
        context.stroke(straps, with: .color(IntarsioWood.padauk.face), lineWidth: max(0.5, w * 0.014))
        let eye = r.height * 0.024
        context.fill(Path(ellipseIn: CGRect(x: at(0.152, 0.186).x - eye, y: at(0.152, 0.186).y - eye, width: eye * 2,
                                            height: eye * 2.2)), with: .color(IntarsioWood.mastic))
        let stud = r.height * 0.02
        context.fill(Path(ellipseIn: CGRect(x: at(0.196, 0.226).x - stud, y: at(0.196, 0.226).y - stud, width: stud * 2,
                                            height: stud * 2)), with: .color(IntarsioWood.brass.face))
        let nostril = r.height * 0.014
        context.fill(Path(ellipseIn: CGRect(x: at(0.076, 0.272).x - nostril, y: at(0.076, 0.272).y - nostril,
                                            width: nostril * 2, height: nostril * 1.6)), with: .color(IntarsioWood.mastic))
    }
}
