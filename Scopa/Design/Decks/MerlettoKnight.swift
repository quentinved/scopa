import ScopaCore
import SwiftUI

/// The cavallo: a linen horse walking right across the foot of the card, its far legs in
/// réseau so they fall back, a saddle cloth in the suit's thread, and the rider above.
extension MerlettoPillow {
    func knight(_ suit: Suit) {
        let house = MerlettoThread.house(suit)
        ground()
        horse(in: CGRect(x: 0.03 * w, y: 0.75 * w, width: 0.92 * w, height: 0.63 * w), house)
        rider(suit, house)
        thread(line([(0.515, 0.785), (0.70, 0.86), (0.885, 0.925)]), house, weight: 0.6)
    }

    private func rider(_ suit: Suit, _ house: MerlettoThread) {
        net(outline([(0.41, 0.58), (0.31, 0.595), (0.21, 0.66), (0.14, 0.77), (0.12, 0.88), (0.20, 0.90), (0.29, 0.85),
                     (0.37, 0.77), (0.41, 0.70)]), cell: 0.026)
        let cloth: [(CGFloat, CGFloat)] = [(0.29, 0.885), (0.56, 0.885), (0.575, 1.02), (0.43, 1.07), (0.30, 1.045)]
        toile(outline(cloth), house, rows: 0)
        let (fringe, tips) = beads(p(0.435, 0.985), 0.135 * w, 0.072 * w, count: 6, r: w * 0.018,
                                   from: .pi * 0.88, to: .pi * 0.16)
        toile(fringe, rows: 0)
        picots(tips)
        toile(polygon([(0.37, 0.57), (0.51, 0.57), (0.53, 0.78), (0.55, 0.91), (0.33, 0.91), (0.35, 0.78)]), house,
              rows: .pi / 2)
        toile(cut(Capsule(), 0.44, 0.80, 0.19, 0.035), rows: 0)
        toile(limb([(0.42, 0.885), (0.50, 0.915), (0.545, 0.96), (0.542, 1.03), (0.535, 1.095)],
                   [0.10, 0.092, 0.085, 0.075, 0.065]), rows: .pi * 0.4)
        toile(limb([(0.53, 1.06), (0.535, 1.12), (0.585, 1.14)], [0.075, 0.07, 0.04]), house, rows: 0)
        toile(limb([(0.385, 0.60), (0.385, 0.72), (0.50, 0.78)], [0.085, 0.075, 0.065]), house, rows: .pi * 0.3)
        hand(0.515, 0.785, 0.036)
        toile(limb([(0.49, 0.60), (0.60, 0.58), (0.67, 0.535)], [0.085, 0.075, 0.065]), house, rows: 0)
        held(suit, hand: 0.685, 0.525, size: 0.26)
        riderHead(house)
    }

    private func riderHead(_ house: MerlettoThread) {
        toile(polygon([(0.41, 0.53), (0.47, 0.53), (0.475, 0.58), (0.405, 0.58)]), rows: .pi / 2)
        let (ruff, tips) = beads(p(0.44, 0.577), 0.08 * w, 0.022 * w, count: 9, r: w * 0.02)
        toile(ruff, rows: 0)
        picots(tips)
        curls(oval(0.44, 0.455, 0.10, 0.10))
        face(0.44, 0.475, 0.082, 0.098)
        plume([(0.465, 0.34), (0.475, 0.26), (0.53, 0.20)], [0.05, 0.055, 0.015])
        toile(outline([(0.36, 0.385), (0.38, 0.31), (0.44, 0.295), (0.50, 0.31), (0.52, 0.385)]), house, rows: 0)
        toile(oval(0.44, 0.39, 0.155, 0.032), rows: 0)
    }

    // MARK: The horse

    // Leg spines, shoulder to hoof, against the horse's frame facing left; the near fore
    // lifted. The same walk every deck's horse takes.
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

    /// Drawn facing left in its own frame, on a pillow turned over so it walks right.
    private func horse(in frame: CGRect, _ house: MerlettoThread) {
        var flipped = context
        flipped.translateBy(x: frame.maxX, y: frame.minY)
        flipped.scaleBy(x: -1, y: 1)
        let bench = MerlettoPillow(context: flipped, w: w, velvet: velvet, mount: mount, lean: -lean)
        let r = CGRect(origin: .zero, size: frame.size)
        bench.net(HorseEar(offset: 0.044).path(in: r), cell: 0.018)
        bench.leg(Self.farHind, Self.hindWidths, far: true, r)
        bench.leg(Self.farFore, Self.foreWidths, far: true, r)
        let tail = [CGPoint(x: 0.878, y: 0.306), CGPoint(x: 0.952, y: 0.416), CGPoint(x: 0.984, y: 0.576), CGPoint(x: 0.940, y: 0.800)]
        bench.net(Ribbon(spine: tail, widths: [0.078, 0.112, 0.086, 0.028]).path(in: r), cell: 0.022)
        bench.toile(HorseEar(offset: 0).path(in: r), rows: .pi / 2)
        bench.toile(HorseBody().path(in: r), rows: 0.12)
        let mane = [CGPoint(x: 0.236, y: 0.060), CGPoint(x: 0.318, y: 0.088), CGPoint(x: 0.390, y: 0.152), CGPoint(x: 0.452, y: 0.250)]
        bench.curls(Ribbon(spine: mane, widths: [0.050, 0.110, 0.120, 0.080]).path(in: r))
        bench.picots(mane.dropFirst().map { CGPoint(x: r.width * $0.x + w * 0.03, y: r.height * $0.y - w * 0.04) })
        bench.leg(Self.nearHind, Self.hindWidths, far: false, r)
        bench.leg(Self.nearFore, Self.foreWidths, far: false, r)
        bench.bridle(r, house)
    }

    /// A leg, réseau on the far side and toile on the near, its hoof a piece of its own.
    private func leg(_ spine: [CGPoint], _ widths: [CGFloat], far: Bool, _ r: CGRect) {
        let shape = Ribbon(spine: spine, widths: widths).path(in: r)
        if far { net(shape, cell: 0.02) } else { toile(shape, rows: .pi / 2) }
        let hoof = Ribbon(spine: Array(spine.suffix(2)), widths: [widths[3] * 1.05, widths[4] * 1.45])
        toile(hoof.path(in: r), far ? .ivory : .linen, rows: 0)
    }

    /// Straps in the suit's thread, the eye and nostril left open, a stud at the brow.
    private func bridle(_ r: CGRect, _ house: MerlettoThread) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var straps = Path()
        straps.move(to: at(0.092, 0.212)); straps.addQuadCurve(to: at(0.130, 0.312), control: at(0.118, 0.268))
        straps.move(to: at(0.164, 0.126)); straps.addQuadCurve(to: at(0.226, 0.322), control: at(0.196, 0.226))
        thread(straps, house, weight: 1.1)
        let eye = r.height * 0.026
        context.fill(Path(ellipseIn: CGRect(x: at(0.152, 0.186).x - eye, y: at(0.152, 0.186).y - eye, width: eye * 2,
                                            height: eye * 2.2)), with: .color(velvet))
        let nostril = r.height * 0.016
        context.fill(Path(ellipseIn: CGRect(x: at(0.076, 0.272).x - nostril, y: at(0.076, 0.272).y - nostril,
                                            width: nostril * 2, height: nostril * 1.6)), with: .color(velvet))
        eyelets([at(0.196, 0.226)], r: 0.012, house)
    }
}
