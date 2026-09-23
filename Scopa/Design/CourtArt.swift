import SwiftUI
import ScopaCore

// MARK: - The horse

/// The horse's barrel in profile facing left: muzzle, jaw, crested neck, back, croup and
/// quarters as one outline.
struct HorseBody: Shape {
    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.055, 0.250))                                          // muzzle, top lip
        p.addQuadCurve(to: at(0.160, 0.112), control: at(0.098, 0.168))       // face
        p.addQuadCurve(to: at(0.216, 0.086), control: at(0.186, 0.086))       // poll
        p.addQuadCurve(to: at(0.452, 0.268), control: at(0.348, 0.104))       // crest
        p.addQuadCurve(to: at(0.718, 0.272), control: at(0.588, 0.316))       // back
        p.addQuadCurve(to: at(0.898, 0.322), control: at(0.822, 0.234))       // croup to dock
        p.addQuadCurve(to: at(0.878, 0.562), control: at(0.938, 0.436))       // hindquarter
        p.addQuadCurve(to: at(0.792, 0.616), control: at(0.844, 0.612))       // stifle
        p.addQuadCurve(to: at(0.412, 0.598), control: at(0.606, 0.678))       // belly
        p.addQuadCurve(to: at(0.322, 0.482), control: at(0.344, 0.566))       // chest
        p.addQuadCurve(to: at(0.250, 0.298), control: at(0.278, 0.404))       // throatlatch
        p.addQuadCurve(to: at(0.166, 0.336), control: at(0.216, 0.372))       // cheek
        p.addQuadCurve(to: at(0.058, 0.302), control: at(0.106, 0.356))       // muzzle, underside
        p.addQuadCurve(to: at(0.055, 0.250), control: at(0.032, 0.270))       // lip
        p.closeSubpath()
        return p
    }
}

/// One ear, pricked forward. `offset` slides the far ear behind the near one.
struct HorseEar: Shape {
    var offset: CGFloat

    func path(in r: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + r.width * (x + offset), y: r.minY + r.height * y)
        }
        var p = Path()
        p.move(to: at(0.170, 0.104))
        p.addQuadCurve(to: at(0.184, 0.004), control: at(0.160, 0.046))
        p.addQuadCurve(to: at(0.224, 0.096), control: at(0.222, 0.040))
        p.closeSubpath()
        return p
    }
}

/// A cavallo: articulated legs with the near foreleg lifted, mane, tail, and a head with an
/// eye and a nostril. Legs are drawn twice, a shaded pair behind the barrel and a lit pair
/// in front.
struct HorseArt: View {
    let style: CardStyle
    let coat: Color
    /// The harness and the hooves.
    let accent: Color
    let ink: Color
    let width: CGFloat
    let height: CGFloat

    private var unit: CGFloat { min(width, height) }
    private var hair: CGFloat { max(0.4, unit * 0.018) }
    /// The far side of the animal, its mane and tail. The lithographed sheet has no grey stone.
    private var shade: Color {
        style.isPolychrome ? Pigment.cobalt.opacity(0.26) : ink.opacity(style == .antica ? 0.22 : 0.30)
    }

    // Leg spines, shoulder to hoof. The knee sits forward of the elbow and the fetlock behind it.
    private static let nearFore: [CGPoint] = [
        CGPoint(x: 0.372, y: 0.470), CGPoint(x: 0.356, y: 0.578),
        CGPoint(x: 0.318, y: 0.658), CGPoint(x: 0.244, y: 0.688), CGPoint(x: 0.204, y: 0.736),
    ]
    private static let farFore: [CGPoint] = [
        CGPoint(x: 0.418, y: 0.478), CGPoint(x: 0.408, y: 0.596),
        CGPoint(x: 0.418, y: 0.706), CGPoint(x: 0.404, y: 0.848), CGPoint(x: 0.400, y: 0.944),
    ]
    private static let nearHind: [CGPoint] = [
        CGPoint(x: 0.818, y: 0.452), CGPoint(x: 0.788, y: 0.588),
        CGPoint(x: 0.842, y: 0.700), CGPoint(x: 0.850, y: 0.838), CGPoint(x: 0.852, y: 0.944),
    ]
    private static let farHind: [CGPoint] = [
        CGPoint(x: 0.756, y: 0.466), CGPoint(x: 0.728, y: 0.602),
        CGPoint(x: 0.780, y: 0.708), CGPoint(x: 0.792, y: 0.842), CGPoint(x: 0.794, y: 0.944),
    ]
    private static let foreWidths: [CGFloat] = [0.115, 0.082, 0.058, 0.044, 0.040]
    private static let hindWidths: [CGFloat] = [0.168, 0.104, 0.060, 0.046, 0.042]

