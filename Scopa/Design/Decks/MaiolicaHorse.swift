import SwiftUI

/// A cream horse dappled in cobalt dabs, its mane and tail laid in with a loaded blue brush.
/// Drawn facing left on the shared `HorseBody`; the court turns it round.
struct MaiolicaHorse: View {
    /// The card width, which the brush follows.
    let unit: CGFloat
    let width: CGFloat
    let height: CGFloat

    // Leg spines, shoulder to hoof, against the horse's frame. The near fore is lifted
    // and tucked so its hoof stays clear of the index corner.
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
    private static let dapples: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.40), CGPoint(x: 0.585, y: 0.355), CGPoint(x: 0.66, y: 0.42),
        CGPoint(x: 0.745, y: 0.37), CGPoint(x: 0.81, y: 0.46), CGPoint(x: 0.56, y: 0.50),
        CGPoint(x: 0.70, y: 0.53), CGPoint(x: 0.43, y: 0.33), CGPoint(x: 0.85, y: 0.36),
    ]

    var body: some View {
        ZStack {
            glazed(HorseEar(offset: 0.044), .shade)
            leg(Self.farHind, Self.hindWidths, .shade)
            leg(Self.farFore, Self.foreWidths, .shade)
            tail
            glazed(HorseEar(offset: 0), .cream)
            glazed(HorseBody(), .cream)
            MaiolicaDapples(points: Self.dapples, size: 0.066)
                .fill(MaiolicaPaint.cobalt.opacity(0.75))
            mane
            leg(Self.nearHind, Self.hindWidths, .cream)
            leg(Self.nearFore, Self.foreWidths, .cream)
            head
        }
        .frame(width: width, height: height)
    }

    private func glazed<S: Shape>(_ shape: S, _ tint: MaiolicaTint,
                                  line: Color? = MaiolicaPaint.manganese) -> some View {
        MaiolicaGlazed(shape: shape, tint: tint, unit: unit, line: line, seed: 23)
    }

    /// A leg, with a manganese hoof over its last joint.
    private func leg(_ spine: [CGPoint], _ widths: [CGFloat], _ tint: MaiolicaTint) -> some View {
        ZStack {
            glazed(Ribbon(spine: spine, widths: widths), tint)
            glazed(Ribbon(spine: Array(spine.suffix(2)), widths: [widths[3] * 1.05, widths[4] * 1.45]),
                   .manganese)
        }
    }

    private var mane: some View {
        let spine = [CGPoint(x: 0.236, y: 0.060), CGPoint(x: 0.318, y: 0.088),
                     CGPoint(x: 0.390, y: 0.152), CGPoint(x: 0.452, y: 0.250)]
        return ZStack {
            glazed(Ribbon(spine: spine, widths: [0.050, 0.110, 0.120, 0.080]), .cobalt,
                   line: MaiolicaPaint.cobaltDeep)
            locks(from: spine, lean: -0.035)
        }
    }

    private var tail: some View {
        let spine = [CGPoint(x: 0.878, y: 0.306), CGPoint(x: 0.952, y: 0.416),
                     CGPoint(x: 0.984, y: 0.576), CGPoint(x: 0.940, y: 0.800)]
        return ZStack {
            glazed(Ribbon(spine: spine, widths: [0.078, 0.112, 0.086, 0.028]), .cobalt,
                   line: MaiolicaPaint.cobaltDeep)
            locks(from: spine, lean: 0.03)
        }
    }

    /// Two darker brush hairs laid along a lock.
    private func locks(from spine: [CGPoint], lean: CGFloat) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                let shift = lean * (CGFloat(k) - 0.5)
                Stroke(spine: spine.map { CGPoint(x: $0.x + shift, y: $0.y - shift * 0.6) })
                    .stroke(MaiolicaPaint.cobaltDeep.opacity(0.7),
                            style: StrokeStyle(lineWidth: max(0.4, unit * 0.006), lineCap: .round))
            }
        }
    }

    /// Eye, nostril and an ochre bridle.
    private var head: some View {
        let strap = StrokeStyle(lineWidth: max(0.5, unit * 0.011), lineCap: .round)
        return ZStack {
            Stroke(spine: [CGPoint(x: 0.092, y: 0.212), CGPoint(x: 0.118, y: 0.268), CGPoint(x: 0.130, y: 0.312)])
                .stroke(MaiolicaPaint.ochre, style: strap)
            Stroke(spine: [CGPoint(x: 0.164, y: 0.126), CGPoint(x: 0.196, y: 0.226), CGPoint(x: 0.226, y: 0.322)])
                .stroke(MaiolicaPaint.ochre, style: strap)
            Ellipse()
                .fill(MaiolicaPaint.manganese)
                .frame(width: height * 0.040, height: height * 0.046)
                .position(x: width * 0.152, y: height * 0.186)
            Ellipse()
                .fill(MaiolicaPaint.manganese.opacity(0.6))
                .frame(width: height * 0.026, height: height * 0.022)
                .position(x: width * 0.076, y: height * 0.272)
        }
    }
}

/// Round dabs at fixed points of a frame, `size` against its height.
private struct MaiolicaDapples: Shape {
    let points: [CGPoint]
    let size: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let d = r.height * size
        for (k, point) in points.enumerated() {
            let squash: CGFloat = k.isMultiple(of: 2) ? 1 : 0.8
            p.addEllipse(in: CGRect(x: r.minX + r.width * point.x - d / 2, y: r.minY + r.height * point.y - d * squash / 2,
                                    width: d, height: d * squash))
        }
        return p
    }
}
