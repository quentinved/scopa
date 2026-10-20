import SwiftUI

/// Mother-of-pearl, which Perla's foils are finished in and Madreperla lays on every card.
///
/// Drawn rather than lit: a pearl ground, soft bands of colour laid in rings from a point
/// off the card the way a shell grows, the fine growth lines between them, and one cool
/// lustre. All of it static, and drawn inside the card's own rasterised face, so a hand of
/// pearl cards costs what a plain one does. Each card sits at its own place in the shell,
/// so no two in a hand catch the colour alike.
enum Nacre {
    static let pearl = Color(red: 0.975, green: 0.968, blue: 0.962)
    static let blush = Color(red: 0.98, green: 0.78, blue: 0.84)
    static let peach = Color(red: 0.99, green: 0.86, blue: 0.74)
    static let butter = Color(red: 0.95, green: 0.93, blue: 0.73)
    static let mint = Color(red: 0.73, green: 0.92, blue: 0.85)
    static let aqua = Color(red: 0.69, green: 0.85, blue: 0.97)
    static let lilac = Color(red: 0.82, green: 0.77, blue: 0.97)
    /// The frame's metal, and the dark either side of it that lets pearl read on gold.
    static let silver = Color(red: 0.80, green: 0.82, blue: 0.86)
    static let silverDeep = Color(red: 0.44, green: 0.47, blue: 0.55)
    static let graphite = Color(red: 0.19, green: 0.21, blue: 0.26)
    /// The light a Perla foil turns over in: pearl with a breath of lilac.
    static let glow = Color(red: 0.89, green: 0.88, blue: 1)

    static let rainbow = [blush, peach, butter, mint, aqua, lilac]

    /// How deep the pearl goes: a light sheen on every card, or a foil's whole face.
    enum Depth { case sheen, foil }

    /// The rainbow round `turns` times, starting `phase` of the way in.
    static func bands(turns: Int, phase: Double) -> [Gradient.Stop] {
        let count = rainbow.count * turns
        let start = Int((phase * Double(rainbow.count)).rounded()) % rainbow.count
        return (0...count).map { index in
            .init(color: rainbow[(start + index) % rainbow.count], location: Double(index) / Double(count))
        }
    }

    /// The pearl of a frame or a plate: white shell with a glint of each colour.
    static let shell = AngularGradient(stops: [
        .init(color: pearl, location: 0),
        .init(color: lilac, location: 0.1),
        .init(color: .white, location: 0.18),
        .init(color: aqua, location: 0.3),
        .init(color: pearl, location: 0.4),
        .init(color: blush, location: 0.52),
        .init(color: .white, location: 0.62),
        .init(color: mint, location: 0.74),
        .init(color: butter, location: 0.86),
        .init(color: pearl, location: 1),
    ], center: .center, angle: .degrees(-30))