    private static let mane: [CGPoint] = [
        CGPoint(x: 0.248, y: 0.062), CGPoint(x: 0.324, y: 0.086),
        CGPoint(x: 0.392, y: 0.152), CGPoint(x: 0.452, y: 0.248),
    ]
    private static let tail: [CGPoint] = [
        CGPoint(x: 0.878, y: 0.306), CGPoint(x: 0.952, y: 0.416),
        CGPoint(x: 0.986, y: 0.576), CGPoint(x: 0.944, y: 0.808),
    ]

    var body: some View {
        ZStack {
            ear(offset: 0.044, tint: shade)
            leg(Self.farHind, widths: Self.hindWidths, tint: shade)
            leg(Self.farFore, widths: Self.foreWidths, tint: shade)
            tail
            ear(offset: 0, tint: coat)
            Drawn(HorseBody(), style: style, colour: coat, ink: ink, unit: unit)
            mane
            leg(Self.nearHind, widths: Self.hindWidths, tint: coat)
            leg(Self.nearFore, widths: Self.foreWidths, tint: coat)
            eye
            if style.isDetailed { headwork }
            bridle
        }
        .frame(width: width, height: height)
    }

    // MARK: Pieces

    private func ear(offset: CGFloat, tint: Color) -> some View {
        Drawn(HorseEar(offset: offset), style: style, colour: tint, ink: ink, unit: unit)
    }

    /// A leg, with a dark wedge for the hoof.
    private func leg(_ spine: [CGPoint], widths: [CGFloat], tint: Color) -> some View {
        ZStack {
            Drawn(Ribbon(spine: spine, widths: widths), style: style, colour: tint, ink: ink, unit: unit)
            Drawn(Ribbon(spine: Array(spine.suffix(2)), widths: [widths[3] * 1.05, widths[4] * 1.5]),
                  style: style, colour: accent.opacity(0.85), ink: ink, unit: unit)
        }
    }

    private var mane: some View {
        ZStack {
            Drawn(Ribbon(spine: Self.mane, widths: [0.046, 0.104, 0.116, 0.082]),
                  style: style, colour: shade, ink: ink, unit: unit)
            if style.isDetailed {
                ForEach(0..<3, id: \.self) { index in
                    let t = 0.24 + Double(index) * 0.24
                    Stroke(spine: [
                        CGPoint(x: 0.216 + t * 0.22, y: 0.058 + t * 0.10),
                        CGPoint(x: 0.256 + t * 0.22, y: 0.104 + t * 0.12),
                        CGPoint(x: 0.276 + t * 0.24, y: 0.158 + t * 0.12),
                    ])
                    .stroke(ink.opacity(0.35), lineWidth: hair)
                }
            }
        }
    }

    private var tail: some View {
        Drawn(Ribbon(spine: Self.tail, widths: [0.078, 0.108, 0.082, 0.026]),
              style: style, colour: shade, ink: ink, unit: unit)
    }

    private var eye: some View {
        Ellipse()
            .fill(ink.opacity(0.85))
            .frame(width: unit * 0.030, height: unit * 0.038)
            .position(x: width * 0.152, y: height * 0.186)
    }

    /// The nostril and the line of the mouth.
    private var headwork: some View {
        ZStack {
            Ellipse()
                .fill(ink.opacity(0.55))
                .frame(width: unit * 0.024, height: unit * 0.020)
                .position(x: width * 0.076, y: height * 0.272)
            Stroke(spine: [CGPoint(x: 0.128, y: 0.286), CGPoint(x: 0.186, y: 0.300), CGPoint(x: 0.238, y: 0.322)])
                .stroke(ink.opacity(0.30), lineWidth: hair)
        }
    }

