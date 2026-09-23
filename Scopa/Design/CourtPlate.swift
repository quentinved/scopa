import SwiftUI
import ScopaCore

/// The court drawn to fill the card, the way a printed sheet does. `CourtArt` draws the
/// small square figure that floats clear of the card edges instead.
///
/// Laid out in a portrait unit box: x against the plate's width, y against its height, and
/// every limb width against the width, so nothing fattens as the plate grows taller.
struct CourtPlate: View {
    let rank: Rank
    let suit: Suit
    let width: CGFloat
    let height: CGFloat

    private var w: CGFloat { width }
    private var h: CGFloat { height }
    /// The outline colour. Everything is outlined: flat colour inside a heavy line is what
    /// reads as printed.
    private var pen: Color { Pigment.ink }
    private var hair: CGFloat { max(0.45, w * 0.012) }
    private static let flesh = Color(red: 0.976, green: 0.855, blue: 0.741)
    private static let locks = Color(red: 0.310, green: 0.196, blue: 0.129)

    /// The doublet takes the suit, everything else comes off the sheet's other stones.
    private var cloth: Color { Pigment.lead(suit) }

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

    /// A page in doublet and parti-coloured hose, one hand on his hip and the suit held out
    /// in the other. Two hose colours keep the legs from reading as one lump.
    private var knave: some View {
        ZStack {
            shoe(from: (0.420, 0.902), toe: -1)
            shoe(from: (0.585, 0.902), toe: 1)
            limb([(0.440, 0.612), (0.425, 0.760), (0.420, 0.906)], [0.135, 0.116, 0.100], Pigment.cobalt)
            limb([(0.560, 0.612), (0.578, 0.760), (0.585, 0.906)], [0.135, 0.116, 0.100], Pigment.vermilion)
            part(Capsule(), 0.128, 0.024, 0.424, 0.752, Pigment.gold)
            part(Capsule(), 0.128, 0.024, 0.580, 0.752, Pigment.gold)

            // The skirt of the doublet, over the top of the hose.
            part(Trapezoid(topRatio: 0.80), 0.44, 0.082, 0.50, 0.578, Pigment.gold)
            scallops(y: 0.616, from: 0.290, to: 0.710, count: 5)

            limb([(0.375, 0.362), (0.300, 0.424), (0.268, 0.500)], [0.150, 0.106, 0.086], Pigment.plum)
            limb([(0.625, 0.362), (0.712, 0.428), (0.652, 0.508)], [0.150, 0.106, 0.086], Pigment.plum)
            slashes(at: (0.336, 0.392), angle: -38)
            slashes(at: (0.668, 0.396), angle: 34)
            hand(at: (0.256, 0.520))
            hand(at: (0.648, 0.528))

            dressed(Robe(flare: 0.10), 0.36, 0.215, 0.50, 0.424)
            part(Capsule(), 0.375, 0.032, 0.50, 0.528, pen)
            part(Rectangle(), 0.052, 0.040, 0.50, 0.528, Pigment.gold)

            ruff(at: 0.306, scale: 0.32)
            head(at: 0.238, scale: 0.205)
            part(Cap(), 0.32, 0.115, 0.50, 0.140, Pigment.vermilion)
            part(Capsule(), 0.44, 0.046, 0.50, 0.186, Pigment.vermilion)
            plume(from: (0.640, 0.132), to: (0.880, 0.044))

            emblem(at: (0.214, 0.640), scale: 0.32)
        }
    }

    // MARK: Cavallo

    /// The horse runs the full width of the card across the lower half, and the rider
    /// stands out of the saddle into the upper half.
    private var knight: some View {
        // The rider's centre line. Everything above the saddle is placed against this, so
        // the hat, head and ruff cannot drift apart.
        let seat: CGFloat = 0.545
        return ZStack {
            // Forward of the plate's centre, so the saddle lands under the seat.
            HorseArt(style: .litografia, coat: Pigment.ivory, accent: Pigment.gold,
                     ink: pen, width: w * 0.98, height: h * 0.400)
                .position(x: w * 0.485, y: h * 0.762)

            part(Trapezoid(topRatio: 1.30), 0.30, 0.076, seat, 0.700, Pigment.vermilion)
            scallops(y: 0.730, from: seat - 0.134, to: seat + 0.134, count: 4)
            part(Capsule(), 0.31, 0.022, seat, 0.672, Pigment.gold)

            limb([(seat + 0.075, 0.470), (seat + 0.177, 0.542), (seat + 0.259, 0.644)],
                 [0.200, 0.240, 0.120], Pigment.plum)
            rein
            // Forward to the stirrup rather than straight down from the seat, so the foot
            // lands on the girth and not in front of the horse's chest.
            limb([(seat - 0.015, 0.640), (0.492, 0.700), (0.465, 0.762), (0.450, 0.802)],
                 [0.118, 0.098, 0.080, 0.070], Pigment.cobalt)
            shoe(from: (0.450, 0.802), toe: -1)

            dressed(Robe(flare: 0.10), 0.25, 0.190, seat, 0.520)
            part(Capsule(), 0.26, 0.028, seat, 0.600, Pigment.gold)
            limb([(seat - 0.037, 0.468), (seat - 0.149, 0.424), (seat - 0.253, 0.382)],
                 [0.108, 0.088, 0.072], Pigment.plum)
            slashes(at: (seat - 0.093, 0.446), angle: 18)
            hand(at: (seat - 0.261, 0.378))
            hand(at: (seat - 0.067, 0.620))

            ruff(at: 0.436, scale: 0.24, x: seat)
            head(at: 0.372, scale: 0.190, x: seat)
            part(Cap(), 0.30, 0.100, seat, 0.278, Pigment.vermilion)
            part(Capsule(), 0.38, 0.040, seat, 0.320, Pigment.vermilion)
            plume(from: (seat + 0.130, 0.268), to: (seat + 0.336, 0.192))

            emblem(at: (seat - 0.345, 0.316), scale: 0.30)
        }
    }

