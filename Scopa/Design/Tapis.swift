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
    /// Panels ruled in gold and notched at the corners, a jewel where four meet. Was `bordo`.
    case campo = "bordo"
    /// Linen, powdered with cross-stitched diamonds. Was `intreccio`.
    case lino = "intreccio"
    /// Glazed tiles with a ribbon wandering through them. Was `damasco`.
    case maiolica = "damasco"
    /// Fish scales, with a deco fan open on them here and there. Was `merletto`.
    case ventaglio = "merletto"
    /// Crushed velvet, powdered with roses couched in gold. Was `broccato`.
    case velluto = "broccato"
    /// Sorrento parquet: cubes inlaid in three woods. Never sold; the Intarsio album pays it.
    case cubi

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
        case .cubi: "Cubi"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .liscio: "Bare cloth, nothing on it"
        case .campo: "Gold-ruled panels laid on the diagonal"
        case .lino: "Linen, powdered with cross-stitched diamonds"
        case .maiolica: "Glazed tiles with a ribbon running through them"
        case .ventaglio: "Deco scales, with a fan open here and there"
        case .velluto: "Velvet, powdered with roses couched in gold"
        case .cubi: "Cubes inlaid in three woods, laid all over"
        }
    }

    /// The line under the swatch in the shop.
    var explanation: LocalizedStringKey {
        switch self {
        case .liscio: "Plain felt. Let the cards do the talking"
        case .campo: "Ruled in gold, like a proper pitch"
        case .lino: "Linen, cross-stitched by a very patient aunt"
        case .maiolica: "Tiles pinched from a seaside hotel"
        case .ventaglio: "Deco fans. A spritz is recommended"
        case .velluto: "Velvet and gold roses. Little finger up"
        case .cubi: "Inlaid cubes. Don't try to climb them"
        }
    }
}

extension EnvironmentValues {
    /// Read by `TableGround`, so nothing in between has to carry it.
    @Entry var tapis: Tapis = .default
}

/// The cloth itself, drawn over a felt.
///
/// Every cloth is cut from the bolt: its repeat all over, with no hem, no border and
/// nothing set in the middle, on the table as everywhere else. A border sewn round the
/// screen read as a box drawn round the cards, and under a scrolling sheet as a box
/// under the shop. A repeat reads as cloth at any size and any crop, the way the tiles
/// always did.
///
/// One `Canvas` rather than a stack of shapes: a field of tiles is a few thousand strokes.
/// A `Canvas` draws once and holds its picture, and where the ground is rasterised it is
/// baked into that texture with the rest of it. Each cloth is drawn in its own file.
struct TapisWeave: View {
    let tapis: Tapis
    /// How far the ground runs past the screen on each side. The repeat is centred on the
    /// visible screen, not on the bleed, which is off the glass.
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
            case .campo: campo(&context, whole: whole, visible: visible)
            case .lino: lino(&context, whole: whole, visible: visible)
            case .maiolica: maiolica(&context, whole: whole, visible: visible)
            case .ventaglio: ventaglio(&context, whole: whole, visible: visible)
            case .velluto: velluto(&context, whole: whole, visible: visible)
            case .cubi: cubi(&context, whole: whole, visible: visible)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Light and line

extension TapisWeave {
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
    func offset(_ point: CGPoint, by direction: CGPoint, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: point.x + direction.x * distance, y: point.y + direction.y * distance)
    }

    /// The direction an angle, in radians, points in on screen.
    func unit(_ angle: Double) -> CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }

    /// A lozenge standing on its point, `long` from tip to tip across the screen.
    func lozenge(at centre: CGPoint, long: CGFloat, wide: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: centre.x + long / 2, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y + wide / 2))
        path.addLine(to: CGPoint(x: centre.x - long / 2, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y - wide / 2))
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

    /// Where a scattered motif falls: a column every `across`, a motif every `down` in it,
    /// each column dropped half a step from the last and one motif on the middle of the
    /// screen — the half drop a printed cloth is laid out in, so nothing lines up in stripes.
    func halfDrop(in whole: CGRect, centredOn visible: CGRect, across: CGFloat, down: CGFloat) -> [CGPoint] {
        let columns = Int(((visible.midX - whole.minX) / across).rounded(.up)) + 1
        let rows = Int(((visible.midY - whole.minY) / down).rounded(.up)) + 1
        var points: [CGPoint] = []
        for column in -columns...columns {
            let x = visible.midX + CGFloat(column) * across
            let drop = column.isMultiple(of: 2) ? 0 : down / 2
            for row in -rows...rows {
                points.append(CGPoint(x: x, y: visible.midY + drop + CGFloat(row) * down))
            }
        }
        return points
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
