import ScopaCore
import SwiftUI

/// Re and fante, standing full length on the meadow as the Visconti courts stand: tall,
/// slender, their gowns brocaded in gold and falling to the ground.
extension TarocchiPanel {
    // MARK: Re

    /// A king: a mantle off both shoulders over a brocaded gown, an ermine cape, a sceptre
    /// in one hand and the suit held up in the other.
    func king(_ suit: Suit, _ dress: TarocchiDress) {
        let mantle: [(CGFloat, CGFloat)] = [(0.35, 0.45), (0.22, 0.58), (0.15, 0.92), (0.09, 1.375), (0.91, 1.375),
                                            (0.85, 0.92), (0.78, 0.58), (0.65, 0.45)]
        robe(outline(mantle), dress.mantle, folds: [[(0.23, 0.68), (0.18, 1.0), (0.15, 1.34)],
                                                    [(0.77, 0.68), (0.82, 1.0), (0.85, 1.34)]])
        let lining: [(CGFloat, CGFloat)] = [(0.37, 0.52), (0.32, 0.92), (0.27, 1.365)]
        paint(limb(lining, [0.045, 0.06, 0.075]), dress.lining.body)
        paint(limb(mirrored(lining), [0.045, 0.06, 0.075]), dress.lining.body)
        let gown: [(CGFloat, CGFloat)] = [(0.40, 0.47), (0.36, 0.82), (0.29, 1.375), (0.71, 1.375), (0.64, 0.82), (0.60, 0.47)]
        robe(outline(gown), dress.gown, brocade: true, folds: [[(0.44, 0.84), (0.415, 1.35)], [(0.5, 0.86), (0.5, 1.355)],
                                                              [(0.56, 0.84), (0.585, 1.35)]])
        gilt([(0.295, 1.35), (0.5, 1.36), (0.705, 1.35)], 0.032)
        gilt([(0.375, 0.76), (0.5, 0.775), (0.625, 0.76)], 0.028)
        shoe(0.47, 1.385, toward: -1)
        shoe(0.53, 1.385, toward: 1)
        kingArms(dress)
        ermine(0.5, 0.50, half: 0.23)
        kingHead(dress)
        let slender = suit == .swords || suit == .clubs
        held(suit, hand: slender ? 0.735 : 0.715, 0.78, size: 0.28)
    }

    /// Sleeves cuffed in gold, a sceptre in the one hand; the other is left for the suit.
    private func kingArms(_ dress: TarocchiDress) {
        robe(limb([(0.385, 0.50), (0.325, 0.64), (0.31, 0.79)], [0.13, 0.115, 0.10]), dress.gown, brocade: true)
        gilt([(0.26, 0.795), (0.36, 0.795)], 0.032)
        sceptre(0.31, 0.42, 1.12)
        hand(0.31, 0.83, 0.038)
        robe(limb([(0.615, 0.50), (0.695, 0.62), (0.715, 0.74)], [0.13, 0.115, 0.10]), dress.gown, brocade: true)
        gilt([(0.665, 0.745), (0.765, 0.745)], 0.032)
    }

    /// A rod of leaf under a lily.
    private func sceptre(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
        paint(polygon([(x - 0.011, top), (x + 0.011, top), (x + 0.011, bottom), (x - 0.011, bottom)]), Tempera.gold, line: 0.8)
        for angle in [-0.75, 0, 0.75] as [CGFloat] {
            petal(p(x, top + 0.005), length: angle == 0 ? 0.085 : 0.062, breadth: 0.04, angle: angle, Tempera.gold)
        }
        paint(oval(x, top + 0.008, 0.024, 0.016), Tempera.gold, line: 0.8)
    }

    /// A pointed petal or leaf from `base`, laid outward at `angle` (0 is up).
    func petal(_ base: CGPoint, length: CGFloat, breadth: CGFloat, angle: CGFloat, _ colour: Color) {
        let shape = Leaf().path(in: CGRect(x: -breadth / 2 * w, y: -length * w, width: breadth * w, height: length * w))
        paint(shape.applying(CGAffineTransform(rotationAngle: angle)
            .concatenating(CGAffineTransform(translationX: base.x, y: base.y))), colour, line: 0.8)
    }

