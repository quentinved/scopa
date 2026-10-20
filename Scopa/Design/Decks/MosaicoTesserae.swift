import SwiftUI

/// The glass and stone a Ravenna workshop sets: gold leaf, lapis, marble and the coloured
/// smalti of the figures. The grouts are here too, since a bed is filled like a tile.
enum Smalto: Int, CaseIterable {
    case groutStone, groutGold, groutNight, groutDark
    case goldDeep, goldWarm, gold, goldPale
    case lapisDeep, lapis, lapisLight, sky
    case stoneShade, stone, stonePale, white
    case slate, steel, silver
    case redDeep, red, terracotta, rose
    case greenDeep, green, greenPale
    case purpleDeep, purple, mauve
    case brown, umber
    case fleshShade, flesh, fleshPale
    case ink

    var colour: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }

    private var rgb: (Double, Double, Double) {
        switch self {
        case .groutStone: (0.741, 0.702, 0.627)
        case .groutGold: (0.478, 0.341, 0.153)
        case .groutNight: (0.039, 0.055, 0.125)
        case .groutDark: (0.208, 0.165, 0.141)
        case .goldDeep: (0.690, 0.506, 0.176)
        case .goldWarm: (0.851, 0.612, 0.231)
        case .gold: (0.871, 0.690, 0.302)
        case .goldPale: (0.949, 0.827, 0.502)
        case .lapisDeep: (0.075, 0.110, 0.294)
        case .lapis: (0.122, 0.204, 0.455)
        case .lapisLight: (0.212, 0.333, 0.604)
        case .sky: (0.443, 0.592, 0.784)
        case .stoneShade: (0.871, 0.831, 0.749)
        case .stone: (0.929, 0.898, 0.831)
        case .stonePale: (0.965, 0.945, 0.898)
        case .white: (0.992, 0.984, 0.957)
        case .slate: (0.231, 0.255, 0.310)
        case .steel: (0.490, 0.565, 0.659)
        case .silver: (0.776, 0.812, 0.851)
        case .redDeep: (0.451, 0.110, 0.094)
        case .red: (0.698, 0.204, 0.153)
        case .terracotta: (0.808, 0.380, 0.243)
        case .rose: (0.894, 0.596, 0.506)
        case .greenDeep: (0.114, 0.290, 0.192)
        case .green: (0.208, 0.475, 0.290)
        case .greenPale: (0.471, 0.663, 0.384)
        case .purpleDeep: (0.243, 0.098, 0.216)
        case .purple: (0.404, 0.173, 0.333)
        case .mauve: (0.557, 0.318, 0.467)
        case .brown: (0.322, 0.196, 0.118)
        case .umber: (0.494, 0.322, 0.196)
        case .fleshShade: (0.808, 0.608, 0.478)
        case .flesh: (0.910, 0.765, 0.627)
        case .fleshPale: (0.961, 0.867, 0.757)
        case .ink: (0.110, 0.082, 0.102)
        }
    }
}

/// One colour the way a mosaicist mixes it: several close smalti, dark to light, set at
/// random. Repeating a shade weights it.
struct Smalti {
    let shades: [Smalto]

    init(_ shades: Smalto...) { self.shades = shades }

    /// The shade a flat fill stands in with.
    var main: Smalto { shades[shades.count / 2] }

    /// `light` above zero leans towards the light end, below zero towards the dark.
    func pick(_ rng: inout MosaicoRandom, light: CGFloat) -> Smalto {
        let u = min(max(rng.unit() + light, 0), 0.999)
        return shades[Int(u * CGFloat(shades.count))]
    }
}

/// SplitMix64. MosaicoRandom by the card, so a face is set the same way every time it is drawn.
struct MosaicoRandom {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 ^ 0xD1B5_4A32_D192_ED03 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0..<1.
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }

    /// Uniform in -amount...amount.
    mutating func spread(_ amount: CGFloat) -> CGFloat { (unit() * 2 - 1) * amount }
}

/// A face being set: layers of grout bed and tesserae, every tessera of one colour in one
/// path, so a card of two thousand tesserae is a few dozen fills.
struct MosaicoWork {
    struct Layer {
        var beds: [Smalto: Path] = [:]
        var tiles: [Smalto: Path] = [:]
    }

