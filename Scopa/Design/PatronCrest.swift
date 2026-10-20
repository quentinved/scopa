import SwiftUI

/// The colours of the patron's things: lapis gone to night, and gold leaf.
///
/// Written out rather than taken from `Palette`, like `IconArtwork`'s, so this file compiles
/// on its own for `Tools/render-icon.sh`, which strikes the crest on the patron's icon.
nonisolated enum PatronTone {
    static let night = Color(red: 0.020, green: 0.031, blue: 0.094)
    static let lapisDeep = Color(red: 0.055, green: 0.086, blue: 0.247)
    static let lapis = Color(red: 0.118, green: 0.192, blue: 0.443)
    static let lapisLight = Color(red: 0.231, green: 0.345, blue: 0.659)

    static let goldShadow = Color(red: 0.373, green: 0.243, blue: 0.055)
    static let goldDeep = Color(red: 0.604, green: 0.424, blue: 0.122)
    static let gold = Color(red: 0.851, green: 0.643, blue: 0.267)
    static let goldLight = Color(red: 0.949, green: 0.800, blue: 0.420)
    static let goldPale = Color(red: 0.984, green: 0.902, blue: 0.635)

    static let terracotta = Color(red: 0.835, green: 0.392, blue: 0.267)
    static let terracottaDeep = Color(red: 0.545, green: 0.188, blue: 0.122)
}

/// The patron's crest: the mark the no-ads purchase gives. A gold medallion inside a row of
/// pearls, a twisted band engraved round it, and a lapis field set with Ravenna's gold stars,
/// the house broom laid across it.
///
/// One Canvas, so it is one layer wherever it sits and nothing in it moves.
struct PatronCrest: View {
    var size: CGFloat
    /// The shadow it drops. Off where whatever holds it lays its own.
    var casts = true

    var body: some View {
        Canvas { context, canvas in
            let side = min(canvas.width, canvas.height)
            CrestEngraving(unit: side / 100, detailed: size >= 40)
                .strike(in: &context, at: CGPoint(x: canvas.width / 2, y: canvas.height / 2))
        }
        .frame(width: size, height: size)
        .shadow(color: casts ? PatronTone.night.opacity(0.55) : .clear, radius: size * 0.045, y: size * 0.03)
        .accessibilityHidden(true)
    }
}