    /// Browband, cheekpiece and noseband, in the accent.
    private var bridle: some View {
        ZStack {
            Stroke(spine: [CGPoint(x: 0.092, y: 0.212), CGPoint(x: 0.118, y: 0.268), CGPoint(x: 0.130, y: 0.312)])
                .stroke(accent, lineWidth: hair * 1.6)
            Stroke(spine: [CGPoint(x: 0.164, y: 0.126), CGPoint(x: 0.196, y: 0.226), CGPoint(x: 0.226, y: 0.322)])
                .stroke(accent, lineWidth: hair * 1.6)
        }
    }
}

// MARK: - The court

/// Fante, cavallo and re, laid out once and finished by the style.
///
/// Everything is placed in the figure's own unit square, so a limb, a robe and a hat share
/// one coordinate system.
struct CourtArt: View {
    let style: CardStyle
    let rank: Rank
    let suit: Suit
    let size: CGFloat
    /// The robe, taken from the suit.
    let colour: Color
    /// Gold: crowns, hems, harness, hilts.
    let accent: Color
    let ink: Color

    private var u: CGFloat { size }
    private var hair: CGFloat { max(0.4, u * 0.014) }
    private static let skin = Color(red: 0.949, green: 0.855, blue: 0.749)
    private var cloth: Color { ink.opacity(style == .antica ? 0.32 : 0.55) }

    // A lithographed court is dressed from the sheet's own stones. The suit picks only the robe.
    private var litho: Bool { style.isPolychrome }
    private var pen: Color { litho ? Pigment.ink : ink }
    private var gown: Color { litho ? Pigment.lead(suit) : colour }
    private var sleeve: Color { litho ? Pigment.vermilion : colour }
    private var hose: Color { litho ? Pigment.cobalt : cloth }
    private var trim: Color { litho ? Pigment.gold : accent }
    private var drape: Color { litho ? Pigment.plum : accent.opacity(0.92) }
    private var hatTint: Color { litho ? Pigment.vermilion : accent }
    private var plumeTint: Color { litho ? Pigment.leaf : accent.opacity(0.85) }
    private var bootTint: Color { litho ? Pigment.ink : ink.opacity(style == .antica ? 0.42 : 0.78) }