    private(set) var layers: [Layer] = [Layer()]
    var rng: MosaicoRandom
    /// False on small cards: tesserae there are only noise, so each piece is laid as flat
    /// bands of its colours instead.
    let detailed: Bool

    init(seed: UInt64, detailed: Bool) {
        rng = MosaicoRandom(seed)
        self.detailed = detailed
    }

    /// Starts a layer over everything laid so far. Pieces that overlap go in separate layers.
    mutating func layer() { layers.append(Layer()) }

    mutating func bed(_ polygon: [CGPoint], _ grout: Smalto) {
        layers[layers.count - 1].beds[grout, default: Path()].addPolygon(polygon.oriented)
    }

    /// A bed with a hole in it, for the frame.
    mutating func bedRing(outer: [CGPoint], inner: [CGPoint], _ grout: Smalto) {
        layers[layers.count - 1].beds[grout, default: Path()].addPolygon(outer.oriented)
        layers[layers.count - 1].beds[grout, default: Path()].addPolygon(inner.oriented.reversed())
    }

    /// Flat colour: a detail too fine to set, or a piece on a small card.
    mutating func solid(_ polygon: [CGPoint], _ smalto: Smalto) {
        guard polygon.count > 2 else { return }
        layers[layers.count - 1].tiles[smalto, default: Path()].addPolygon(polygon.oriented)
    }

    /// Flat colour with a hole in it, for the frame of a small card.
    mutating func solidRing(outer: [CGPoint], inner: [CGPoint], _ smalto: Smalto) {
        layers[layers.count - 1].tiles[smalto, default: Path()].addPolygon(outer.oriented)
        layers[layers.count - 1].tiles[smalto, default: Path()].addPolygon(inner.oriented.reversed())
    }

    /// One tessera: a slightly irregular square turned to the course it sits in.
    mutating func tessera(at c: CGPoint, angle: CGFloat, along: CGFloat, across: CGFloat, _ smalto: Smalto) {
        let turn = angle + rng.spread(0.09)
        let (ca, sa) = (cos(turn), sin(turn))
        let hx = along * 0.43, hy = across * 0.42
        let jitter = min(hx, hy) * 0.18
        var corners: [CGPoint] = []
        for (x, y) in [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)] {
            let jx = x + rng.spread(jitter), jy = y + rng.spread(jitter)
            corners.append(CGPoint(x: c.x + jx * ca - jy * sa, y: c.y + jx * sa + jy * ca))
        }
        layers[layers.count - 1].tiles[smalto, default: Path()].addPolygon(corners)
    }

    func draw(in context: GraphicsContext) {
        for layer in layers {
            for smalto in Smalto.allCases {
                if let path = layer.beds[smalto] { context.fill(path, with: .color(smalto.colour)) }
            }
            for smalto in Smalto.allCases {
                if let path = layer.tiles[smalto] { context.fill(path, with: .color(smalto.colour)) }
            }
        }
    }
}

extension MosaicoWork {
    /// Sets tesserae along one course, spaced to fit it exactly.
    mutating func course(_ course: MosaicoCourse, pitch: CGFloat, material: Smalti,
                         light: (CGPoint) -> CGFloat, keep: (CGPoint) -> Bool = { _ in true }) {
        var points = course.points, depths = course.depths
        if course.closed, let first = points.first {
            points.append(first)
            depths.append(depths[0])
        }
        guard points.count > 1 else {
            if let only = points.first, keep(only) { tessera(at: only, pitch: pitch, material, light: light(only)) }
            return
        }
        let lengths = points.runningLengths
        let total = lengths[lengths.count - 1]
        let count = max(1, Int((total / pitch).rounded()))
        let step = total / CGFloat(count)
        let phase = course.closed ? rng.unit() : 0.5
        var segment = 0
        for index in 0..<count {
            let distance = (CGFloat(index) + phase) * step
            while segment < points.count - 2 && lengths[segment + 1] < distance { segment += 1 }
            let a = points[segment], b = points[segment + 1]
            let span = max(lengths[segment + 1] - lengths[segment], 0.0001)
            let t = min(max((distance - lengths[segment]) / span, 0), 1)
            let at = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            guard keep(at) else { continue }
            let depth = depths[segment] + (depths[segment + 1] - depths[segment]) * t
            let shade = material.pick(&rng, light: light(at))
            tessera(at: at, angle: atan2(b.y - a.y, b.x - a.x), along: step,
                    across: min(max(depth, pitch * 0.5), pitch * 1.25), shade)
        }
    }

