import SwiftUI
import ScopaCore

/// The Carnevale court, masked and filling the card: the fante in a bauta, the cavallo in a
/// colombina on a parade horse, the re in a gilded volto. Each holds its suit sign.
///
/// Laid out like `CourtPlate`: x against the plate's width, y against its height, limb
/// widths against the width.
struct CarnevaleCourt: View {
    let rank: Rank
    let suit: Suit
    let width: CGFloat
    let height: CGFloat

    var w: CGFloat { width }
    var h: CGFloat { height }
    var hair: CGFloat { max(0.45, w * 0.010) }
    var pen: Color { Carnevale.ink }
    /// The garment that takes the suit.
    var cloth: Color { Carnevale.colour(of: suit) }
    /// A second garment colour, never the suit's own.
    var contrast: Color { suit == .cups ? Carnevale.teal : Carnevale.red }
    /// Gold woven into the suit's cloth, darker on the gold suit so it still shows.
    var thread: Color { suit == .coins ? Carnevale.ochre : Carnevale.gold }

    var body: some View {
        ZStack {
            switch rank {
            case .king: king
            case .knight: knight
            default: knave
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: Fante

    /// A bauta under a black tricorn and hood, the tabarro open over a coat in the suit's
    /// colour, one arm out of the cloak holding the sign up.
    var knave: some View {
        ZStack {
            limb([(0.455, 0.80), (0.449, 0.87), (0.446, 0.925)], [0.080, 0.066, 0.058], Carnevale.white)
            limb([(0.545, 0.80), (0.551, 0.87), (0.554, 0.925)], [0.080, 0.066, 0.058], Carnevale.white)
            shoe(from: (0.446, 0.925), toe: -1)
            shoe(from: (0.554, 0.925), toe: 1)
            part(Robe(flare: 0.24), 0.50, 0.48, 0.50, 0.58, Carnevale.cloak)
            folds(left: 0.36, right: 0.64, top: 0.46, bottom: 0.80)
            part(Trapezoid(topRatio: 0.30), 0.17, 0.42, 0.50, 0.615, cloth)
            buttons(x: 0.50, from: 0.47, count: 5)
            limb([(0.39, 0.44), (0.31, 0.52), (0.255, 0.575)], [0.095, 0.080, 0.066], cloth)
            cuff(at: 0.590, 0.515)
            glove(at: 0.585, 0.535)
            emblem(at: (0.230, 0.460), scale: 0.28)
            cuff(at: 0.250, 0.582)
            glove(at: 0.245, 0.600)
            part(Carnevale.Hood(), 0.40, 0.25, 0.50, 0.275, Carnevale.cloak)
            part(Carnevale.Jabot(), 0.13, 0.075, 0.50, 0.385, Carnevale.white)
            bauta(x: 0.50, y: 0.255, pw: 0.22, ph: 0.165)
            tricorn(x: 0.50, y: 0.130, pw: 0.46, ph: 0.115)
            part(Carnevale.Scalloped(count: 9, depth: 0.25), 0.07, 0.046, 0.355, 0.112, contrast)
            dot(0.355, 0.112, 0.022, Carnevale.gold)
        }
    }

    /// The bauta's face: eye holes, brows, the long nose and the crease where the jaw juts.
    func bauta(x: CGFloat, y: CGFloat, pw: CGFloat, ph: CGFloat) -> some View {
        let at = { (u: CGFloat, v: CGFloat) in (x + (u - 0.5) * pw, y + (v - 0.5) * ph) }
        return ZStack {
            part(Carnevale.Bauta(), pw, ph, x, y, Carnevale.white)
            eyes(x: x, y: at(0, 0.40).1, apart: pw * 0.36, pw: pw * 0.24, ph: ph * 0.11)
            line([at(0.15, 0.31), at(0.30, 0.22), at(0.45, 0.25)], pen, weight: 0.9)
            line([at(0.55, 0.25), at(0.70, 0.22), at(0.85, 0.31)], pen, weight: 0.9)
            line([at(0.50, 0.34), at(0.45, 0.60), at(0.54, 0.63)], pen.opacity(0.7), weight: 0.9)
            line([at(0.24, 0.73), at(0.50, 0.79), at(0.76, 0.73)], pen.opacity(0.45), weight: 0.9)
        }
    }

    /// A tricorn with gold braid round the brim.
    func tricorn(x: CGFloat, y: CGFloat, pw: CGFloat, ph: CGFloat) -> some View {
        ZStack {
            part(Carnevale.Tricorn(), pw, ph, x, y, pen)
            Carnevale.TricornBraid()
                .stroke(Carnevale.gold, style: StrokeStyle(lineWidth: hair * 1.7, lineCap: .round))
                .frame(width: w * pw, height: h * ph)
                .position(x: w * x, y: h * y)
        }
    }

    /// Two almond eye holes, `apart` between their centres.
    func eyes(x: CGFloat, y: CGFloat, apart: CGFloat, pw: CGFloat, ph: CGFloat) -> some View {
        ZStack {
            part(Carnevale.Almond(), pw, ph, x - apart / 2, y, pen)
            part(Carnevale.Almond(), pw, ph, x + apart / 2, y, pen)
        }
    }

    // MARK: Re

    /// A gilded volto under a crown, a black veil behind it, a lace collar and a brocade cape
    /// open over an ivory gown. Sceptre in one hand, the suit in the other.
    var king: some View {
        ZStack {
            shoe(from: (0.455, 0.905), toe: -1)
            shoe(from: (0.545, 0.905), toe: 1)
            part(Robe(flare: 0.20), 0.36, 0.50, 0.50, 0.665, Carnevale.white)
            part(Rectangle(), 0.07, 0.47, 0.50, 0.68, Carnevale.gold)
            ForEach(0..<6, id: \.self) { index in
                part(Carnevale.Lozenge(), 0.05, 0.045, 0.50, 0.49 + CGFloat(index) * 0.075,
                     index.isMultiple(of: 2) ? Carnevale.red : pen)
            }
            capeHalf
            capeHalf.scaleEffect(x: -1)
            sleeves
            sceptre
            emblem(at: (0.765, 0.515), scale: 0.28)
            glove(at: 0.708, 0.598)
            part(Carnevale.LaceCollar(count: 9), 0.46, 0.10, 0.50, 0.40, Carnevale.white)
            Carnevale.CollarHoles(count: 9).fill(pen.opacity(0.35))
                .frame(width: w * 0.46, height: h * 0.10).position(x: w * 0.50, y: h * 0.40)
            part(Carnevale.Hood(), 0.36, 0.23, 0.50, 0.255, Carnevale.cloak)
            part(Ellipse(), 0.24, 0.07, 0.50, 0.125, cloth)
            volto(x: 0.50, y: 0.265, pw: 0.21, ph: 0.16)
            crown
        }
    }

    /// The left half of the cape: suit cloth woven with gold, bordered in gold. Mirrored
    /// for the right.
    var capeHalf: some View {
        let shape = Carnevale.CapeHalf()
        return ZStack {
            shape.fill(cloth)
            Carnevale.Brocade(step: w * 0.07).fill(thread).clipShape(shape)
            Carnevale.CapeTrim().stroke(Carnevale.gold, style: StrokeStyle(lineWidth: hair * 3.2, lineCap: .round))
            shape.stroke(pen, lineWidth: hair * 1.3)
        }
        .frame(width: w * 0.36, height: h * 0.56)
        .position(x: w * 0.32, y: h * 0.63)
    }

    var sleeves: some View {
        ZStack {
            limb([(0.385, 0.43), (0.33, 0.50), (0.305, 0.565)], [0.11, 0.09, 0.075], cloth)
            limb([(0.615, 0.43), (0.67, 0.50), (0.695, 0.565)], [0.11, 0.09, 0.075], cloth)
            cuff(at: 0.300, 0.578)
            cuff(at: 0.700, 0.578)
        }
    }

    var sceptre: some View {
        ZStack {
            part(Capsule(), 0.026, 0.50, 0.297, 0.56, Carnevale.gold)
            part(Carnevale.Lozenge(), 0.035, 0.034, 0.297, 0.262, Carnevale.gold)
            part(Ellipse(), 0.075, 0.050, 0.297, 0.300, Carnevale.gold)
            dot(0.297, 0.300, 0.026, Carnevale.red)
            glove(at: 0.297, 0.600)
        }
    }

    /// The volto's face, painted on gold: eye holes, ochre brows and nose, red lips, a curl
    /// on each cheek.
    func volto(x: CGFloat, y: CGFloat, pw: CGFloat, ph: CGFloat) -> some View {
        let at = { (u: CGFloat, v: CGFloat) in (x + (u - 0.5) * pw, y + (v - 0.5) * ph) }
        return ZStack {
            part(Carnevale.Volto(), pw, ph, x, y, Carnevale.gold)
            eyes(x: x, y: at(0, 0.42).1, apart: pw * 0.36, pw: pw * 0.22, ph: ph * 0.10)
            line([at(0.16, 0.33), at(0.32, 0.27), at(0.45, 0.33)], Carnevale.ochre, weight: 1.1)
            line([at(0.55, 0.33), at(0.68, 0.27), at(0.84, 0.33)], Carnevale.ochre, weight: 1.1)
            line([at(0.50, 0.40), at(0.46, 0.62), at(0.54, 0.65)], Carnevale.ochre, weight: 1.0)
            line([at(0.18, 0.56), at(0.16, 0.66), at(0.26, 0.70)], Carnevale.ochre, weight: 0.9)
            line([at(0.82, 0.56), at(0.84, 0.66), at(0.74, 0.70)], Carnevale.ochre, weight: 0.9)
            line([at(0.32, 0.16), at(0.50, 0.10), at(0.68, 0.16)], Carnevale.ochre, weight: 0.9)
            part(Carnevale.Almond(), pw * 0.24, ph * 0.07, x, at(0, 0.79).1, Carnevale.red)
        }
    }

    var crown: some View {
        ZStack {
            part(KingCrown(), 0.32, 0.075, 0.50, 0.155, Carnevale.gold)
            dot(0.42, 0.178, 0.028, Carnevale.red)
            dot(0.50, 0.178, 0.028, Carnevale.teal)
            dot(0.58, 0.178, 0.028, Carnevale.red)
        }
    }
}
