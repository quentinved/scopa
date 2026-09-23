import SwiftUI

/// How much work the one medal carries at each league: a bare struck disc, then a milled
/// edge, a set ring, studs, a cut stone with a halo, and light behind it at the top.
///
/// Each tier keeps everything the tier below earned, like `Prestige`.
enum LeagueRank: Int, Comparable, CaseIterable {
    case struck, milled, ringed, studded, set, crowned

    static func < (a: LeagueRank, b: LeagueRank) -> Bool { a.rawValue < b.rawValue }

    /// Bronze, Silver, Gold, Platinum, Diamond, Maestro, in the order the ladder counts.
    static func league(_ index: Int) -> LeagueRank { LeagueRank(rawValue: index) ?? .struck }
}

/// What a league is struck in: three tones of one metal and its stone. The medal, the bar
/// and the rim all take their colour from here.
struct LeagueMetal: Hashable {
    let dark: Color
    let base: Color
    let light: Color
    /// The stone set in the face, at the leagues that have one.
    var stone: Color = Color(red: 0.62, green: 0.88, blue: 1.0)
    /// The little stones round the bezel, where they are not the same as the big one.
    var halo: Color?

    /// Light at the top left, deep at the bottom right.
    var sheen: LinearGradient {
        LinearGradient(colors: [light, base, dark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let bronze = LeagueMetal(dark: Color(red: 0.33, green: 0.18, blue: 0.09),
                                    base: Color(red: 0.63, green: 0.39, blue: 0.20),
                                    light: Color(red: 0.87, green: 0.62, blue: 0.38))
    static let silver = LeagueMetal(dark: Color(red: 0.36, green: 0.39, blue: 0.42),
                                    base: Color(red: 0.68, green: 0.71, blue: 0.75),
                                    light: Color(red: 0.95, green: 0.96, blue: 0.98))
    static let gold = LeagueMetal(dark: Palette.goldDeep, base: Palette.gold, light: Palette.goldLight)
    /// Colder and whiter than silver, which it is only a shade from on a phone.
    static let platinum = LeagueMetal(dark: Color(red: 0.42, green: 0.48, blue: 0.55),
                                      base: Color(red: 0.80, green: 0.85, blue: 0.89),
                                      light: Color(red: 0.98, green: 0.99, blue: 1.00))
    /// White metal and ice, so the stone carries the medal.
    static let diamond = LeagueMetal(dark: Color(red: 0.38, green: 0.52, blue: 0.62),
                                     base: Color(red: 0.82, green: 0.90, blue: 0.95),
                                     light: Color(red: 0.99, green: 1.00, blue: 1.00))
    /// The same stone in gold, with terracotta set round it.
    static let maestro = LeagueMetal(dark: Palette.goldDeep, base: Palette.gold, light: Palette.goldLight,
                                     halo: Palette.terracotta)

    static let ladder = [bronze, silver, gold, platinum, diamond, maestro]

    static func league(_ index: Int) -> LeagueMetal { ladder[safe: index] ?? bronze }
}

/// The medal for a league, at any size. Everything inside is measured against `size`.
/// The glow and the rays reach past the frame without changing the layout.
struct LeagueMedal: View {
    let league: Int
    var size: CGFloat = 20

    /// What the piece drops on the cloth, so the shadow is the table's own colour.
    @Environment(\.tableFelt) private var felt

    private var metal: LeagueMetal { .league(league) }
    private var rank: LeagueRank { .league(league) }
    private var isSet: Bool { rank >= .set }

    var body: some View {
        ZStack {
            if rank >= .crowned { rays }
            if isSet { glow }
            disc
            if rank >= .ringed { ring }
            if rank >= .studded { studs }
            if isSet { halo }
            centre
            if isSet { glints }
        }
        .frame(width: size, height: size)
        .shadow(color: felt.shade(0.5), radius: size * 0.06, y: size * 0.03)
    }

    // MARK: The metal

    /// The medal itself: struck plain at the bottom of the ladder, milled from silver up.
    @ViewBuilder private var disc: some View {
        if rank >= .milled {
            Cog(teeth: 22, depth: 0.055)
                .fill(metal.sheen)
                .overlay { Cog(teeth: 22, depth: 0.055).strokeBorder(metal.dark.opacity(0.7), lineWidth: size * 0.025) }
                .overlay(face)
        } else {
            Circle()
                .fill(metal.sheen)
                .overlay { Circle().strokeBorder(metal.dark.opacity(0.7), lineWidth: size * 0.035) }
                .overlay(face)
        }
    }

    /// The face, sunk inside the edge and lit from the opposite corner so the edge reads
    /// as raised metal.
    private var face: some View {
        Circle()
            .fill(LinearGradient(colors: [metal.base, metal.light, metal.dark],
                                 startPoint: .bottomTrailing, endPoint: .topLeading))
            .overlay { Circle().strokeBorder(metal.dark.opacity(0.45), lineWidth: size * 0.02) }
            .padding(size * (isSet ? 0.11 : 0.16))
    }

    /// A raised ring set inside the edge.
    private var ring: some View {
        Circle()
            .strokeBorder(LinearGradient(colors: [metal.light, metal.dark], startPoint: .topLeading, endPoint: .bottomTrailing),
                          lineWidth: size * 0.045)
            .padding(size * 0.20)
    }

    /// Eight studs set into the ring.
    private var studs: some View {
        ForEach(0..<8, id: \.self) { index in
            Circle()
                .fill(LinearGradient(colors: [metal.light, metal.base], startPoint: .top, endPoint: .bottom))
                .overlay { Circle().strokeBorder(metal.dark.opacity(0.6), lineWidth: size * 0.008) }
                .frame(width: size * 0.075, height: size * 0.075)
                .offset(y: -size * 0.325)
                .rotationEffect(.degrees(Double(index) / 8 * 360 + 22.5))
        }
    }

    // MARK: The stone

    /// What sits in the middle: a struck sparkle, or the stone once it is earned.
    @ViewBuilder private var centre: some View {
        if isSet {
            brilliant
        } else {
            Sparkle()
                .fill(metal.light)
                .frame(width: size * 0.34, height: size * 0.34)
                .shadow(color: metal.dark.opacity(0.6), radius: size * 0.02, y: size * 0.01)
        }
    }

    /// A brilliant seen from above: an eight-sided girdle, a flat table, and the facets
    /// between them.
    private var brilliant: some View {
        ZStack {
            Polygon(sides: 8)
                .fill(LinearGradient(colors: [.white, metal.stone, metal.stone.opacity(0.75)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Facets(sides: 8, table: 0.5).stroke(.white.opacity(0.55), lineWidth: size * 0.012) }
                .overlay { Polygon(sides: 8).strokeBorder(.white.opacity(0.9), lineWidth: size * 0.022) }
            Polygon(sides: 8)
                .fill(LinearGradient(colors: [.white, metal.stone.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Polygon(sides: 8).strokeBorder(.white.opacity(0.75), lineWidth: size * 0.014) }
                .frame(width: size * 0.24, height: size * 0.24)
        }
        .frame(width: size * 0.56, height: size * 0.56)
        .shadow(color: metal.stone.opacity(0.9), radius: size * 0.10)
    }

    /// Eight small stones set round the ring.
    private var halo: some View {
        ForEach(0..<8, id: \.self) { index in
            Circle()
                .fill(RadialGradient(colors: [.white, metal.halo ?? metal.stone],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.05))
                .overlay { Circle().strokeBorder(metal.light.opacity(0.9), lineWidth: size * 0.01) }
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(y: -size * 0.335)
                .rotationEffect(.degrees(Double(index) / 8 * 360))
        }
    }

    /// Two four-point glints on the stone. Drawn rather than animated.
    private var glints: some View {
        ZStack {
            Sparkle()
                .fill(.white)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.13, y: -size * 0.14)
            Sparkle()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(x: size * 0.14, y: size * 0.12)
        }
    }

    /// The light a stone throws on the felt around it.
    private var glow: some View {
        Circle()
            .fill(RadialGradient(colors: [metal.stone.opacity(0.6), metal.stone.opacity(0.22), metal.stone.opacity(0)],
                                 center: .center, startRadius: size * 0.30, endRadius: size * 0.62))
            .frame(width: size * 1.24, height: size * 1.24)
    }

    /// Twelve short rays behind the top league's medal.
    private var rays: some View {
        Sunburst(count: 12)
            .fill(RadialGradient(colors: [metal.light, metal.light.opacity(0.85), metal.base.opacity(0)],
                                 center: .center, startRadius: size * 0.60, endRadius: size * 0.95))
            .frame(width: size * 1.85, height: size * 1.85)
    }
}

/// A four-pointed star with hollowed sides, used for struck sparkles and stone glints.
private struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let waist = outer * 0.28
        var path = Path()
        for index in 0..<4 {
            let angle = Double(index) * .pi / 2 - .pi / 2
            let tip = CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer)
            let next = angle + .pi / 4
            let side = CGPoint(x: centre.x + cos(next) * waist, y: centre.y + sin(next) * waist)
            if index == 0 { path.move(to: tip) } else { path.addLine(to: tip) }
            path.addQuadCurve(to: side, control: centre)
        }
        path.closeSubpath()
        return path
    }
}

/// A regular polygon, point up.
private struct Polygon: InsettableShape {
    var sides: Int
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> Polygon {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - inset
        var path = Path()
        for index in 0..<sides {
            let angle = Double(index) / Double(sides) * 2 * .pi - .pi / 2
            let point = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The lines a cut stone shows between its girdle and its table.
private struct Facets: Shape {
    var sides: Int
    /// How far in the table sits, as a fraction of the radius.
    var table: CGFloat

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<sides {
            let angle = Double(index) / Double(sides) * 2 * .pi - .pi / 2
            path.move(to: CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * radius * table,
                                     y: centre.y + sin(angle) * radius * table))
        }
        return path
    }
}

/// Wedges radiating from the centre, for the light behind the top league's medal.
private struct Sunburst: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.34
        let outer = min(rect.width, rect.height) * 0.5
        let half = .pi / Double(count) * 0.40
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            path.move(to: CGPoint(x: centre.x + cos(angle - half) * inner, y: centre.y + sin(angle - half) * inner))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
            path.addLine(to: CGPoint(x: centre.x + cos(angle + half) * inner, y: centre.y + sin(angle + half) * inner))
            path.closeSubpath()
        }
        return path
    }
}

#Preview("The ladder, one medal at a time") {
    ZStack {
        TableGround()
        VStack(spacing: 26) {
            ForEach(0..<6, id: \.self) { league in
                HStack(spacing: 18) {
                    LeagueMedal(league: league, size: 22)
                    LeagueMedal(league: league, size: 46)
                    Text(verbatim: ["BRONZE III", "SILVER I", "GOLD III", "PLATINUM II", "DIAMOND I", "MAESTRO"][league])
                        .font(.system(size: 12.5, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.onTable)
                    Spacer()
                }
                .frame(width: 300)
            }
        }
        .padding(40)
    }
}