    /// A course that has shrunk to one point: the tessera at the heart of a disc.
    private mutating func tessera(at point: CGPoint, pitch: CGFloat, _ material: Smalti, light: CGFloat) {
        let shade = material.pick(&rng, light: light)
        tessera(at: point, angle: 0, along: pitch, across: pitch, shade)
    }

    /// Lays a whole piece: its grout bed, then course after course from the outline in.
    /// `paint` takes how far in a course runs, 0 on the outline and 1 at the core.
    mutating func lay(_ piece: MosaicoPiece, pitch: CGFloat, grout: Smalto, lit: Bool = true,
                      paint: (CGFloat) -> Smalti) {
        guard detailed else { return layFlat(piece, pitch: pitch, paint: paint) }
        bed(piece.outline(pitch * 0.12), grout)
        let box = piece.bounds
        for course in piece.courses(pitch) {
            self.course(course, pitch: pitch, material: paint(course.inward),
                        light: { lit ? MosaicoWork.light(in: box, at: $0) : 0 })
        }
    }

    /// The same piece as bands of flat colour, for a card too small to set. Each band is a
    /// ring round the next, since fills batched by colour do not keep the order they were laid.
    private mutating func layFlat(_ piece: MosaicoPiece, pitch: CGFloat, paint: (CGFloat) -> Smalti) {
        let bands = piece.bands(pitch).map { (polygon: $0.polygon, shade: paint($0.inward).main) }
        let starts = bands.indices.filter { $0 == 0 || bands[$0].shade != bands[$0 - 1].shade }
        for (order, start) in starts.enumerated() {
            if order + 1 < starts.count {
                solidRing(outer: bands[start].polygon, inner: bands[starts[order + 1]].polygon, bands[start].shade)
            } else {
                solid(bands[start].polygon, bands[start].shade)
            }
        }
    }

    /// Lit from the upper left, the way the light falls in San Vitale's apse.
    static func light(in box: CGRect, at point: CGPoint) -> CGFloat {
        let x = (point.x - box.midX) / max(box.width / 2, 1)
        let y = (point.y - box.midY) / max(box.height / 2, 1)
        return -x * 0.26 - y * 0.10
    }
}

/// A line of tesserae set side by side.
struct MosaicoCourse {
    var points: [CGPoint]
    /// How deep the course is at each point: courses crowd where a strip narrows.
    var depths: [CGFloat]
    var closed: Bool
    /// 0 on the outline, 1 at the core.
    var inward: CGFloat
}

/// A shape a mosaicist fills course by course, outermost first.
enum MosaicoPiece {
    /// An ellipse, or the part of one between two angles (a bowl). Courses run concentric.
    case oval(CGPoint, rx: CGFloat, ry: CGFloat, from: CGFloat = 0, to: CGFloat = 2 * .pi)
    /// A band along a smooth spine, `widths` across it at each control point. Courses run
    /// lengthwise, the way drapery and blades are set.
    case strip([CGPoint], widths: [CGFloat])
}

extension Path {
    mutating func addPolygon(_ points: [CGPoint]) {
        guard points.count > 2 else { return }
        addLines(points)
        closeSubpath()
    }
}

extension Array where Element == CGPoint {
    /// Wound the way every tessera is, so overlapping fills in one path never cut holes.
    var oriented: [CGPoint] {
        var area: CGFloat = 0
        for index in indices {
            let a = self[index], b = self[(index + 1) % count]
            area += a.x * b.y - b.x * a.y
        }
        return area < 0 ? reversed() : self
    }

    /// Distance along the line to each point.
    var runningLengths: [CGFloat] {
        var lengths: [CGFloat] = [0]
        for index in 1..<count {
            let a = self[index - 1], b = self[index]
            lengths.append(lengths[index - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        return lengths
    }

    func encloses(_ point: CGPoint) -> Bool {
        var inside = false
        var j = count - 1
        for i in indices {
            let a = self[i], b = self[j]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