/// The crest's drawing, measured on a medallion 100 units across.
nonisolated struct CrestEngraving {
    let unit: CGFloat
    /// Pearls, twist and the field's beading only where there is room to see them.
    let detailed: Bool

    private var u: CGFloat { unit }

    func strike(in context: inout GraphicsContext, at c: CGPoint) {
        mount(&context, c)
        pearls(&context, c)
        disc(&context, c)
        band(&context, c)
        field(&context, c)
        stars(&context, c)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: PatronTone.night.opacity(0.6), radius: 1.1 * u, x: 0.7 * u, y: 1.3 * u))
            broom(&layer, c)
            PatronStar.strike(in: &layer, at: CGPoint(x: c.x - 14 * u, y: c.y - 14 * u), radius: 8.4 * u)
        }
    }

    // MARK: The metal

    /// The dark ring the pearls are set in.
    private func mount(_ context: inout GraphicsContext, _ c: CGPoint) {
        context.fill(Self.circle(c, 49.6 * u), with: .linearGradient(
            Gradient(colors: [PatronTone.goldDeep, PatronTone.goldShadow]),
            startPoint: CGPoint(x: c.x - 40 * u, y: c.y - 40 * u), endPoint: CGPoint(x: c.x + 40 * u, y: c.y + 40 * u)))
    }

    /// A row of pearls round the edge, each lit from the top left.
    private func pearls(_ context: inout GraphicsContext, _ c: CGPoint) {
        let count = detailed ? 36 : 24
        let radius = (detailed ? 2.75 : 3.4) * u
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            let centre = CGPoint(x: c.x + cos(angle) * 46.4 * u, y: c.y + sin(angle) * 46.4 * u)
            let pearl = Self.circle(centre, radius)
            context.fill(pearl, with: .radialGradient(
                Gradient(colors: [PatronTone.goldPale, PatronTone.gold, PatronTone.goldDeep]),
                center: CGPoint(x: centre.x - radius * 0.4, y: centre.y - radius * 0.45),
                startRadius: 0, endRadius: radius * 1.5))
            context.stroke(pearl, with: .color(PatronTone.goldShadow.opacity(0.55)), lineWidth: 0.3 * u)
        }
    }

    /// The medallion's face, raised: lit at the top left, and its rim cut back into shadow.
    private func disc(_ context: inout GraphicsContext, _ c: CGPoint) {
        let face = Self.circle(c, 43.2 * u)
        context.fill(face, with: .linearGradient(
            Gradient(colors: [PatronTone.goldPale, PatronTone.goldLight, PatronTone.gold, PatronTone.goldDeep]),
            startPoint: CGPoint(x: c.x - 34 * u, y: c.y - 38 * u), endPoint: CGPoint(x: c.x + 32 * u, y: c.y + 38 * u)))
        context.stroke(face, with: .color(PatronTone.goldShadow.opacity(0.85)), lineWidth: 0.8 * u)
    }

    /// The band between the rim and the field: two rules, and a twist engraved between them.
    private func band(_ context: inout GraphicsContext, _ c: CGPoint) {
        let rule = PatronTone.goldShadow.opacity(0.7)
        context.stroke(Self.circle(c, 41.2 * u), with: .color(rule), lineWidth: 0.45 * u)
        context.stroke(Self.circle(c, 35.6 * u), with: .color(rule), lineWidth: 0.45 * u)
        let count = detailed ? 84 : 44
        var twist = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            let lean = 0.07
            twist.move(to: CGPoint(x: c.x + cos(angle) * 36.6 * u, y: c.y + sin(angle) * 36.6 * u))
            twist.addLine(to: CGPoint(x: c.x + cos(angle + lean) * 40.2 * u, y: c.y + sin(angle + lean) * 40.2 * u))
        }
        context.stroke(twist, with: .color(PatronTone.goldShadow.opacity(detailed ? 0.5 : 0.4)),
                       lineWidth: (detailed ? 0.5 : 0.7) * u)
    }

    // MARK: The field

    /// Lapis enamel sunk into the gold, with its own edge catching the light.
    private func field(_ context: inout GraphicsContext, _ c: CGPoint) {
        context.fill(Self.circle(c, 34.2 * u), with: .color(PatronTone.goldShadow))
        let enamel = Self.circle(c, 32.8 * u)
        context.fill(enamel, with: .radialGradient(
            Gradient(colors: [PatronTone.lapisLight, PatronTone.lapis, PatronTone.lapisDeep]),
            center: CGPoint(x: c.x - 7 * u, y: c.y - 11 * u), startRadius: 0, endRadius: 44 * u))
        context.stroke(Self.circle(c, 33.4 * u), with: .linearGradient(
            Gradient(colors: [PatronTone.goldShadow, PatronTone.goldPale.opacity(0.9)]),
            startPoint: CGPoint(x: c.x - 24 * u, y: c.y - 24 * u), endPoint: CGPoint(x: c.x + 24 * u, y: c.y + 24 * u)),
            lineWidth: 0.8 * u)
        if detailed {
            // A ring of gold tesserae just inside the edge.
            context.stroke(Self.circle(c, 29.8 * u), with: .color(PatronTone.goldLight.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 0.9 * u, lineCap: .round, dash: [0, 2.6 * u]))
        }
    }

    /// The small stars of the vault, where the broom leaves room for them.
    private func stars(_ context: inout GraphicsContext, _ c: CGPoint) {
        let spots: [(x: CGFloat, y: CGFloat, r: CGFloat)] = detailed
            ? [(14, 15, 4.2), (22, -8, 2.6), (-4, -25, 2.6), (-24, 4, 2.4), (5, 25, 2.2), (-15, 21, 1.6), (23, 8, 1.5)]
            : [(14, 15, 4.6), (22, -8, 3), (-24, 4, 2.8)]
        for spot in spots {
            PatronStar.strike(in: &context, at: CGPoint(x: c.x + spot.x * u, y: c.y + spot.y * u),
                              radius: spot.r * u, faceted: detailed && spot.r > 2)
        }
    }

    // MARK: The broom

    /// The house broom, gold, the handle to the top right: slats under a terracotta collar.
    private func broom(_ context: inout GraphicsContext, _ c: CGPoint) {
        var local = context
        local.translateBy(x: c.x - 1.4 * u, y: c.y + 1.6 * u)
        local.rotate(by: .degrees(38))
        // Big enough to fill the field from rim to rim, as a charge on a coin does.
        local.scaleBy(x: 1.2, y: 1.2)
        handle(&local)
        bristles(&local)
        collar(&local)
    }

    private func handle(_ context: inout GraphicsContext) {
        let shaft = Path(roundedRect: CGRect(x: -1.9 * u, y: -27 * u, width: 3.8 * u, height: 23 * u), cornerRadius: 1.9 * u)
        context.fill(shaft, with: .linearGradient(
            Gradient(colors: [PatronTone.goldPale, PatronTone.gold, PatronTone.goldDeep]),
            startPoint: CGPoint(x: -1.9 * u, y: 0), endPoint: CGPoint(x: 1.9 * u, y: 0)))
        context.stroke(shaft, with: .color(PatronTone.goldShadow.opacity(0.7)), lineWidth: 0.35 * u)
        if detailed {
            var groove = Path()
            groove.move(to: CGPoint(x: 0.5 * u, y: -24 * u))
            groove.addLine(to: CGPoint(x: 0.5 * u, y: -6 * u))
            context.stroke(groove, with: .color(PatronTone.goldShadow.opacity(0.45)), lineWidth: 0.35 * u)
            context.fill(Self.circle(CGPoint(x: 0, y: -24.6 * u), 0.8 * u), with: .color(PatronTone.goldShadow.opacity(0.75)))
        }
    }

    /// Slats hinged under the collar, the outer ones first so the middle lies on top.
    private func bristles(_ context: inout GraphicsContext) {
        let count = detailed ? 9 : 7
        let order = (0..<count).sorted { abs($0 - count / 2) > abs($1 - count / 2) }
        for index in order {
            let position = Double(index) / Double(count - 1) * 2 - 1
            let length = (25 - abs(position) * 3.5) * u
            var slat = context
            slat.translateBy(x: 0, y: -1.6 * u)
            slat.rotate(by: .degrees(position * 24))
            var outline = Path()
            outline.move(to: CGPoint(x: -1.05 * u, y: 0))
            outline.addLine(to: CGPoint(x: 1.05 * u, y: 0))
            outline.addLine(to: CGPoint(x: 1.45 * u, y: length - 1.2 * u))
            outline.addQuadCurve(to: CGPoint(x: -1.45 * u, y: length - 1.2 * u), control: CGPoint(x: 0, y: length + 0.9 * u))
            outline.closeSubpath()
            slat.fill(outline, with: .linearGradient(
                Gradient(colors: [PatronTone.gold, PatronTone.goldLight, PatronTone.goldPale, PatronTone.gold]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: length)))
            slat.stroke(outline, with: .color(PatronTone.goldShadow.opacity(0.6)), lineWidth: 0.3 * u)
        }
        guard detailed else { return }
        // The two rows of stitching that hold the slats together.
        for reach in [7.0, 10.5] {
            var stitch = Path()
            stitch.addArc(center: CGPoint(x: 0, y: -1.6 * u), radius: reach * u,
                          startAngle: .degrees(90 - 27), endAngle: .degrees(90 + 27), clockwise: false)
            context.stroke(stitch, with: .color(PatronTone.goldShadow.opacity(0.65)), lineWidth: 0.45 * u)
        }
    }

    private func collar(_ context: inout GraphicsContext) {
        let band = Path(roundedRect: CGRect(x: -5.2 * u, y: -5.6 * u, width: 10.4 * u, height: 4.2 * u), cornerRadius: 1.2 * u)
        context.fill(band, with: .linearGradient(
            Gradient(colors: [PatronTone.terracotta, PatronTone.terracottaDeep]),
            startPoint: CGPoint(x: 0, y: -5.6 * u), endPoint: CGPoint(x: 0, y: -1.4 * u)))
        context.stroke(band, with: .color(PatronTone.goldShadow.opacity(0.75)), lineWidth: 0.4 * u)
        if detailed {
            var bead = Path()
            bead.move(to: CGPoint(x: -4.4 * u, y: -3.5 * u))
            bead.addLine(to: CGPoint(x: 4.4 * u, y: -3.5 * u))
            context.stroke(bead, with: .color(PatronTone.goldLight.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 0.7 * u, lineCap: .round, dash: [0, 1.6 * u]))
        }
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}

