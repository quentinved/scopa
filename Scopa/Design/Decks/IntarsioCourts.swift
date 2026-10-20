import ScopaCore
import SwiftUI

/// Re and fante, cut in light woods against the rosewood field the way Sorrento sets its
/// figures: a gown in the suit's wood, a cloak never in it, the grain run down each piece
/// as the cloth would fall.
extension IntarsioPanel {
    // MARK: Re

    /// A king standing to the knee: a mantle off both shoulders, a gown with a banded
    /// orphrey, an ermine cape, a sceptre in one hand and the suit in the other.
    func king(_ suit: Suit, _ dress: IntarsioDress) {
        let mantle: [(CGFloat, CGFloat)] = [(0.31, 0.55), (0.19, 0.74), (0.13, 1.05), (0.11, 1.46), (0.50, 1.46), (0.50, 0.55)]
        lay(outline(mantle), dress.cloak, grain: .pi * 0.60, scorch: .left)
        lay(outline(mirrored(mantle)), dress.cloak, grain: .pi * 0.40, scorch: .right)
        let lining: [(CGFloat, CGFloat)] = [(0.355, 0.60), (0.325, 0.92), (0.28, 1.46)]
        layLimb(lining, [0.05, 0.05, 0.05], .holly, scorch: .none)
        layLimb(mirrored(lining), [0.05, 0.05, 0.05], .holly, scorch: .none)
        let gown: [(CGFloat, CGFloat)] = [(0.38, 0.56), (0.34, 0.92), (0.29, 1.46), (0.50, 1.46), (0.50, 0.56)]
        lay(polygon(gown), dress.gown, grain: .pi * 0.53, scorch: .left)
        lay(polygon(mirrored(gown)), dress.gown, grain: .pi * 0.47, scorch: .right)
        orphrey(x: 0.5, from: 0.62, to: 1.46, width: 0.085, dress.trim)
        lay(cut(Capsule(), 0.5, 0.95, 0.34, 0.035), dress.trim, grain: 0, scorch: .down)
        sleeves(dress)
        ermine(0.5, 0.585)
        kingHead()
        sceptre(0.285, 0.47, 1.22)
        hand(0.285, 0.87)
        held(suit, hand: 0.75, 0.87, size: 0.30)
    }

    /// Out from under the ermine, cuffed in the trim.
    private func sleeves(_ dress: IntarsioDress) {
        layLimb([(0.36, 0.60), (0.29, 0.71), (0.285, 0.83)], [0.13, 0.11, 0.09], dress.gown, scorch: .left)
        layLimb([(0.64, 0.60), (0.73, 0.70), (0.75, 0.83)], [0.13, 0.11, 0.09], dress.gown, scorch: .right)
        lay(cut(Capsule(), 0.285, 0.835, 0.10, 0.035), dress.trim, grain: 0, scorch: .none)
        lay(cut(Capsule(), 0.75, 0.835, 0.10, 0.035), dress.trim, grain: 0, scorch: .none)
    }

    /// A rod of brass under a box lily.
    private func sceptre(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
        lay(polygon([(x - 0.013, top), (x + 0.013, top), (x + 0.013, bottom), (x - 0.013, bottom)]), .brass,
            grain: .pi / 2, scorch: .right)
        petal(p(x, top + 0.01), length: w * 0.10, breadth: w * 0.05, angle: 0, .box)
        petal(p(x, top + 0.02), length: w * 0.075, breadth: w * 0.04, angle: -.pi * 0.30, .box)
        petal(p(x, top + 0.02), length: w * 0.075, breadth: w * 0.04, angle: .pi * 0.30, .box)
        lay(oval(x, top + 0.025, 0.026, 0.022), .brass, scorch: .rim)
    }

    /// A shoulder cape of holly, its ermine tails set in ebony.
    func ermine(_ x: CGFloat, _ y: CGFloat) {
        let cape: [(CGFloat, CGFloat)] = [(x - 0.29, y + 0.05), (x - 0.21, y - 0.06), (x, y - 0.085), (x + 0.21, y - 0.06),
                                          (x + 0.29, y + 0.05), (x + 0.22, y + 0.10), (x, y + 0.115), (x - 0.22, y + 0.10)]
        lay(outline(cape), .holly, grain: 0, scorch: .down)
        let tails: [(CGFloat, CGFloat)] = [(-0.19, 0.035), (-0.10, 0.065), (0, 0.075), (0.10, 0.065), (0.19, 0.035),
                                           (-0.145, -0.02), (0.145, -0.02)]
        for (dx, dy) in tails {
            lay(outline([(x + dx, y + dy - 0.022), (x + dx + 0.011, y + dy + 0.012), (x + dx, y + dy + 0.02),
                         (x + dx - 0.011, y + dy + 0.012)]), .ebony, scorch: .none, kerf: false)
        }
    }

    /// Hair to the shoulders, a forked beard, the face between them and a crown on top.
    private func kingHead() {
        let hair: [(CGFloat, CGFloat)] = [(0.37, 0.53), (0.36, 0.36), (0.40, 0.255), (0.50, 0.23), (0.60, 0.255),
                                          (0.64, 0.36), (0.63, 0.53), (0.56, 0.47), (0.44, 0.47)]
        lay(outline(hair), .walnut, grain: .pi / 2, scorch: .right)
        face(0.5, 0.36, 0.098, 0.118, mouth: false)
        let beard: [(CGFloat, CGFloat)] = [(0.402, 0.37), (0.415, 0.45), (0.455, 0.515), (0.485, 0.535), (0.5, 0.515),
                                           (0.515, 0.535), (0.545, 0.515), (0.585, 0.45), (0.598, 0.37), (0.56, 0.415),
                                           (0.5, 0.405), (0.44, 0.415)]
        lay(outline(beard), .walnut, grain: .pi / 2, scorch: .lowerRight)
        let moustache: [(CGFloat, CGFloat)] = [(0.44, 0.432), (0.5, 0.405), (0.56, 0.432), (0.5, 0.425)]
        lay(outline(moustache), .walnut, grain: 0, scorch: .none)
        lay(outline([(0.475, 0.445), (0.5, 0.437), (0.525, 0.445), (0.5, 0.457)]), .padauk, grain: 0, scorch: .none)
        crown(0.5, 0.215, 0.25)
    }

