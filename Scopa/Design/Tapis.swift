import SwiftUI

/// What the table is dressed in. `TableFelt` is the dye, and the two vary independently the
/// way `CardStyle` and `CardSkin` do.
///
/// A tapis is drawn only in the felt's own light — cream, gold and shadow — never in a
/// colour of its own, so every one works over every felt.
///
/// The raw values are the names of the first set of cloths, which this set replaced
/// one for one in 2026-10. They are what the purse, the ledger and the account sync
/// remember, so whoever owned or laid the old one has its successor.
///
/// Cosmetic and device-local like the felt: nothing on the wire knows it exists.
enum Tapis: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Bare cloth, and free.
    case liscio
    /// A playing field ruled in gold, notched at the corners. Was `bordo`.
    case campo = "bordo"
    /// Linen with a turned hem, a running stitch and a hemstitched ladder. Was `intreccio`.
    case lino = "intreccio"
    /// Glazed tiles with a ribbon wandering through them. Was `damasco`.
    case maiolica = "damasco"
    /// Deco fans at the corners and sides, over a field of scales. Was `merletto`.
    case ventaglio = "merletto"
    /// Velvet, piped in twisted gold cord, with a rose couched in the middle. Was `broccato`.
    case velluto = "broccato"

    static let `default` = Tapis.liscio

    var id: String { rawValue }

    /// The name, or the old one, so `-tapis` takes either.
    init?(named name: String) {
        let found = Tapis.allCases.first { $0.title.lowercased() == name.lowercased() }
        guard let tapis = found ?? Tapis(rawValue: name) else { return nil }
        self = tapis
    }

    var title: String {
        switch self {
        case .liscio: "Liscio"
        case .campo: "Campo"
        case .lino: "Lino"
        case .maiolica: "Maiolica"
        case .ventaglio: "Ventaglio"
        case .velluto: "Velluto"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .liscio: "Bare cloth, no border"
        case .campo: "A playing field ruled in gold, notched at the corners"
        case .lino: "Linen, hemmed and hemstitched"
        case .maiolica: "Glazed tiles with a ribbon running through them"
        case .ventaglio: "Deco fans round the edge, over a field of scales"
        case .velluto: "Velvet piped in gold cord, a rose couched in the middle"
        }
    }

    /// The line under the swatch in the shop.
    var explanation: LocalizedStringKey {
        switch self {
        case .liscio: "Plain felt. Let the cards do the talking"
        case .campo: "Ruled in gold, like a proper pitch"
        case .lino: "Linen, hemmed by a very patient aunt"
        case .maiolica: "Tiles pinched from a seaside hotel"
        case .ventaglio: "Deco fans. A spritz is recommended"
        case .velluto: "Velvet and gold cord. Little finger up"
        }
    }
}

extension EnvironmentValues {
    /// Read by `TableGround`, so nothing in between has to carry it.
    @Entry var tapis: Tapis = .default
}