    // MARK: Re

    /// A king in a floor-length robe with an orphrey band down the front, an ermine mantle,
    /// and the sceptre standing the whole height of the figure.
    private var king: some View {
        ZStack {
            shoe(from: (0.452, 0.900), toe: -1)
            shoe(from: (0.548, 0.900), toe: 1)
            dressed(Robe(flare: 0.32), 0.48, 0.500, 0.50, 0.660)
            // The orphrey: the embroidered band down the centre of a vestment.
            part(Rectangle(), 0.082, 0.430, 0.50, 0.672, Pigment.gold)
            ForEach(0..<5, id: \.self) { index in
                part(Circle(), 0.036, 0.024, 0.50, 0.512 + CGFloat(index) * 0.078, Pigment.vermilion)
            }
            part(Capsule(), 0.62, 0.048, 0.50, 0.888, Pigment.gold)
            checks(y: 0.888, from: 0.220, to: 0.780, count: 9)

            limb([(0.390, 0.430), (0.330, 0.500), (0.300, 0.572)], [0.135, 0.104, 0.084], cloth)
            limb([(0.610, 0.430), (0.678, 0.502), (0.712, 0.578)], [0.135, 0.104, 0.084], cloth)
            hand(at: (0.290, 0.592))
            hand(at: (0.722, 0.598))
            sceptre

            // The mantle, ermine-spotted.
            part(Mantle(), 0.46, 0.125, 0.50, 0.392, Pigment.plum)
            ForEach(0..<4, id: \.self) { index in
                part(Circle(), 0.028, 0.019, 0.368 + CGFloat(index) * 0.088, 0.406, Pigment.ivory)
            }
            ruff(at: 0.330, scale: 0.30)
            beard
            head(at: 0.232, scale: 0.225)
            part(KingCrown(), 0.38, 0.115, 0.50, 0.126, Pigment.gold)
            ForEach(0..<3, id: \.self) { index in
                part(Circle(), 0.038, 0.026, 0.412 + CGFloat(index) * 0.088, 0.152, Pigment.vermilion)
            }

            emblem(at: (0.752, 0.664), scale: 0.30)
        }
    }

    // MARK: Pieces

