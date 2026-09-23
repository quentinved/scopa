import SwiftUI

/// The weave of the cloth. `TableFelt` is the dye, and the two vary independently the way
/// `CardStyle` and `CardSkin` do.
///
/// A tapis is drawn only in the felt's own light, never in a colour of its own, so every
/// weave works over every felt. Everything here is cream or gold at a low opacity.
///
/// Cosmetic and device-local like the felt: nothing on the wire knows it exists.
enum Tapis: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Bare cloth, and free.
    case liscio
    /// A stitched double border with a tick at each corner.
    case bordo
    /// A damask lattice of small diamonds, woven across the whole cloth.
    case damasco
    /// Basket weave: over, under, over.
    case intreccio
    /// A deep lace band round the edge, scalloped, over a field of eyelets.
    case merletto
    /// An ogival brocade, shot with gold thread that catches the light.
    case broccato

    static let `default` = Tapis.liscio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liscio: "Liscio"
        case .bordo: "Bordo"
        case .damasco: "Damasco"
        case .intreccio: "Intreccio"
        case .merletto: "Merletto"
        case .broccato: "Broccato"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .liscio: "Bare cloth, no border"
        case .bordo: "A stitched double border"
        case .damasco: "A damask lattice, woven through"
        case .intreccio: "Basket weave, over and under"
        case .merletto: "A netted lace band, scalloped, over a field of eyelets"
        case .broccato: "Brocade, an ogival lattice shot with gold"
        }
    }

    /// The line under the swatch in the shop.
    var explanation: LocalizedStringKey {
        switch self {
        case .liscio: "The table as it comes"
        case .bordo: "Sewn round the edge"
        case .damasco: "Figured all the way across"
        case .intreccio: "Rush, over and under"
        case .merletto: "The good cloth, for company"
        case .broccato: "Silk, shot with gold thread"
        }
    }
}

extension EnvironmentValues {
    /// Read by `TableGround`, so nothing in between has to carry it.
    @Entry var tapis: Tapis = .default
}