/// The eight-pointed gold star of Ravenna's vaults, struck rather than printed: sixteen
/// facets, each lit from the top left as a raised star would be.
nonisolated enum PatronStar {
    /// The star's outline, a point straight up.
    static func path(at c: CGPoint, radius: CGFloat, waist: CGFloat = 0.42) -> Path {
        var path = Path()
        for index in 0..<16 {
            let angle = Double(index) * .pi / 8 - .pi / 2
            let reach = index.isMultiple(of: 2) ? radius : radius * waist
            let point = CGPoint(x: c.x + cos(angle) * reach, y: c.y + sin(angle) * reach)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Facets where it is big enough for them to be seen, a flat gold star where it is not.
    static func strike(in context: inout GraphicsContext, at c: CGPoint, radius: CGFloat,
                       faceted: Bool = true, opacity: Double = 1) {
        guard faceted else {
            context.fill(path(at: c, radius: radius), with: .color(PatronTone.goldLight.opacity(opacity)))
            return
        }
        let tones = [PatronTone.goldDeep, PatronTone.gold, PatronTone.goldLight, PatronTone.goldPale]
        let light = -3 * Double.pi / 4
        for point in 0..<8 {
            let angle = Double(point) * .pi / 4 - .pi / 2
            let tip = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            for side in [-1.0, 1.0] {
                let waistAngle = angle + side * .pi / 8
                let waist = CGPoint(x: c.x + cos(waistAngle) * radius * 0.42, y: c.y + sin(waistAngle) * radius * 0.42)
                var facet = Path()
                facet.move(to: c)
                facet.addLine(to: tip)
                facet.addLine(to: waist)
                facet.closeSubpath()
                // The side of each ridge that faces the light is the bright one.
                let facing = angle + side * .pi / 2
                let lit = (cos(facing - light) + 1) / 2
                let tone = tones[min(Int(lit * Double(tones.count)), tones.count - 1)]
                context.fill(facet, with: .color(tone.opacity(opacity)))
            }
        }
        context.stroke(path(at: c, radius: radius), with: .color(PatronTone.goldShadow.opacity(0.5 * opacity)),
                       lineWidth: max(radius * 0.05, 0.3))
    }
}

#Preview("The patron's crest") {
    VStack(spacing: 28) {
        PatronCrest(size: 180)
        HStack(spacing: 22) {
            PatronCrest(size: 64)
            PatronCrest(size: 44)
            PatronCrest(size: 30)
            PatronCrest(size: 22)
        }
    }
    .padding(40)
    .background(PatronTone.lapisDeep)
}