    var body: some View {
        ZStack {
            switch rank {
            case .king: king
            case .knight: knight
            default: knave
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Fante

    private var knave: some View {
        ZStack {
            limb([(0.455, 0.600), (0.430, 0.756), (0.426, 0.902)], [0.118, 0.096, 0.086], hose)
            limb([(0.545, 0.600), (0.564, 0.756), (0.570, 0.902)], [0.118, 0.096, 0.086],
                 litho ? Pigment.vermilion : hose)
            boot(at: 0.426)
            boot(at: 0.570)
            limb([(0.400, 0.420), (0.302, 0.502), (0.248, 0.588)], [0.086, 0.070, 0.060], sleeve)
            limb([(0.600, 0.420), (0.688, 0.500), (0.628, 0.586)], [0.086, 0.070, 0.060], sleeve)
            hand(at: (0.240, 0.602))
            hand(at: (0.622, 0.600))
            gown(flare: 0.20, width: 0.42, height: 0.34, x: 0.50, y: 0.545)
            band(width: 0.34, height: 0.040, x: 0.50, y: 0.582, trim)
            band(width: 0.47, height: 0.046, x: 0.50, y: 0.706, trim)
            if style.isDetailed { folds(x: 0.50, top: 0.44, bottom: 0.70, spread: 0.13) }
            head(at: 0.245, scale: 0.23, beard: false)
            shape(Cap(), width: 0.28, height: 0.132, x: 0.50, y: 0.108, hatTint)
            if style.isDetailed { plume(from: (0.615, 0.108), to: (0.735, 0.020)) }
            emblem(at: (0.202, 0.640), scale: 0.30)
        }
    }

    // MARK: Cavallo

    // The rider's head sits on the card's centre line and the seat behind the withers, so
    // the horse is placed forward of centre rather than the rider pushed back along it.
    private static let seat: CGFloat = 0.545
    private static let horseCentre: CGFloat = 0.465

    private var knight: some View {
        let seat = Self.seat
        return ZStack {
            HorseArt(style: style, coat: litho ? Pigment.ivory : Color(white: style == .moderna ? 0.82 : 0.91),
                     accent: trim, ink: pen, width: u * 0.98, height: u * 0.62)
                .position(x: u * Self.horseCentre, y: u * 0.66)
            shape(Trapezoid(topRatio: 1.35), width: 0.26, height: 0.105, x: seat, y: 0.556,
                  litho ? Pigment.vermilion : gown)
            band(width: 0.28, height: 0.030, x: seat, y: 0.598, trim)
            limb([(seat + 0.045, 0.330), (seat + 0.147, 0.402), (seat + 0.229, 0.502)],
                 [0.160, 0.196, 0.104], litho ? Pigment.plum : gown.opacity(0.85))
            rein
            // The leg swings forward to the stirrup so the boot stays over the girth.
            limb([(seat - 0.010, 0.495), (0.478, 0.575), (0.452, 0.665), (0.440, 0.726)],
                 [0.106, 0.088, 0.070, 0.062], hose)
            boot(at: 0.440, y: 0.742, facing: -1)
            gown(flare: 0.10, width: 0.20, height: 0.245, x: seat, y: 0.400)
            band(width: 0.21, height: 0.034, x: seat, y: 0.478, trim)
            limb([(seat - 0.033, 0.360), (seat - 0.145, 0.300), (seat - 0.250, 0.244)],
                 [0.078, 0.066, 0.056], sleeve)
            hand(at: (seat - 0.258, 0.240), scale: 0.056)
            hand(at: (seat - 0.049, 0.478), scale: 0.052)
            head(at: 0.216, scale: 0.20, beard: false, x: seat)
            shape(Helmet(), width: 0.215, height: 0.105, x: seat, y: 0.148, hatTint)
            if style.isDetailed { plume(from: (seat + 0.085, 0.130), to: (seat + 0.193, 0.042)) }
            emblem(at: (seat - 0.332, 0.194), scale: 0.24)
        }
    }

    // MARK: Re

    private var king: some View {
        ZStack {
            gown(flare: 0.34, width: 0.46, height: 0.54, x: 0.50, y: 0.660)
            band(width: 0.58, height: 0.052, x: 0.50, y: 0.912, trim)
            if style.isDetailed { folds(x: 0.50, top: 0.50, bottom: 0.89, spread: 0.19) }
            limb([(0.402, 0.448), (0.348, 0.502), (0.308, 0.548)], [0.084, 0.070, 0.062], sleeve)
            limb([(0.598, 0.448), (0.664, 0.508), (0.712, 0.572)], [0.084, 0.070, 0.062], sleeve)
            hand(at: (0.300, 0.560))
            hand(at: (0.722, 0.586))
            sceptre
            shape(Mantle(), width: 0.40, height: 0.185, x: 0.50, y: 0.418, drape)
            head(at: 0.236, scale: 0.24, beard: true)
            shape(KingCrown(), width: 0.31, height: 0.145, x: 0.50, y: 0.108, trim)
            emblem(at: (0.760, 0.638), scale: 0.30)
        }
    }

    // MARK: Pieces

    /// A limb: the spine and widths given in the figure's own unit square.
    private func limb(_ spine: [(CGFloat, CGFloat)], _ widths: [CGFloat], _ tint: Color) -> some View {
        Drawn(Ribbon(spine: spine.map { CGPoint(x: $0.0, y: $0.1) }, widths: widths),
              style: style, colour: tint, ink: pen, unit: u)
            .frame(width: u, height: u)
    }

    /// A shape placed by its centre, in unit coordinates.
    private func shape<S: Shape>(_ s: S, width: CGFloat, height: CGFloat,
                                 x: CGFloat, y: CGFloat, _ tint: Color) -> some View {
        Drawn(s, style: style, colour: tint, ink: pen, unit: u)
            .frame(width: u * width, height: u * height)
            .position(x: u * x, y: u * y)
    }

    private func band(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, _ tint: Color) -> some View {
        shape(Capsule(), width: width, height: height, x: x, y: y, tint)
    }

    /// A gown, and for the lithographed sheet the stripe woven down it.
    private func gown(flare: CGFloat, width: CGFloat, height: CGFloat,
                      x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            shape(Robe(flare: flare), width: width, height: height, x: x, y: y, gown)
            if litho {
                HStack(spacing: u * width * 0.18) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(Pigment.gold.opacity(0.62)).frame(width: u * width * 0.035)
                    }
                }
                .frame(width: u * width, height: u * height)
                .clipShape(Robe(flare: flare))
                .position(x: u * x, y: u * y)
            }
        }
    }

