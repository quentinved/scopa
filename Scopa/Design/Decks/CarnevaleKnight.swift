import SwiftUI

// MARK: - Cavallo

extension CarnevaleCourt {
    /// The rider's centre line. Everything above the saddle is placed against it.
    private static let seat: CGFloat = 0.545

    /// A rider in a colombina and tricorn, cape flying, on a white parade horse under a
    /// caparison of the suit's cloth. The sign is held up in the free hand.
    var knight: some View {
        let seat = Self.seat
        return ZStack {
            limb([(seat + 0.06, 0.45), (seat + 0.17, 0.53), (seat + 0.26, 0.64)], [0.17, 0.21, 0.11], Carnevale.cloak)
            HorseArt(style: .litografia, coat: Carnevale.white, accent: Carnevale.gold,
                     ink: pen, width: w * 0.98, height: h * 0.40)
                .position(x: w * 0.485, y: h * 0.762)
            caparison
            limb([(0.214, 0.590), (0.206, 0.545), (0.228, 0.505)], [0.020, 0.046, 0.014], Carnevale.red)
            limb([(0.222, 0.592), (0.236, 0.553), (0.268, 0.530)], [0.016, 0.034, 0.010], Carnevale.gold)
            line([(0.124, 0.684), (0.320, 0.648), (seat - 0.060, 0.615)], pen.opacity(0.8), weight: 1.6)
            part(Trapezoid(topRatio: 1.30), 0.28, 0.07, seat, 0.675, contrast)
            rider(seat: seat)
            emblem(at: (0.25, 0.285), scale: 0.28)
            cuff(at: seat - 0.245, 0.386)
            glove(at: seat - 0.258, 0.372)
        }
    }

    /// The caparison over the horse: a gold border showing under the cloth's dagged hem,
    /// gold woven through the cloth.
    private var caparison: some View {
        let inner = Carnevale.Caparison(lift: 0.04)
        let whole = Carnevale.Caparison()
        return ZStack {
            whole.fill(Carnevale.gold)
            inner.fill(cloth)
            Carnevale.Brocade(step: w * 0.075).fill(thread).clipShape(inner)
            inner.stroke(pen.opacity(0.5), lineWidth: hair)
            whole.stroke(pen, lineWidth: hair * 1.3)
        }
        .frame(width: w * 0.98, height: h * 0.40)
        .position(x: w * 0.485, y: h * 0.762)
    }

    /// Leg, coat, arms, cape and head, from the saddle up.
    private func rider(seat: CGFloat) -> some View {
        ZStack {
            limb([(seat - 0.015, 0.64), (0.492, 0.70), (0.468, 0.75)], [0.115, 0.095, 0.078], Carnevale.cloak)
            limb([(0.468, 0.745), (0.462, 0.775), (0.458, 0.800)], [0.070, 0.066, 0.062], Carnevale.white)
            shoe(from: (0.458, 0.800), toe: -1)
            part(Robe(flare: 0.12), 0.24, 0.19, seat, 0.53, contrast)
            buttons(x: seat, from: 0.475, count: 4)
            limb([(seat - 0.037, 0.468), (seat - 0.149, 0.424), (seat - 0.243, 0.384)],
                 [0.10, 0.082, 0.068], contrast)
            glove(at: seat - 0.060, 0.615)
            part(Mantle(), 0.30, 0.09, seat, 0.462, Carnevale.cloak)
            part(Carnevale.Jabot(), 0.10, 0.06, seat, 0.445, Carnevale.white)
            masked(x: seat, y: 0.375)
        }
    }