    // MARK: Fante

    /// A page head to foot: a plumed beret, a belted doublet in the suit's wood, hose in
    /// two woods, one hand on his hip and the suit held up in the other.
    func knave(_ suit: Suit, _ dress: IntarsioDress) {
        ground()
        layLimb([(0.448, 0.88), (0.44, 1.10), (0.432, 1.33)], [0.10, 0.085, 0.07], dress.cloak, scorch: .left)
        layLimb([(0.552, 0.88), (0.56, 1.10), (0.568, 1.33)], [0.10, 0.085, 0.07], .holly, scorch: .right)
        lay(cut(Capsule(), 0.441, 1.10, 0.095, 0.03), dress.trim, grain: 0, scorch: .none)
        lay(cut(Capsule(), 0.559, 1.10, 0.095, 0.03), dress.trim, grain: 0, scorch: .none)
        lay(outline([(0.39, 1.36), (0.40, 1.32), (0.455, 1.32), (0.465, 1.365)]), .ebony, grain: 0, scorch: .none)
        lay(outline([(0.61, 1.36), (0.60, 1.32), (0.545, 1.32), (0.535, 1.365)]), .ebony, grain: 0, scorch: .none)
        let doublet: [(CGFloat, CGFloat)] = [(0.40, 0.46), (0.37, 0.70), (0.31, 0.94), (0.50, 0.95), (0.50, 0.46)]
        lay(polygon(doublet), dress.gown, grain: .pi * 0.56, scorch: .left)
        lay(polygon(mirrored(doublet)), dress.gown, grain: .pi * 0.44, scorch: .right)
        layLimb([(0.31, 0.925), (0.40, 0.94), (0.5, 0.945), (0.60, 0.94), (0.69, 0.925)], [0.04, 0.04, 0.04, 0.04, 0.04],
                dress.cloak, scorch: .none)
        lay(cut(Capsule(), 0.5, 0.72, 0.30, 0.04), dress.trim, grain: 0, scorch: .down)
        lay(cut(Rectangle(), 0.5, 0.72, 0.05, 0.05), .brass, scorch: .rim)
        for k in 0..<3 { lay(oval(0.5, 0.52 + CGFloat(k) * 0.065, 0.012, 0.012), .box, scorch: .none) }
        knaveArms(suit, dress)
        knaveHead(dress)
    }

    /// The walnut ground a standing figure is set on, across the foot of the field.
    func ground() {
        lay(outline([(0.0, 1.37), (0.25, 1.345), (0.5, 1.335), (0.75, 1.345), (1.0, 1.37), (1.0, 1.6), (0.0, 1.6)]),
            .walnut, grain: 0.04, scorch: .none)
    }

    private func knaveArms(_ suit: Suit, _ dress: IntarsioDress) {
        layLimb([(0.63, 0.50), (0.745, 0.60), (0.655, 0.705)], [0.10, 0.085, 0.075], dress.gown, scorch: .right)
        hand(0.64, 0.715)
        lay(oval(0.375, 0.495, 0.065, 0.05), dress.cloak, grain: 0, scorch: .lowerLeft)
        lay(oval(0.625, 0.495, 0.065, 0.05), dress.cloak, grain: 0, scorch: .lowerRight)
        layLimb([(0.37, 0.51), (0.30, 0.62), (0.275, 0.71)], [0.10, 0.085, 0.075], dress.gown, scorch: .left)
        held(suit, hand: 0.275, 0.735, size: 0.30)
    }

    private func knaveHead(_ dress: IntarsioDress) {
        lay(polygon([(0.465, 0.40), (0.535, 0.40), (0.54, 0.47), (0.46, 0.47)]), .pear, scorch: .right)
        lay(cut(Capsule(), 0.5, 0.465, 0.21, 0.045), .holly, grain: 0, scorch: .down)
        let hair: [(CGFloat, CGFloat)] = [(0.385, 0.40), (0.38, 0.29), (0.42, 0.225), (0.50, 0.21), (0.58, 0.225),
                                          (0.62, 0.29), (0.615, 0.40), (0.57, 0.38), (0.5, 0.27), (0.43, 0.38)]
        lay(outline(hair), .olive, grain: .pi / 2, scorch: .right)
        face(0.5, 0.315, 0.09, 0.105)
        let plume: [(CGFloat, CGFloat)] = [(0.58, 0.215), (0.66, 0.16), (0.74, 0.12), (0.80, 0.115)]
        layLimb(plume, [0.05, 0.065, 0.05, 0.015], .holly, scorch: .down)
        if fine {
            for k in 0..<5 {
                let t = 0.62 + CGFloat(k) * 0.035
                incise([(t, 0.215 - (t - 0.58) * 0.62), (t + 0.02, 0.195 - (t - 0.58) * 0.62)], 0.004)
            }
        }
        lay(oval(0.5, 0.215, 0.135, 0.045), dress.cloak, grain: 0, scorch: .down)
        lay(cut(Capsule(), 0.5, 0.245, 0.24, 0.03), dress.trim, grain: 0, scorch: .none)
    }
}