    private func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat], _ tint: Color) -> some View {
        let shape = Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1) }, widths: widths)
        return shape
            .fill(tint)
            .overlay { shape.stroke(pen, lineWidth: hair * 1.7) }
            .frame(width: w, height: h)
    }

    private func part<S: Shape>(_ s: S, _ pw: CGFloat, _ ph: CGFloat,
                                _ x: CGFloat, _ y: CGFloat, _ tint: Color) -> some View {
        s.fill(tint)
            .overlay { s.stroke(pen, lineWidth: hair * 1.7) }
            .frame(width: w * pw, height: h * ph)
            .position(x: w * x, y: h * y)
    }

    /// A garment, with a stripe woven down it so the colour is never flat.
    private func dressed<S: Shape>(_ s: S, _ pw: CGFloat, _ ph: CGFloat,
                                   _ x: CGFloat, _ y: CGFloat) -> some View {
        ZStack {
            part(s, pw, ph, x, y, cloth)
            HStack(spacing: w * pw * 0.20) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(Pigment.gold.opacity(0.70)).frame(width: w * pw * 0.040)
                }
            }
            .frame(width: w * pw, height: h * ph)
            .clipShape(s)
            .position(x: w * x, y: h * y)
        }
    }

    /// A face: two eyes, a nose and a mouth, none more than a point across.
    private func head(at y: CGFloat, scale: CGFloat, x: CGFloat = 0.50) -> some View {
        ZStack {
            part(Capsule(), scale * 0.94, scale * 0.62, x, y, Self.locks)
            part(Ellipse(), scale * 0.86, scale * 0.55, x, y + scale * 0.045, Self.flesh)
            Group {
                Circle().fill(pen)
                    .frame(width: w * scale * 0.085)
                    .position(x: w * (x - scale * 0.185), y: h * (y + scale * 0.005))
                Circle().fill(pen)
                    .frame(width: w * scale * 0.085)
                    .position(x: w * (x + scale * 0.185), y: h * (y + scale * 0.005))
                Stroke(spine: [CGPoint(x: x, y: y + scale * 0.02),
                               CGPoint(x: x - scale * 0.05, y: y + scale * 0.14)])
                    .stroke(pen.opacity(0.7), lineWidth: hair)
                Stroke(spine: [CGPoint(x: x - scale * 0.12, y: y + scale * 0.235),
                               CGPoint(x: x + scale * 0.12, y: y + scale * 0.235)])
                    .stroke(pen.opacity(0.8), lineWidth: hair * 1.3)
            }
            .frame(width: w, height: h)
        }
    }

    private var beard: some View {
        part(Bowl(roundness: 0.80), 0.26, 0.105, 0.50, 0.318, Self.locks)
    }

    /// The pleated collar, which is what separates a head from a body at this size.
    private func ruff(at y: CGFloat, scale: CGFloat, x: CGFloat = 0.50) -> some View {
        ZStack {
            part(Capsule(), scale, scale * 0.155, x, y, Pigment.ivory)
            checks(y: y, from: x - scale / 2 + 0.012, to: x + scale / 2 - 0.012, count: 6)
        }
    }

    private func hand(at point: (CGFloat, CGFloat)) -> some View {
        part(Circle(), 0.062, 0.042, point.0, point.1, Self.flesh)
    }

    private func shoe(from point: (CGFloat, CGFloat), toe: CGFloat) -> some View {
        limb([point, (point.0 + toe * 0.020, point.1 + 0.042), (point.0 + toe * 0.070, point.1 + 0.050)],
             [0.102, 0.092, 0.062], pen)
    }

    private func plume(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> some View {
        limb([from, ((from.0 + to.0) / 2 + 0.02, (from.1 + to.1) / 2 - 0.028), to],
             [0.066, 0.048, 0.016], Pigment.leaf)
    }

    /// Slashes cut in a sleeve to show the shirt beneath.
    private func slashes(at point: (CGFloat, CGFloat), angle: Double) -> some View {
        VStack(spacing: h * 0.016) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule().fill(Pigment.ivory)
                    .overlay { Capsule().stroke(pen.opacity(0.6), lineWidth: hair * 0.8) }
                    .frame(width: w * 0.075, height: h * 0.010)
            }
        }
        .rotationEffect(.degrees(angle))
        .position(x: w * point.0, y: h * point.1)
    }

    /// A scalloped edge, for a hem that would otherwise be a ruled line.
    private func scallops(y: CGFloat, from: CGFloat, to: CGFloat, count: Int) -> some View {
        let step = (to - from) / CGFloat(count)
        return ForEach(0..<count, id: \.self) { index in
            Circle()
                .fill(Pigment.gold)
                .overlay { Circle().stroke(pen, lineWidth: hair * 1.3) }
                .frame(width: w * step * 0.92, height: w * step * 0.92)
                .position(x: w * (from + step * (CGFloat(index) + 0.5)), y: h * y)
        }
    }

    /// A row of alternating squares: the checked band on a hem or a ruff.
    private func checks(y: CGFloat, from: CGFloat, to: CGFloat, count: Int) -> some View {
        let step = (to - from) / CGFloat(count)
        return ForEach(0..<count, id: \.self) { index in
            Rectangle()
                .fill(index.isMultiple(of: 2) ? Pigment.cobalt : Pigment.vermilion)
                .frame(width: w * step * 0.62, height: h * 0.016)
                .position(x: w * (from + step * (CGFloat(index) + 0.5)), y: h * y)
        }
    }

    private var sceptre: some View {
        ZStack {
            part(Capsule(), 0.036, 0.330, 0.288, 0.470, Pigment.gold)
            part(Circle(), 0.092, 0.062, 0.288, 0.292, Pigment.gold)
            part(Circle(), 0.040, 0.027, 0.288, 0.292, Pigment.vermilion)
        }
    }

    private var rein: some View {
        Stroke(spine: [CGPoint(x: 0.124, y: 0.686), CGPoint(x: 0.320, y: 0.650),
                       CGPoint(x: 0.478, y: 0.624)])
            .stroke(pen.opacity(0.8), lineWidth: hair * 1.6)
            .frame(width: w, height: h)
    }

    private func emblem(at point: (CGFloat, CGFloat), scale: CGFloat) -> some View {
        SuitArt(style: .litografia, suit: suit, size: w * scale,
                colour: cloth, accent: Pigment.gold, ink: pen)
            .position(x: w * point.0, y: h * point.1)
    }
}