    /// A boot: the toe points the way the figure faces.
    private func boot(at x: CGFloat, y: CGFloat = 0.928, facing: CGFloat = -1) -> some View {
        limb([(x, y - 0.030), (x + facing * 0.030, y + 0.026), (x + facing * 0.072, y + 0.030)],
             [0.082, 0.074, 0.056], bootTint)
    }

    /// A head in profile, with hair, an eye, and a beard for the re.
    private func head(at y: CGFloat, scale: CGFloat, beard: Bool, x: CGFloat = 0.50) -> some View {
        ZStack {
            if beard {
                shape(Beard(), width: scale * 1.02, height: scale * 0.92,
                      x: x - scale * 0.02, y: y + scale * 0.42, cloth)
            }
            shape(Head(), width: scale * 0.92, height: scale, x: x, y: y, Self.skin)
            shape(Hair(), width: scale * 0.98, height: scale * 0.56,
                  x: x + scale * 0.03, y: y - scale * 0.22, cloth)
            if style.isDetailed {
                Circle()
                    .fill(ink.opacity(0.85))
                    .frame(width: u * scale * 0.085)
                    .position(x: u * (x - scale * 0.20), y: u * (y - scale * 0.02))
            }
        }
    }

    /// Three fold lines down a robe.
    private func folds(x: CGFloat, top: CGFloat, bottom: CGFloat, spread: CGFloat) -> some View {
        ForEach(0..<3, id: \.self) { index in
            let lean = (CGFloat(index) - 1) * spread
            Stroke(spine: [
                CGPoint(x: x + lean * 0.34, y: top),
                CGPoint(x: x + lean * 0.74, y: (top + bottom) / 2),
                CGPoint(x: x + lean, y: bottom),
            ])
            .stroke(ink.opacity(0.22), lineWidth: hair)
            .frame(width: u, height: u)
        }
    }

    private func plume(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> some View {
        limb([from, ((from.0 + to.0) / 2 + 0.02, (from.1 + to.1) / 2 - 0.03), to],
             [0.048, 0.036, 0.014], plumeTint)
    }

    private var sceptre: some View {
        ZStack {
            band(width: 0.036, height: 0.44, x: 0.288, y: 0.480, trim)
            shape(Circle(), width: 0.090, height: 0.090, x: 0.288, y: 0.256, trim)
        }
    }

    /// The rein, from the noseband back to the rider's hand.
    private var rein: some View {
        Stroke(spine: [CGPoint(x: Self.horseCentre - 0.362, y: 0.540),
                       CGPoint(x: 0.310, y: 0.498),
                       CGPoint(x: Self.seat - 0.049, y: 0.478)])
            .stroke(ink.opacity(0.55), lineWidth: hair * 1.2)
            .frame(width: u, height: u)
    }

    private func hand(at point: (CGFloat, CGFloat), scale: CGFloat = 0.062) -> some View {
        shape(Circle(), width: scale, height: scale, x: point.0, y: point.1, Self.skin)
    }

    private func emblem(at point: (CGFloat, CGFloat), scale: CGFloat) -> some View {
        SuitArt(style: style, suit: suit, size: u * scale,
                colour: colour, accent: accent, ink: ink)
            .position(x: u * point.0, y: u * point.1)
    }
}