/// The cloth itself, drawn over a felt.
///
/// One `Canvas` rather than a stack of shapes: a field of tiles is a few thousand strokes.
/// A `Canvas` draws once and holds its picture, and where the ground is rasterised it is
/// baked into that texture with the rest of it. Each cloth is drawn in its own file.
struct TapisWeave: View {
    let tapis: Tapis
    /// How far the ground runs past the screen on each side. A border is sewn round the
    /// visible edge, not round the bleed, which is off the glass.
    var bleed: CGFloat = 0
    /// Everything is drawn at this scale, so the same cloth can be a swatch. At 1 the
    /// figures are sized for a phone held at arm's length.
    var scale: CGFloat = 1
    /// The finest line drawn. A miniature asks for more, so its rules still read as gold.
    var finest: CGFloat = 0.5

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let whole = CGRect(origin: .zero, size: size)
            let visible = whole.insetBy(dx: bleed, dy: bleed)
            switch tapis {
            case .liscio: break
            case .campo: campo(&context, whole: whole, in: visible)
            case .lino: lino(&context, whole: whole, visible: visible)
            case .maiolica: maiolica(&context, whole: whole, visible: visible)
            case .ventaglio: ventaglio(&context, whole: whole, visible: visible)
            case .velluto: velluto(&context, whole: whole, visible: visible)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Light and line

extension TapisWeave {
    /// The table is lit from its top-left corner; this is the way towards the lamp.
    static let lamp = CGPoint(x: -0.6, y: -0.8)

    /// A line width at this scale, never finer than the screen can draw cleanly.
    func hair(_ width: CGFloat) -> CGFloat { max(width * scale, finest * min(width, 1.2)) }

    /// A distance at this scale.
    func pt(_ length: CGFloat) -> CGFloat { length * scale }

    /// Strokes a path as a thing raised off the cloth: its shadow cast down and away from
    /// the lamp, a catch of light on the side towards it, then the line itself.
    func raise(_ path: Path, in context: inout GraphicsContext, with shading: GraphicsContext.Shading,
               width: CGFloat, height: CGFloat = 1) {
        let drop = max(pt(0.9) * height, 0.35)
        context.stroke(path.offsetBy(dx: drop * 0.6, dy: drop),
                       with: .color(.black.opacity(0.26)), lineWidth: hair(width))
        context.stroke(path.offsetBy(dx: -drop * 0.3, dy: -drop * 0.45),
                       with: .color(Palette.cream.opacity(0.07)), lineWidth: hair(width * 0.8))
        context.stroke(path, with: shading, lineWidth: hair(width))
    }

    /// The same for a filled shape: a jewel, a bead, a tile insert.
    func raiseFill(_ path: Path, in context: inout GraphicsContext, with shading: GraphicsContext.Shading) {
        let drop = max(pt(0.9), 0.35)
        context.fill(path.offsetBy(dx: drop * 0.6, dy: drop), with: .color(.black.opacity(0.3)))
        context.fill(path, with: shading)
        context.stroke(path.offsetBy(dx: -drop * 0.25, dy: -drop * 0.35),
                       with: .color(Palette.cream.opacity(0.12)), lineWidth: hair(0.5))
    }

    /// Gold as it is under the lamp at the top left and away from it at the bottom right.
    func gilt(in rect: CGRect, _ opacity: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [Palette.goldLight.opacity(opacity),
                                          Palette.gold.opacity(opacity * 0.9),
                                          Palette.goldDeep.opacity(opacity * 0.8)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
    }

    static func cream(_ opacity: Double) -> GraphicsContext.Shading {
        .color(Palette.cream.opacity(opacity))
    }
}

// MARK: Geometry

extension TapisWeave {
    func roundedPath(_ rect: CGRect, radius: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: max(0, min(radius, min(rect.width, rect.height) / 2)),
             style: .circular)
    }

    func offset(_ point: CGPoint, by direction: CGPoint, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: point.x + direction.x * distance, y: point.y + direction.y * distance)
    }

    /// The direction an angle, in radians, points in on screen.
    func unit(_ angle: Double) -> CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }

    /// A lozenge standing on its point, `long` from tip to tip along `axis`.
    func lozenge(at centre: CGPoint, long: CGFloat, wide: CGFloat, axis: CGPoint = CGPoint(x: 1, y: 0)) -> Path {
        let across = CGPoint(x: -axis.y, y: axis.x)
        var path = Path()
        path.move(to: offset(centre, by: axis, long / 2))
        path.addLine(to: offset(centre, by: across, wide / 2))
        path.addLine(to: offset(centre, by: axis, -long / 2))
        path.addLine(to: offset(centre, by: across, -wide / 2))
        path.closeSubpath()
        return path
    }

    /// A leaf pointed at both ends, from `start` to `end`, bellied `width` either side.
    func leaf(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let length = max(hypot(end.x - start.x, end.y - start.y), 0.001)
        let across = CGPoint(x: -(end.y - start.y) / length, y: (end.x - start.x) / length)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: offset(middle, by: across, width))
        path.addQuadCurve(to: start, control: offset(middle, by: across, -width))
        path.closeSubpath()
        return path
    }

    func disc(at centre: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                               width: radius * 2, height: radius * 2))
    }
}

/// Xorshift, so a cloth with a random hand in it is the same cloth every redraw.
struct TapisDice: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func unit() -> CGFloat { CGFloat.random(in: 0..<1, using: &self) }
}