    /// The same laid flat across a board: a cover, a bar, a tag.
    static let board = LinearGradient(stops: [
        .init(color: silver, location: 0),
        .init(color: lilac, location: 0.2),
        .init(color: pearl, location: 0.38),
        .init(color: .white, location: 0.47),
        .init(color: blush, location: 0.6),
        .init(color: aqua, location: 0.8),
        .init(color: silver, location: 1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The pearl over a card's face, under its frame. `phase` is where in the shell this card
/// was cut from, nought to one.
struct NacreFace: View {
    let width: CGFloat
    let depth: Nacre.Depth
    /// The deck paints its own face, often dark or gilded: the colour has to lighten there,
    /// since tinting alone vanishes on navy and on gold.
    var painted = false
    var phase: Double = 0

    private var height: CGFloat { width * 1.5 }
    private var isFoil: Bool { depth == .foil }
    /// Where the rings grow from: below and to the left of the card, moved along by the phase.
    private var centre: UnitPoint { UnitPoint(x: -0.25 + phase * 0.5, y: 1.15 - phase * 0.25) }

    /// How much of each layer a face takes: the colour multiplied in, the colour lightened
    /// in, and the growth lines.
    private var mix: (tint: Double, light: Double, lines: Double) {
        switch (depth, painted) {
        case (.foil, false): (0.55, 0, width > 100 ? 0.42 : 0.55)
        case (.foil, true): (0.4, 0.34, 0.24)
        case (.sheen, false): (0.24, 0, 0.28)
        case (.sheen, true): (0.14, 0.16, 0.16)
        }
    }

    var body: some View {
        // Multiplied, so the ink stays ink; lightened only where the face is dark, since
        // that is the one place multiplying shows nothing.
        ZStack {
            if isFoil && painted { ground }
            rings.blendMode(.multiply).opacity(mix.tint)
            if painted { rings.blendMode(.screen).opacity(mix.light) }
            if width >= 40 {
                NacreGrowth(phase: phase, centre: centre, fine: isFoil)
                    .blendMode(.screen)
                    .opacity(mix.lines)
            }
            lustre
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: width * 0.12))
        .allowsHitTesting(false)
    }

    /// The pearl itself, on a dark or gilded face: lifted toward white, cooler at one corner.
    private var ground: some View {
        LinearGradient(colors: [.white, Nacre.pearl, Nacre.lilac.opacity(0.7), Nacre.pearl],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.screen)
            .opacity(0.08)
    }

    /// The colour, in rings: round three times across the card, pooling at two corners and
    /// thinning to pearl across the middle, where the pips are.
    private var rings: some View {
        RadialGradient(stops: Nacre.bands(turns: 3, phase: phase), center: centre,
                       startRadius: width * 0.2, endRadius: width * 2.1)
            .mask {
                LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.35), location: 0.45 + phase * 0.1),
                    .init(color: .white.opacity(0.9), location: 1),
                ], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
    }

    /// One soft cool shine, across from where the rings grow.
    private var lustre: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.18),
            .init(color: .white.opacity(isFoil ? 0.34 : 0.26), location: 0.34),
            .init(color: Nacre.aqua.opacity(isFoil ? 0.2 : 0.1), location: 0.42),
            .init(color: .clear, location: 0.58),
        ], startPoint: .topTrailing, endPoint: .bottomLeading)
        .blendMode(.screen)
    }
}

/// The growth lines of the shell: fine wavering rings, a hair of light each.
private struct NacreGrowth: View {
    let phase: Double
    let centre: UnitPoint
    /// A foil's lines are closer set.
    let fine: Bool

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: centre.x * size.width, y: centre.y * size.height)
            let count = fine ? 26 : 14
            let reach = hypot(size.width * 1.4, size.height * 1.3)
            let line = max(0.4, size.width * (fine ? 0.006 : 0.008))
            for index in 1...count {
                let radius = reach * (0.18 + 0.82 * Double(index) / Double(count))
                let ring = Self.ring(around: origin, radius: radius, wave: radius * 0.012,
                                     twist: phase * 9 + Double(index) * 1.7)
                let light = index.isMultiple(of: 3) ? 0.9 : 0.5
                context.stroke(ring, with: .color(.white.opacity(light)), lineWidth: line)
            }
        }
    }

    /// A ring that wavers a little in and out, as a shell's growth does.
    private static func ring(around origin: CGPoint, radius: Double, wave: Double, twist: Double) -> Path {
        var path = Path()
        let steps = 72
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let reach = radius + wave * sin(angle * 7 + twist) + wave * 0.6 * sin(angle * 13 - twist)
            let point = CGPoint(x: origin.x + cos(angle) * reach, y: origin.y + sin(angle) * reach)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A card's edge in mother-of-pearl: pearl between a dark line and a silver one, so it reads
/// on cream paper and on Mosaico's gold alike, where leaf laid on leaf vanished. A string of
/// seed pearls round it once the card is big enough for them to be pearls.
struct PearlEdge: View {
    let width: CGFloat
    let radius: CGFloat
    /// Laid over a deck that paints its own frame: wider, and darker either side.
    var wide = false

    private var dark: CGFloat { max(0.8, width * (wide ? 0.02 : 0.013)) }
    private var band: CGFloat { wide ? max(2.4, width * 0.048) : max(1.8, width * 0.032) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Nacre.graphite.opacity(wide ? 0.9 : 0.7), lineWidth: dark)
            RoundedRectangle(cornerRadius: max(radius - dark, 0))
                .strokeBorder(Nacre.shell, lineWidth: band)
                .padding(dark)
            if width >= 90 { SeedPearls(width: width, radius: radius, inset: dark, band: band) }
            RoundedRectangle(cornerRadius: max(radius - dark - band, 0))
                .strokeBorder(Nacre.silverDeep.opacity(wide ? 0.95 : 0.7), lineWidth: max(0.5, dark * 0.7))
                .padding(dark + band)
        }
        .allowsHitTesting(false)
    }
}