    /// Hair to the shoulders, a forked beard and moustache, the face between, and a crown.
    private func kingHead(_ dress: TarocchiDress) {
        let hair: [(CGFloat, CGFloat)] = [(0.395, 0.48), (0.38, 0.31), (0.41, 0.205), (0.5, 0.18), (0.59, 0.205),
                                          (0.62, 0.31), (0.605, 0.48), (0.56, 0.44), (0.44, 0.44)]
        paint(outline(hair), dress.hair.body)
        face(0.5, 0.305, 0.088, 0.108, mouth: false)
        let beard: [(CGFloat, CGFloat)] = [(0.416, 0.33), (0.425, 0.41), (0.465, 0.475), (0.5, 0.46), (0.535, 0.475),
                                           (0.575, 0.41), (0.584, 0.33), (0.548, 0.372), (0.5, 0.365), (0.452, 0.372)]
        paint(outline(beard), dress.hair.body)
        if fine {
            draw([(0.465, 0.40), (0.477, 0.455)], dress.hair.shade, 0.0045)
            draw([(0.535, 0.40), (0.523, 0.455)], dress.hair.shade, 0.0045)
        }
        context.fill(oval(0.5, 0.384, 0.019, 0.0075), with: .color(TarocchiPigment.vermilion.body))
        draw([(0.455, 0.375), (0.5, 0.364), (0.545, 0.375)], dress.hair.shade, 0.01)
        crown(0.5, 0.20, 0.20)
    }

    // MARK: Fante

    /// A page: a hat with a broad brim, a brocaded giornea belted and pleated to the knee,
    /// parti-coloured hose and pointed shoes, one hand on his hip and the suit held up.
    func knave(_ suit: Suit, _ dress: TarocchiDress) {
        let leg: [(CGFloat, CGFloat)] = [(0.452, 0.94), (0.443, 1.14), (0.438, 1.345)]
        robe(limb(leg, [0.10, 0.075, 0.056]), dress.mantle)
        robe(limb(mirrored(leg), [0.10, 0.075, 0.056]), dress.lining)
        shoe(0.442, 1.355, toward: -1)
        shoe(0.558, 1.355, toward: 1)
        let giornea: [(CGFloat, CGFloat)] = [(0.385, 0.46), (0.375, 0.61), (0.40, 0.71), (0.30, 0.99), (0.70, 0.99),
                                             (0.60, 0.71), (0.625, 0.61), (0.615, 0.46)]
        robe(outline(giornea), dress.gown, brocade: true,
             folds: [[(0.44, 0.76), (0.40, 0.97)], [(0.5, 0.77), (0.5, 0.975)], [(0.56, 0.76), (0.60, 0.97)]])
        gilt([(0.305, 0.975), (0.5, 0.985), (0.695, 0.975)], 0.028)
        gilt([(0.395, 0.71), (0.5, 0.72), (0.605, 0.71)], 0.026)
        knaveHead(dress)
        knaveArms(suit, dress)
    }

    private func knaveArms(_ suit: Suit, _ dress: TarocchiDress) {
        robe(limb([(0.385, 0.51), (0.295, 0.60), (0.385, 0.69)], [0.11, 0.09, 0.072]), dress.gown, brocade: true)
        hand(0.395, 0.695, 0.036)
        robe(limb([(0.615, 0.51), (0.715, 0.545), (0.75, 0.46)], [0.11, 0.09, 0.072]), dress.gown, brocade: true)
        for x in [0.385, 0.615] as [CGFloat] { robe(oval(x, 0.495, 0.068, 0.056), dress.mantle) }
        held(suit, hand: 0.75, 0.45, size: 0.30)
    }

    /// Fair hair bobbed to the jaw, a collar of biacca, a hat with a broad brim and a plume.
    private func knaveHead(_ dress: TarocchiDress) {
        paint(polygon([(0.47, 0.37), (0.53, 0.37), (0.535, 0.45), (0.465, 0.45)]), TarocchiPigment.flesh.body)
        paint(limb([(0.435, 0.455), (0.5, 0.466), (0.565, 0.455)], [0.034, 0.034, 0.034]), TarocchiPigment.biacca.body)
        let hair: [(CGFloat, CGFloat)] = [(0.41, 0.40), (0.40, 0.28), (0.43, 0.195), (0.5, 0.178), (0.57, 0.195),
                                          (0.60, 0.28), (0.59, 0.40), (0.5, 0.37)]
        paint(outline(hair), dress.hair.body)
        if fine {
            for x in [0.415, 0.437, 0.563, 0.585] as [CGFloat] {
                draw([(x, 0.32), (x - 0.007, 0.36), (x + 0.004, 0.39)], dress.hair.shade, 0.0045)
            }
        }
        face(0.5, 0.29, 0.08, 0.098)
        paint(limb([(0.56, 0.14), (0.585, 0.095), (0.572, 0.062)], [0.03, 0.04, 0.008]), TarocchiPigment.biacca.body)
        let dome: [(CGFloat, CGFloat)] = [(0.405, 0.205), (0.42, 0.13), (0.5, 0.10), (0.58, 0.13), (0.595, 0.205)]
        robe(outline(dome), dress.mantle)
        robe(oval(0.5, 0.205, 0.16, 0.034), dress.mantle)
        gilt([(0.42, 0.188), (0.58, 0.188)], 0.022)
    }
}