/// The weave itself, drawn over a felt.
///
/// One `Canvas` rather than a stack of shapes: a lattice is a few hundred strokes. A
/// `Canvas` draws once and holds its picture, and where the ground is rasterised it is
/// baked into that texture with the rest of it.
struct TapisWeave: View {
    let tapis: Tapis
    /// How far the ground runs past the screen on each side. A border is sewn round the
    /// visible edge, not round the bleed, which is off the glass.
    var bleed: CGFloat = 0
    /// Everything is drawn at this scale, so the same weave can be a swatch. At 1 the
    /// figures are sized for a phone held at arm's length.
    var scale: CGFloat = 1

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let visible = CGRect(x: bleed, y: bleed,
                                 width: size.width - bleed * 2, height: size.height - bleed * 2)
            switch tapis {
            case .liscio: break
            case .bordo: bordo(&context, in: visible)
            case .damasco: damasco(&context, in: CGRect(origin: .zero, size: size))
            case .intreccio: intreccio(&context, in: CGRect(origin: .zero, size: size))
            case .merletto: merletto(&context, in: visible)
            case .broccato: broccato(&context, in: CGRect(origin: .zero, size: size))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: The colours a cloth is allowed

    /// Thread caught by the light. Cream rather than white, to match the cards.
    private var thread: Color { Palette.cream.opacity(0.11) }
    /// The shadow the thread casts, which stops a border reading as a sticker on the felt.
    private var shade: Color { Color.black.opacity(0.13) }
    /// The one gold in here, and only ever a hairline of it.
    private var gilt: Color { Palette.gold.opacity(0.34) }

    // MARK: Bordo

    /// Two rounded rectangles a finger apart, with a tick across each corner. The outer
    /// line is gold and the inner thread, so the pair reads as piping over a hem.
    private func bordo(_ context: inout GraphicsContext, in rect: CGRect) {
        let inset = 22 * scale
        let gap = 7 * scale
        let outer = rect.insetBy(dx: inset, dy: inset)
        let inner = outer.insetBy(dx: gap, dy: gap)
        let radius = 26 * scale

        context.stroke(roundedPath(outer, radius: radius), with: .color(gilt), lineWidth: 1.6 * scale)
        context.stroke(roundedPath(outer.offsetBy(dx: 0, dy: 1 * scale), radius: radius),
                       with: .color(shade), lineWidth: 1 * scale)
        context.stroke(roundedPath(inner, radius: radius - gap), with: .color(thread), lineWidth: 1 * scale)

        // A bar tack across each corner, on the diagonal.
        let arm = 9 * scale
        for corner in corners(of: inner) {
            var tack = Path()
            let sign = CGPoint(x: corner.x < inner.midX ? 1 : -1, y: corner.y < inner.midY ? 1 : -1)
            tack.move(to: CGPoint(x: corner.x + arm * sign.x, y: corner.y))
            tack.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * sign.y))
            context.stroke(tack, with: .color(gilt), lineWidth: 1.4 * scale)
        }
    }

    // MARK: Damasco

    /// A diamond lattice on the diagonal, with a four-petal figure at every crossing.
    private func damasco(_ context: inout GraphicsContext, in rect: CGRect) {
        let pitch = 46 * scale
        context.stroke(damascoLattice(in: rect, pitch: pitch),
                       with: .color(thread.opacity(0.55)), lineWidth: 1 * scale)
        context.fill(damascoFigures(in: rect, pitch: pitch), with: .color(thread.opacity(0.5)))
    }

    /// Two families of parallel lines rather than a grid of diamonds: half the path for
    /// the same picture.
    private func damascoLattice(in rect: CGRect, pitch: CGFloat) -> Path {
        var lattice = Path()
        // Enough lines to cross the rectangle both ways once it is turned 45 degrees.
        let span = rect.width + rect.height
        var offset = -rect.height
        while offset < span {
            lattice.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            lattice.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.maxY))
            lattice.move(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            lattice.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            offset += pitch
        }
        return lattice
    }

    /// A four-petal quatrefoil in the middle of each diamond.
    private func damascoFigures(in rect: CGRect, pitch: CGFloat) -> Path {
        let petal = 5.5 * scale
        var figures = Path()
        var y = rect.minY
        var row = 0
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : pitch / 2)
            while x < rect.maxX {
                for angle in stride(from: 0.0, to: 360.0, by: 90.0) {
                    let radians = angle * .pi / 180
                    figures.addEllipse(in: CGRect(x: x + cos(radians) * petal - petal * 0.55,
                                                  y: y + sin(radians) * petal - petal * 0.55,
                                                  width: petal * 1.1, height: petal * 1.1))
                }
                x += pitch
            }
            y += pitch / 2
            row += 1
        }
        return figures
    }

    // MARK: Intreccio

    /// Over, under, over. Alternate cells carry a stroke lying the other way, and the
    /// shadow under each horizontal reed is what makes the crossing read.
    private func intreccio(_ context: inout GraphicsContext, in rect: CGRect) {
        let (horizontal, vertical, shadows) = reeds(in: rect)
        context.stroke(shadows, with: .color(shade.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
        context.stroke(horizontal, with: .color(thread),
                       style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
        context.stroke(vertical, with: .color(thread.opacity(0.75)),
                       style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
    }

    /// The three paths a basket weave is stroked from: the reeds lying each way, and the
    /// shadows under the horizontal ones.
    private func reeds(in rect: CGRect) -> (horizontal: Path, vertical: Path, shadows: Path) {
        let cell = 26 * scale
        let reed = cell * 0.62
        var horizontal = Path()
        var vertical = Path()
        var shadows = Path()

        var row = 0
        var y = rect.minY
        while y < rect.maxY {
            var column = 0
            var x = rect.minX
            while x < rect.maxX {
                let centre = CGPoint(x: x + cell / 2, y: y + cell / 2)
                if (row + column).isMultiple(of: 2) {
                    horizontal.move(to: CGPoint(x: centre.x - reed / 2, y: centre.y))
                    horizontal.addLine(to: CGPoint(x: centre.x + reed / 2, y: centre.y))
                    shadows.move(to: CGPoint(x: centre.x - reed / 2, y: centre.y + 1.5 * scale))
                    shadows.addLine(to: CGPoint(x: centre.x + reed / 2, y: centre.y + 1.5 * scale))
                } else {
                    vertical.move(to: CGPoint(x: centre.x, y: centre.y - reed / 2))
                    vertical.addLine(to: CGPoint(x: centre.x, y: centre.y + reed / 2))
                }
                x += cell
                column += 1
            }
            y += cell
            row += 1
        }
        return (horizontal, vertical, shadows)
    }

    // MARK: Merletto

    /// Lace, the way a cloth carries it: a deep band round the edge worked over a net
    /// ground, a chain of little stars along it, a scalloped free edge hanging inward off
    /// the net with a picot in every notch, and a field of eyelets over the rest.
    ///
    /// The band is what this used to be on its own, and on its own it was not enough. One
    /// row of scallops at the very edge of a phone is a hairline, and most of that hairline
    /// is behind the score chips, the hand and the coach's line — so the cloth that costs
    /// more than the damask showed less of itself than the damask does, which is the wrong
    /// way round. The band is now four fingers deep and worked through, and the eyelets
    /// carry the cloth into the middle of the table, where there was nothing at all.
    ///
    /// The edge is a rounded rectangle rather than a square one: a square corner this near
    /// the glass is cut off by the corner of the screen.
    private func merletto(_ context: inout GraphicsContext, in rect: CGRect) {
        let inset = 16 * scale
        let depth = 42 * scale
        let edge = rect.insetBy(dx: inset, dy: inset)
        let radius = min(54 * scale, min(edge.width, edge.height) / 2)
        let inner = edge.insetBy(dx: depth, dy: depth)
        guard inner.width > 0, inner.height > 0 else { return }
        let innerRadius = min(max(radius - depth, 8 * scale), min(inner.width, inner.height) / 2)

        let hem = roundedPath(edge, radius: radius)
        let free = roundedPath(inner, radius: innerRadius)

        // The net the band is worked over. Clipped to the band rather than drawn side by
        // side four times, which is what makes the corners turn: a mitre I do not have to
        // draw is a mitre that cannot be wrong.
        var ring = hem
        ring.addPath(free)
        var band = context
        band.clip(to: ring, style: FillStyle(eoFill: true))
        band.stroke(damascoLattice(in: rect, pitch: 11 * scale),
                    with: .color(thread.opacity(0.34)), lineWidth: 0.7 * scale)

        // The hem: gold on the outside, a thread of cream inside it, a shadow under both.
        context.stroke(hem.offsetBy(dx: 0, dy: 1 * scale), with: .color(shade), lineWidth: 1 * scale)
        context.stroke(hem, with: .color(gilt), lineWidth: 1.5 * scale)
        context.stroke(roundedPath(edge.insetBy(dx: 4 * scale, dy: 4 * scale),
                                   radius: max(radius - 4 * scale, 0)),
                       with: .color(thread.opacity(0.7)), lineWidth: 0.8 * scale)

        // The chain of stars worked into the band, halfway between hem and free edge.
        let chain = edge.insetBy(dx: depth / 2, dy: depth / 2)
        var stars = Path()
        var hearts = Path()
        for stitch in walk(chain, radius: max(radius - depth / 2, 6 * scale), step: 44 * scale) {
            stars.addPath(laceStar(at: stitch.point, reach: 6.5 * scale, points: 8))
            let heart = 1.1 * scale
            hearts.addEllipse(in: CGRect(x: stitch.point.x - heart, y: stitch.point.y - heart,
                                         width: heart * 2, height: heart * 2))
        }
        context.stroke(stars, with: .color(thread), lineWidth: 1 * scale)
        context.fill(hearts, with: .color(gilt))

        // The free edge. Two stitches to a scallop: the even ones are the notches the
        // scallops hang between, the odd ones are the middle of each scallop.
        let step = 19 * scale
        var scallops = Path()
        var shadows = Path()
        var eyelets = Path()
        var picots = Path()
        let stitches = walk(inner, radius: innerRadius, step: step / 2)
        for (index, stitch) in stitches.enumerated() {
            guard !index.isMultiple(of: 2) else {
                // The picot sits in the notch where two scallops meet, on the line itself.
                let picot = 1.6 * scale
                picots.addEllipse(in: CGRect(x: stitch.point.x - picot, y: stitch.point.y - picot,
                                             width: picot * 2, height: picot * 2))
                continue
            }
            let belly = step / 2
            scallops.addPath(scallop(at: stitch.point, along: stitch.along,
                                     inward: stitch.inward, radius: belly))
            shadows.addPath(scallop(at: offset(stitch.point, by: stitch.inward, 1.3 * scale),
                                    along: stitch.along, inward: stitch.inward, radius: belly))
            // The eye of the scallop, punched out well short of its floor.
            let eye = offset(stitch.point, by: stitch.inward, belly * 0.5)
            let hole = belly * 0.22
            eyelets.addEllipse(in: CGRect(x: eye.x - hole, y: eye.y - hole,
                                          width: hole * 2, height: hole * 2))
        }

        context.stroke(shadows, with: .color(shade.opacity(0.65)), lineWidth: 1.5 * scale)
        // Twice over: a soft wide pass is the cordonnet, the thick thread a needle lace is
        // finished with, and the fine one on top of it is the edge itself.
        context.stroke(scallops, with: .color(thread.opacity(0.5)), lineWidth: 2.4 * scale)
        context.stroke(scallops, with: .color(thread.opacity(0.95)), lineWidth: 1.2 * scale)
        context.stroke(eyelets, with: .color(thread.opacity(0.7)), lineWidth: 0.9 * scale)
        context.fill(picots, with: .color(gilt))

        // The field: single eyelets, far enough apart to be a sprinkling rather than a
        // weave. The damask fills a table; this one is meant to have air in it.
        var middle = context
        middle.clip(to: free)
        middle.stroke(eyeletField(in: rect, pitch: 104 * scale),
                      with: .color(thread.opacity(0.95)), lineWidth: 0.9 * scale)
    }

    /// The eyelets sprinkled over the middle of the cloth, on a half-dropped grid so they
    /// do not line up into rows and columns.
    private func eyeletField(in rect: CGRect, pitch: CGFloat) -> Path {
        var field = Path()
        var row = 0
        var y = rect.minY
        while y < rect.maxY + pitch {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : pitch / 2)
            while x < rect.maxX + pitch {
                field.addPath(eyelet(at: CGPoint(x: x, y: y), reach: 9 * scale))
                x += pitch
            }
            y += pitch / 2
            row += 1
        }
        return field
    }

    /// A star worked into the band: narrow points round a small ring, which is the figure
    /// a needle lace fills a band with.
    private func laceStar(at centre: CGPoint, reach: CGFloat, points: Int) -> Path {
        var path = Path()
        for index in 0..<points {
            path.addPath(petal(from: centre, angle: Double(index) * 2 * .pi / Double(points),
                               length: reach, width: reach * 0.24))
        }
        let ring = reach * 0.24
        path.addEllipse(in: CGRect(x: centre.x - ring, y: centre.y - ring,
                                   width: ring * 2, height: ring * 2))
        return path
    }

    /// An eyelet: a hole with its ring of stitches, and four petals lying flat around it.
    ///
    /// Not the star the band is worked with, shrunk. Four narrow points is a sparkle —
    /// the glyph, twinkling over the table — and a sprinkling of those is a screensaver,
    /// not a cloth. A ring with something round it is a hole worked into linen.
    private func eyelet(at centre: CGPoint, reach: CGFloat) -> Path {
        var path = Path()
        for index in 0..<4 {
            path.addPath(petal(from: offset(centre, by: unit(Double(index) * .pi / 2), reach * 0.3),
                               angle: Double(index) * .pi / 2,
                               length: reach * 0.7, width: reach * 0.42))
        }
        let ring = reach * 0.3
        path.addEllipse(in: CGRect(x: centre.x - ring, y: centre.y - ring,
                                   width: ring * 2, height: ring * 2))
        return path
    }

    /// The direction an angle points in.
    private func unit(_ angle: Double) -> CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }

    /// One scallop: a half circle hanging off the hem and bulging into the cloth.
    ///
    /// Two quarter-circle cubics rather than a sampled polyline, so a scallop is four
    /// points however large the table is and the curve stays a curve on an iPad.
    private func scallop(at centre: CGPoint, along: CGPoint, inward: CGPoint,
                         radius: CGFloat) -> Path {
        // The usual circular-arc constant: a quarter circle is a cubic whose handles run
        // this far along the tangent at each end.
        let handle = 0.552_284_749_8 * radius
        let start = offset(centre, by: along, -radius)
        let deep = offset(centre, by: inward, radius)
        let end = offset(centre, by: along, radius)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: deep,
                      control1: offset(start, by: inward, handle),
                      control2: offset(deep, by: along, -handle))
        path.addCurve(to: end,
                      control1: offset(deep, by: along, handle),
                      control2: offset(end, by: inward, handle))
        return path
    }

    private func offset(_ point: CGPoint, by direction: CGPoint, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: point.x + direction.x * distance, y: point.y + direction.y * distance)
    }

    // MARK: Broccato

    /// Brocade: stems running the height of the cloth in a slow wave, every other one half
    /// a wave out of step so each pair closes a pointed frame between them, with a fruit
    /// in one frame and a rosette in the next and a knot wherever two stems cross.
    ///
    /// The stems are continuous rather than a frame repeated. A field of separate figures
    /// is a tile; one stem drawn from one edge of the cloth to the other, sharing its
    /// flanks with the frames on both sides, is a weave, and that is the difference
    /// between this and the damask.
    ///
    /// It is also the only cloth drawn in a gradient rather than a flat colour, which is
    /// what a brocade is — metal thread laid into silk flares where the light crosses it
    /// and goes to almost nothing where it does not. The table is lit from its top-left
    /// corner, so the sheen is laid the same way: gold under the lamp, a watermark at the
    /// far corner. Flat gold would be a pattern printed on a cloth; this is woven into it.
    ///
    /// Nine passes, against the lace's four and the damask's two: the relief under
    /// everything, the stems, the bracts, the body of each fruit, its outline, its scales,
    /// its heart, the rosettes between, and the knots.
    private func broccato(_ context: inout GraphicsContext, in rect: CGRect) {
        // A large repeat: a brocade is a figure read from across the table, not a texture.
        // Three and a half frames across a phone, against the damask's nine.
        let pitch = 54 * scale
        let period = 136 * scale
        let field = brocade(in: rect, pitch: pitch, period: period)
        let silk = sheen(in: rect, [Palette.cream.opacity(0.22),
                                    Palette.cream.opacity(0.12),
                                    Palette.cream.opacity(0.05)])
        let gold = sheen(in: rect, [Palette.goldLight.opacity(0.52),
                                    Palette.gold.opacity(0.29),
                                    Palette.goldDeep.opacity(0.13)])
        // The same gold laid flat rather than as a hairline, at a fifth of the weight: a
        // filled fruit covers a hundred times the pixels its outline does, and at the
        // hairline's opacity the field would read as a wall of tiles.
        let wash = sheen(in: rect, [Palette.goldLight.opacity(0.13),
                                    Palette.gold.opacity(0.07),
                                    Palette.goldDeep.opacity(0.03)])

        // One offset copy of everything with an edge, in the dark, under the lot: the
        // thread stands off the silk, and without this the field is ink on the felt.
        context.stroke(field.relief.offsetBy(dx: 0.8 * scale, dy: 1.2 * scale),
                       with: .color(shade.opacity(0.7)), lineWidth: 1.4 * scale)
        context.stroke(field.stems, with: silk,
                       style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round))
        context.stroke(field.bracts, with: silk,
                       style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round))
        context.fill(field.petals, with: wash)
        context.stroke(field.petals, with: gold, lineWidth: 1.2 * scale)
        context.stroke(field.scales, with: gold, lineWidth: 0.9 * scale)
        context.fill(field.hearts, with: gold)
        context.stroke(field.rosettes, with: silk,
                       style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round))
        context.fill(field.knots, with: gold)
    }

    /// Every path a brocade is stroked or filled from, so the whole field is one walk
    /// rather than one walk per pass.
    private struct Brocade {
        /// The stems, which are the lattice.
        var stems = Path()
        /// Everything with an edge, copied once more to be cast in shadow underneath.
        var relief = Path()
        /// The body of the fruit and its crown.
        var petals = Path()
        /// The rows of scales across it, drawn finer than its outline.
        var scales = Path()
        /// The two leaves it springs from.
        var bracts = Path()
        var hearts = Path()
        var rosettes = Path()
        var knots = Path()
    }

    /// The field, a stem and the frames to the right of it at a time.
    ///
    /// Every stem is the same wave; the odd ones start half a period along. Two stems that
    /// far apart touch once a period and bow a full pitch apart between, which is the
    /// pointed frame, and the frames either side of a stem are half a period out of step
    /// with each other — the half-drop that keeps the cloth from reading as a grid.
    private func brocade(in rect: CGRect, pitch: CGFloat, period: CGFloat) -> Brocade {
        var field = Brocade()
        // Started a frame outside the rectangle on every side: a figure cut off by the edge
        // of the cloth is what a bolt of brocade looks like, a figure that stops short of
        // it is what a sticker looks like.
        let top = rect.minY - period
        let bottom = rect.maxY + period
        var column = 0
        var x = rect.minX - pitch * 2
        while x < rect.maxX + pitch * 2 {
            let dropped = !column.isMultiple(of: 2)
            let wave = stem(at: x, from: top, to: bottom, pitch: pitch, period: period,
                            dropped: dropped)
            field.stems.addPath(wave)
            field.relief.addPath(wave)

            // Where this stem crosses the one to its right, and so where the frame between
            // them begins and ends.
            let centre = x + pitch / 2
            var cross = top + (dropped ? period / 2 : 0)
            var row = 0
            while cross < bottom {
                field.knots.addPath(knot(at: CGPoint(x: centre, y: cross), reach: 4 * scale))
                let middle = CGPoint(x: centre, y: cross + period / 2)
                if (column + row).isMultiple(of: 2) {
                    pomegranate(at: middle, pitch: pitch, period: period, into: &field)
                } else {
                    rosette(at: middle, pitch: pitch, into: &field)
                }
                cross += period
                row += 1
            }
            x += pitch
            column += 1
        }
        return field
    }

    /// One stem: a wave of the cloth's own period, run the whole height of it.
    ///
    /// Each half period is a single cubic with a flat tangent at both ends, which is a
    /// cosine to within a hairline and joins the next one smoothly without a join to
    /// compute. A sampled polyline would show its corners on an iPad.
    private func stem(at x: CGFloat, from top: CGFloat, to bottom: CGFloat,
                      pitch: CGFloat, period: CGFloat, dropped: Bool) -> Path {
        let amplitude = pitch / 2
        let half = period / 2
        var side: CGFloat = dropped ? -1 : 1
        var y = top
        var path = Path()
        path.move(to: CGPoint(x: x + amplitude * side, y: y))
        while y < bottom {
            path.addCurve(to: CGPoint(x: x - amplitude * side, y: y + half),
                          control1: CGPoint(x: x + amplitude * side, y: y + half * 0.36),
                          control2: CGPoint(x: x - amplitude * side, y: y + half * 0.64))
            y += half
            side = -side
        }
        return path
    }

    /// The figure in the frame: a pomegranate, scaled like a cone, crowned with three
    /// short petals and sitting on two bracts.
    ///
    /// The fruit, and not the fan of narrow leaflets this was first drawn as: five pointed
    /// leaflets spread off a stem is a hemp leaf, whatever an Italian weaver meant by it,
    /// and a card table is not the place to find that out. A closed body under a crown too
    /// short to read as leaves cannot be taken for one, and it is the older figure anyway.
    private func pomegranate(at centre: CGPoint, pitch: CGFloat, period: CGFloat,
                             into field: inout Brocade) {
        let height = period * 0.4
        let wide = pitch * 0.42
        let tip = CGPoint(x: centre.x, y: centre.y - height * 0.42)
        let foot = CGPoint(x: centre.x, y: centre.y + height * 0.5)

        // The body, a half at a time, each half left open so a fill closes it down the
        // axis the two of them share and the pair fills as one fruit.
        var body = Path()
        for side in [CGFloat(-1), 1] {
            body.move(to: tip)
            body.addCurve(to: CGPoint(x: centre.x + wide * side, y: centre.y + height * 0.02),
                          control1: CGPoint(x: centre.x + wide * 0.6 * side, y: centre.y - height * 0.34),
                          control2: CGPoint(x: centre.x + wide * side, y: centre.y - height * 0.18))
            body.addCurve(to: foot,
                          control1: CGPoint(x: centre.x + wide * side, y: centre.y + height * 0.3),
                          control2: CGPoint(x: centre.x + wide * 0.56 * side, y: centre.y + height * 0.5))
        }
        field.petals.addPath(body)
        field.relief.addPath(body)

        // Three rows of scales across the belly, each as wide as the fruit is where it
        // crosses it. This is the pass that makes a fruit of what is otherwise a bead.
        for (down, span) in [(-0.06, 0.9), (0.14, 0.78), (0.32, 0.5)] {
            let y = centre.y + height * down
            let half = wide * span
            field.scales.move(to: CGPoint(x: centre.x - half, y: y))
            field.scales.addQuadCurve(to: CGPoint(x: centre.x + half, y: y),
                                      control: CGPoint(x: centre.x, y: y + height * 0.14))
        }

        // The calyx: three petals, short and wide enough that the crown reads as a crown.
        for (degrees, reach) in [(-90.0, 1.0), (-46.0, 0.78), (-134.0, 0.78)] {
            let leaf = petal(from: tip, angle: degrees * .pi / 180,
                             length: height * 0.22 * reach, width: height * 0.09)
            field.petals.addPath(leaf)
            field.relief.addPath(leaf)
        }

        // The bracts: two leaves falling away from the foot, which is what sits the fruit
        // on the stem instead of floating it in the frame.
        for degrees in [28.0, 152.0] {
            let leaf = petal(from: foot, angle: degrees * .pi / 180,
                             length: pitch * 0.46, width: pitch * 0.1)
            field.bracts.addPath(leaf)
            field.relief.addPath(leaf)
        }
        field.hearts.addPath(knot(at: foot, reach: height * 0.1))
    }

    /// The figure in the other frame: six petals round a hub, and small, because its whole
    /// job is to be the quiet one between two pomegranates.
    private func rosette(at centre: CGPoint, pitch: CGFloat, into field: inout Brocade) {
        let reach = pitch * 0.3
        for index in 0..<6 {
            let radians = Double(index) * .pi / 3
            let leaf = petal(from: centre, angle: radians, length: reach, width: reach * 0.3)
            field.rosettes.addPath(leaf)
            field.relief.addPath(leaf)
        }
        let hub = reach * 0.22
        field.hearts.addEllipse(in: CGRect(x: centre.x - hub, y: centre.y - hub,
                                           width: hub * 2, height: hub * 2))
    }

    /// One petal: out to a point and back, bellied either side of its own axis.
    private func petal(from hub: CGPoint, angle: Double, length: CGFloat, width: CGFloat) -> Path {
        let along = CGPoint(x: cos(angle), y: sin(angle))
        let across = CGPoint(x: -along.y, y: along.x)
        let tip = offset(hub, by: along, length)
        let waist = offset(hub, by: along, length * 0.42)
        var path = Path()
        path.move(to: hub)
        path.addQuadCurve(to: tip, control: offset(waist, by: across, width))
        path.addQuadCurve(to: hub, control: offset(waist, by: across, -width))
        return path
    }

    /// The knot two stems are tied with: a four-pointed star with hollow flanks.
    private func knot(at point: CGPoint, reach: CGFloat) -> Path {
        let waist = reach * 0.3
        var path = Path()
        path.move(to: CGPoint(x: point.x, y: point.y - reach))
        path.addQuadCurve(to: CGPoint(x: point.x + reach, y: point.y),
                          control: CGPoint(x: point.x + waist, y: point.y - waist))
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y + reach),
                          control: CGPoint(x: point.x + waist, y: point.y + waist))
        path.addQuadCurve(to: CGPoint(x: point.x - reach, y: point.y),
                          control: CGPoint(x: point.x - waist, y: point.y + waist))
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - reach),
                          control: CGPoint(x: point.x - waist, y: point.y - waist))
        path.closeSubpath()
        return path
    }

    /// A thread lit from the corner the table is lit from, given as the colours it passes
    /// through on the way across the cloth.
    private func sheen(in rect: CGRect, _ colours: [Color]) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colours),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
    }

    // MARK: Geometry

    private func roundedPath(_ rect: CGRect, radius: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: max(0, radius), style: .continuous)
    }

    private func corners(of rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
    }

    /// Where a stitch falls while walking the edge of the cloth: the point itself, the way
    /// the edge runs there, and the way into the middle.
    private struct Stitch {
        var point: CGPoint
        var along: CGPoint
        var inward: CGPoint
    }

    /// One leg of a rounded rectangle: a straight run, or a quarter turn at a corner.
    private enum Leg {
        case run(from: CGPoint, along: CGPoint, length: CGFloat)
        case turn(centre: CGPoint, radius: CGFloat, from: Double)

        var length: CGFloat {
            switch self {
            case .run(_, _, let length): length
            case .turn(_, let radius, _): radius * .pi / 2
            }
        }

        /// The stitch that far along this leg. Walking clockwise on a screen, the way into
        /// the cloth is the direction of travel turned a quarter turn.
        func stitch(at distance: CGFloat) -> Stitch {
            switch self {
            case .run(let from, let along, _):
                return Stitch(point: CGPoint(x: from.x + along.x * distance, y: from.y + along.y * distance),
                              along: along, inward: CGPoint(x: -along.y, y: along.x))
            case .turn(let centre, let radius, let from):
                let angle = from + Double(distance / radius)
                let out = CGPoint(x: cos(angle), y: sin(angle))
                return Stitch(point: CGPoint(x: centre.x + out.x * radius, y: centre.y + out.y * radius),
                              along: CGPoint(x: -out.y, y: out.x),
                              inward: CGPoint(x: -out.x, y: -out.y))
            }
        }
    }

    /// Stitches laid round a rounded rectangle, as evenly as its perimeter allows.
    ///
    /// The spacing asked for is rounded to a whole number of stitches, because a chain of
    /// scallops that does not meet where it began is the one fault the eye finds straight
    /// away, and the count is made even because the callers work in pairs.
    private func walk(_ rect: CGRect, radius: CGFloat, step: CGFloat) -> [Stitch] {
        let radius = max(0, min(radius, min(rect.width, rect.height) / 2))
        let across = rect.width - radius * 2
        let down = rect.height - radius * 2
        let perimeter = (across + down) * 2 + 2 * .pi * radius
        guard perimeter > 0, step > 0 else { return [] }
        var count = max(8, Int((perimeter / step).rounded()))
        if !count.isMultiple(of: 2) { count += 1 }

        // Clockwise from the top left corner, the eight legs of a rounded rectangle.
        let legs: [Leg] = [
            .run(from: CGPoint(x: rect.minX + radius, y: rect.minY), along: CGPoint(x: 1, y: 0), length: across),
            .turn(centre: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, from: -.pi / 2),
            .run(from: CGPoint(x: rect.maxX, y: rect.minY + radius), along: CGPoint(x: 0, y: 1), length: down),
            .turn(centre: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, from: 0),
            .run(from: CGPoint(x: rect.maxX - radius, y: rect.maxY), along: CGPoint(x: -1, y: 0), length: across),
            .turn(centre: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, from: .pi / 2),
            .run(from: CGPoint(x: rect.minX, y: rect.maxY - radius), along: CGPoint(x: 0, y: -1), length: down),
            .turn(centre: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, from: .pi),
        ]

        let spacing = perimeter / CGFloat(count)
        var stitches: [Stitch] = []
        stitches.reserveCapacity(count)
        var leg = 0
        var travelled: CGFloat = 0
        for index in 0..<count {
            let distance = CGFloat(index) * spacing
            while leg < legs.count - 1, distance > travelled + legs[leg].length {
                travelled += legs[leg].length
                leg += 1
            }
            stitches.append(legs[leg].stitch(at: distance - travelled))
        }
        return stitches
    }
}
