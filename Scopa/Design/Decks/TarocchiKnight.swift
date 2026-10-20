import ScopaCore
import SwiftUI

/// The cavallo: a white horse walking right under a caparison to its fetlocks, the cloth in
/// the mantle's colour brocaded in gold and dagged at its hem, the rider above it in a
/// chaperon with the suit held high.
extension TarocchiPanel {
    func knight(_ suit: Suit, _ dress: TarocchiDress) {
        horse(dress, in: CGRect(x: 0.07 * w, y: 0.66 * w, width: 0.90 * w, height: 0.70 * w))
        rider(suit, dress)
    }

    // MARK: The rider

    private func rider(_ suit: Suit, _ dress: TarocchiDress) {
        let skirt: [(CGFloat, CGFloat)] = [(0.37, 0.74), (0.31, 0.86), (0.30, 0.99), (0.43, 1.01), (0.565, 0.95),
                                           (0.585, 0.80), (0.55, 0.74)]
        robe(outline(skirt), dress.gown, brocade: true, folds: [[(0.37, 0.82), (0.35, 0.97)], [(0.45, 0.83), (0.45, 0.99)]])
        robe(limb([(0.47, 0.84), (0.575, 0.885), (0.59, 0.98), (0.585, 1.06)], [0.085, 0.075, 0.06, 0.05]), dress.lining)
        shoe(0.575, 1.075, toward: 1)
        let cloak: [(CGFloat, CGFloat)] = [(0.42, 0.50), (0.32, 0.53), (0.235, 0.63), (0.185, 0.79), (0.245, 0.81),
                                           (0.305, 0.74), (0.36, 0.66), (0.40, 0.60)]
        robe(outline(cloak), dress.mantle, folds: [[(0.34, 0.56), (0.27, 0.66), (0.22, 0.78)]])
        robe(limb([(0.53, 0.53), (0.625, 0.505), (0.685, 0.43)], [0.085, 0.075, 0.065]), dress.gown, brocade: true)
        let torso: [(CGFloat, CGFloat)] = [(0.405, 0.50), (0.385, 0.62), (0.395, 0.80), (0.545, 0.80), (0.555, 0.62),
                                           (0.535, 0.50)]
        robe(outline(torso), dress.gown, brocade: true)
        gilt([(0.392, 0.72), (0.47, 0.73), (0.55, 0.72)], 0.024)
        robe(limb([(0.43, 0.53), (0.445, 0.65), (0.545, 0.715)], [0.085, 0.075, 0.065]), dress.gown, brocade: true)
        draw([(0.56, 0.72), (0.73, 0.795), (0.887, 0.849)], Tempera.sable, 0.0055)
        hand(0.555, 0.72, 0.03)
        riderHead(dress)
        held(suit, hand: 0.69, 0.42, size: 0.26)
    }

    /// A face under a chaperon: a rolled turban with its tail hanging behind.
    private func riderHead(_ dress: TarocchiDress) {
        paint(polygon([(0.44, 0.45), (0.50, 0.45), (0.505, 0.52), (0.435, 0.52)]), TarocchiPigment.flesh.body)
        robe(limb([(0.41, 0.33), (0.37, 0.43), (0.355, 0.53)], [0.065, 0.055, 0.035]), dress.lining)
        paint(outline([(0.395, 0.47), (0.39, 0.36), (0.47, 0.31), (0.55, 0.36), (0.545, 0.47), (0.47, 0.44)]), dress.hair.body)
        face(0.47, 0.40, 0.074, 0.09)
        robe(oval(0.47, 0.29, 0.082, 0.05), dress.lining)
        robe(cut(Capsule(), 0.47, 0.325, 0.195, 0.056), dress.lining,
             folds: [[(0.39, 0.325), (0.47, 0.31), (0.55, 0.325)]])
    }

    // MARK: The horse

    // Lower legs, from under the caparison to the hoof, in the horse's own frame facing
    // left. The near fore lifted.
    private static let farLegs: [[CGPoint]] = [
        [CGPoint(x: 0.43, y: 0.70), CGPoint(x: 0.42, y: 0.82), CGPoint(x: 0.412, y: 0.944)],
        [CGPoint(x: 0.80, y: 0.74), CGPoint(x: 0.79, y: 0.85), CGPoint(x: 0.795, y: 0.944)],
    ]
    private static let nearLegs: [[CGPoint]] = [
        [CGPoint(x: 0.865, y: 0.74), CGPoint(x: 0.858, y: 0.85), CGPoint(x: 0.858, y: 0.944)],
        [CGPoint(x: 0.36, y: 0.68), CGPoint(x: 0.315, y: 0.77), CGPoint(x: 0.29, y: 0.835), CGPoint(x: 0.305, y: 0.885)],
    ]