/// Seed pearls strung along the band, each with its own light: one Canvas, drawn once.
private struct SeedPearls: View {
    let width: CGFloat
    let radius: CGFloat
    let inset: CGFloat
    let band: CGFloat

    var body: some View {
        Canvas { context, size in
            let middle = inset + band / 2
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: middle, dy: middle)
            let bead = band * 0.92
            for point in Self.points(along: rect, radius: max(radius - middle, 0), spacing: bead * 1.08) {
                let pearl = CGRect(x: point.x - bead / 2, y: point.y - bead / 2, width: bead, height: bead)
                let light = CGPoint(x: pearl.minX + bead * 0.34, y: pearl.minY + bead * 0.3)
                context.fill(Path(ellipseIn: pearl), with: .radialGradient(
                    Gradient(colors: [.white, Nacre.pearl, Nacre.lilac, Nacre.silverDeep]),
                    center: light, startRadius: 0, endRadius: bead * 0.75))
            }
        }
    }

    /// Evenly spaced points round a rounded rectangle, corners included.
    static func points(along rect: CGRect, radius: CGFloat, spacing: CGFloat) -> [CGPoint] {
        let straight = 2 * (rect.width + rect.height - 4 * radius)
        let perimeter = straight + 2 * .pi * radius
        let count = max(Int(perimeter / spacing), 4)
        return (0..<count).map { point(at: perimeter * Double($0) / Double(count), on: rect, radius: radius) }
    }

    /// The point `distance` round the edge, clockwise from the top left corner's end.
    private static func point(at distance: CGFloat, on rect: CGRect, radius r: CGFloat) -> CGPoint {
        let (w, h) = (rect.width - 2 * r, rect.height - 2 * r)
        let arc = .pi / 2 * r
        let legs: [(CGFloat, (CGFloat) -> CGPoint)] = [
            (w, { CGPoint(x: rect.minX + r + $0, y: rect.minY) }),
            (arc, { corner(CGPoint(x: rect.maxX - r, y: rect.minY + r), r, -.pi / 2 + $0 / r) }),
            (h, { CGPoint(x: rect.maxX, y: rect.minY + r + $0) }),
            (arc, { corner(CGPoint(x: rect.maxX - r, y: rect.maxY - r), r, $0 / r) }),
            (w, { CGPoint(x: rect.maxX - r - $0, y: rect.maxY) }),
            (arc, { corner(CGPoint(x: rect.minX + r, y: rect.maxY - r), r, .pi / 2 + $0 / r) }),
            (h, { CGPoint(x: rect.minX, y: rect.maxY - r - $0) }),
            (arc, { corner(CGPoint(x: rect.minX + r, y: rect.minY + r), r, .pi + $0 / r) }),
        ]
        var left = distance
        for (length, at) in legs {
            if left <= length { return at(left) }
            left -= length
        }
        return CGPoint(x: rect.minX + r, y: rect.minY)
    }

    private static func corner(_ centre: CGPoint, _ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
    }
}