    /// A face under a colombina and a plumed tricorn.
    private func masked(x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            part(Capsule(), 0.17, 0.10, x + 0.012, y - 0.004, Carnevale.locks)
            part(Ellipse(), 0.15, 0.10, x, y, Carnevale.flesh)
            part(Carnevale.Almond(), 0.040, 0.011, x, y + 0.030, Carnevale.red)
            part(Carnevale.Colombina(), 0.22, 0.055, x, y - 0.012, Carnevale.gold)
            eyes(x: x, y: y - 0.008, apart: 0.075, pw: 0.050, ph: 0.014)
            dot(x, y - 0.030, 0.020, Carnevale.red)
            limb([(x + 0.10, y - 0.085), (x + 0.20, y - 0.150), (x + 0.32, y - 0.170)],
                 [0.050, 0.062, 0.016], Carnevale.white)
            line([(x + 0.12, y - 0.092), (x + 0.21, y - 0.148), (x + 0.30, y - 0.166)], pen.opacity(0.35), weight: 0.8)
            tricorn(x: x, y: y - 0.075, pw: 0.34, ph: 0.085)
        }
    }
}

// MARK: - Parts

extension CarnevaleCourt {
    /// A shape placed by its centre and outlined in ink.
    func part<S: Shape>(_ s: S, _ pw: CGFloat, _ ph: CGFloat,
                        _ x: CGFloat, _ y: CGFloat, _ tint: Color) -> some View {
        s.fill(tint)
            .overlay { s.stroke(pen, lineWidth: hair * 1.3) }
            .frame(width: w * pw, height: h * ph)
            .position(x: w * x, y: h * y)
    }

    func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat], _ tint: Color) -> some View {
        let shape = Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1) }, widths: widths)
        return shape.fill(tint)
            .overlay { shape.stroke(pen, lineWidth: hair * 1.3) }
            .frame(width: w, height: h)
    }

    /// An inked line through points, `weight` times the hairline.
    func line(_ spine: [(CGFloat, CGFloat)], _ tint: Color, weight: CGFloat = 1) -> some View {
        Stroke(spine: spine.map { CGPoint(x: $0.0, y: $0.1) })
            .stroke(tint, style: StrokeStyle(lineWidth: hair * weight, lineCap: .round))
            .frame(width: w, height: h)
    }

    /// A round dot, `d` across against the width.
    func dot(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat, _ tint: Color) -> some View {
        Circle().fill(tint).frame(width: w * d, height: w * d).position(x: w * x, y: h * y)
    }

    func glove(at x: CGFloat, _ y: CGFloat) -> some View {
        part(Ellipse(), 0.060, 0.040, x, y, Carnevale.white)
    }

    /// A lace cuff at the wrist.
    func cuff(at x: CGFloat, _ y: CGFloat) -> some View {
        part(Carnevale.Scalloped(count: 8, depth: 0.22), 0.080, 0.050, x, y, Carnevale.white)
    }

    /// A black shoe with a gold buckle, its toe pointing `toe` (-1 left, 1 right).
    func shoe(from point: (CGFloat, CGFloat), toe: CGFloat) -> some View {
        ZStack {
            limb([point, (point.0 + toe * 0.020, point.1 + 0.030), (point.0 + toe * 0.064, point.1 + 0.038)],
                 [0.082, 0.076, 0.050], pen)
            dot(point.0 + toe * 0.020, point.1 + 0.028, 0.032, Carnevale.gold)
        }
    }

    /// Gold buttons down a coat front.
    func buttons(x: CGFloat, from y: CGFloat, count: Int) -> some View {
        ForEach(0..<count, id: \.self) { index in
            dot(x, y + CGFloat(index) * 0.068, 0.024, Carnevale.gold)
        }
    }

    /// Fold lines down both sides of a black cloak, in a grey that shows on it.
    func folds(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) -> some View {
        let grey = Color(white: 0.40)
        return ZStack {
            line([(left, top), (left - 0.03, (top + bottom) / 2), (left - 0.07, bottom)], grey, weight: 1.1)
            line([(right, top), (right + 0.03, (top + bottom) / 2), (right + 0.07, bottom)], grey, weight: 1.1)
            line([(left + 0.04, top + 0.10), (left + 0.02, bottom)], grey, weight: 0.9)
            line([(right - 0.04, top + 0.10), (right - 0.02, bottom)], grey, weight: 0.9)
        }
    }

    func emblem(at point: (CGFloat, CGFloat), scale: CGFloat) -> some View {
        CarnevalePip(suit: suit, size: w * scale)
            .position(x: w * point.0, y: h * point.1)
    }
}