    /// Drawn facing left in its own frame, on a panel turned over so it walks right.
    private func horse(_ dress: TarocchiDress, in frame: CGRect) {
        var flipped = context
        flipped.translateBy(x: frame.maxX, y: frame.minY)
        flipped.scaleBy(x: -1, y: 1)
        let stall = TarocchiPanel(context: flipped, w: w)
        let r = CGRect(origin: .zero, size: frame.size)
        for spine in Self.farLegs { stall.leg(spine, r, TarocchiPigment.biacca.shade) }
        stall.paint(HorseEar(offset: 0.044).path(in: r), TarocchiPigment.biacca.shade)
        stall.paint(HorseBody().path(in: r), TarocchiPigment.biacca.body)
        stall.paint(HorseEar(offset: 0).path(in: r), TarocchiPigment.biacca.body)
        let mane = [CGPoint(x: 0.236, y: 0.060), CGPoint(x: 0.318, y: 0.088), CGPoint(x: 0.390, y: 0.152), CGPoint(x: 0.452, y: 0.250)]
        stall.paint(Ribbon(spine: mane, widths: [0.04, 0.085, 0.095, 0.06]).path(in: r), TarocchiPigment.biacca.shade, line: 0.7)
        for spine in Self.nearLegs { stall.leg(spine, r, TarocchiPigment.biacca.body) }
        stall.caparison(dress, r)
        let tail = [CGPoint(x: 0.925, y: 0.30), CGPoint(x: 0.985, y: 0.40), CGPoint(x: 0.995, y: 0.56), CGPoint(x: 0.965, y: 0.72)]
        stall.paint(Ribbon(spine: tail, widths: [0.045, 0.075, 0.065, 0.015]).path(in: r), TarocchiPigment.biacca.shade, line: 0.7)
        stall.bridle(r)
    }

    /// A leg with its hoof in sable.
    private func leg(_ spine: [CGPoint], _ r: CGRect, _ coat: Color) {
        let widths: [CGFloat] = spine.count == 4 ? [0.075, 0.062, 0.055, 0.052] : [0.07, 0.056, 0.052]
        paint(Ribbon(spine: spine, widths: widths).path(in: r), coat, line: 0.8)
        let hoof = Ribbon(spine: Array(spine.suffix(2)), widths: [0.052, 0.075])
        let foot = CGRect(x: 0, y: r.height * (spine[spine.count - 1].y - 0.035), width: r.width, height: r.height)
        var inside = context
        inside.clip(to: Path(foot))
        TarocchiPanel(context: inside, w: w).paint(hoof.path(in: r), Tempera.sable, line: 0.6)
    }

    /// The cloth over the barrel, from the breast to the quarters, its hem cut in scallops
    /// and bound in gold.
    private func caparison(_ dress: TarocchiDress, _ r: CGRect) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.width * x, y: r.height * y) }
        var cloth = Path()
        cloth.move(to: at(0.335, 0.37))
        cloth.addQuadCurve(to: at(0.47, 0.25), control: at(0.38, 0.265))
        cloth.addQuadCurve(to: at(0.74, 0.255), control: at(0.60, 0.29))
        cloth.addQuadCurve(to: at(0.93, 0.33), control: at(0.86, 0.22))
        cloth.addQuadCurve(to: at(0.975, 0.78), control: at(0.99, 0.55))
        let scallops = 9
        for k in 1...scallops {
            let t = CGFloat(k) / CGFloat(scallops), mid = (CGFloat(k) - 0.5) / CGFloat(scallops)
            cloth.addQuadCurve(to: at(0.975 - 0.70 * t, 0.78 - 0.06 * t), control: at(0.975 - 0.70 * mid, 0.83 - 0.06 * mid))
        }
        cloth.addQuadCurve(to: at(0.335, 0.37), control: at(0.25, 0.50))
        cloth.closeSubpath()
        robe(cloth, dress.mantle, brocade: true)
        let hem = Path { $0.move(to: at(0.29, 0.69)); $0.addQuadCurve(to: at(0.965, 0.745), control: at(0.62, 0.73)) }
        context.stroke(hem, with: .color(Tempera.gold), lineWidth: w * 0.026)
        if fine { punchRow(hem, radius: w * 0.0048, pitch: w * 0.017) }
        context.stroke(Path { $0.move(to: at(0.47, 0.25)); $0.addQuadCurve(to: at(0.74, 0.255), control: at(0.60, 0.29)) },
                       with: .color(Tempera.gold), lineWidth: w * 0.02)
    }

    /// Eye, nostril and a vermilion bridle studded in gold.
    private func bridle(_ r: CGRect) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.width * x, y: r.height * y) }
        var straps = Path()
        straps.move(to: at(0.092, 0.212)); straps.addQuadCurve(to: at(0.130, 0.312), control: at(0.118, 0.268))
        straps.move(to: at(0.164, 0.126)); straps.addQuadCurve(to: at(0.226, 0.322), control: at(0.196, 0.226))
        context.stroke(straps, with: .color(TarocchiPigment.vermilion.body), lineWidth: max(0.5, w * 0.014))
        punch([at(0.196, 0.226), at(0.11, 0.26)], radius: max(0.4, w * 0.009), Tempera.gold)
        punch([at(0.152, 0.186)], radius: max(0.4, w * 0.008), Tempera.ink)
        punch([at(0.074, 0.272)], radius: max(0.3, w * 0.005), Tempera.ink)
    }
}
