import SwiftUI

/// How much metal a seat mark wears around its circle. Each tier adds a piece to the last:
/// hairline, studs, bezel, toothed plate, steel plate with rivets, rays, jewels.
///
/// All of it draws outside the circle and never changes the layout size, so a badge
/// measured for a plain circle can wear the lot.
enum Prestige: Int, Comparable, CaseIterable {
    case none, ring, studded, bezel, plated, armoured, royal, sovereign

    static func < (lhs: Prestige, rhs: Prestige) -> Bool { lhs.rawValue < rhs.rawValue }

    /// How far past the circle's edge the armour reaches, as a multiple of the badge size.
    /// Callers with tight neighbours can budget for it.
    var reach: CGFloat {
        switch self {
        case .none: 1.00
        case .ring, .studded: 1.14
        case .bezel: 1.22
        case .plated: 1.30
        case .armoured: 1.34
        case .royal, .sovereign: 1.52
        }
    }
}

/// Everything that lies *behind* the circle: the plates and the rays.
struct PrestigePlate: View {
    var tier: Prestige
    var size: CGFloat

    /// What the piece drops on the cloth, so the shadow is the table's own colour.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        if tier >= .plated {
            ZStack {
                if tier >= .royal { rays }
                if tier >= .armoured { steelPlate } else { goldPlate }
            }
        }
    }

    /// Sixteen short rays showing past the plate. They start under it so their inner ends
    /// never show.
    private var rays: some View {
        Sunburst(count: 16)
            .fill(RadialGradient(colors: [Palette.goldLight, Palette.goldLight.opacity(0.85), Palette.gold.opacity(0.0)],
                                 center: .center, startRadius: size * 0.64, endRadius: size * 0.76))
            .frame(width: size * 1.52, height: size * 1.52)
    }

    /// A gilded cog with twelve teeth.
    private var goldPlate: some View {
        Cog(teeth: 12, depth: 0.14)
            .fill(Palette.goldSheen)
            .overlay { Cog(teeth: 12, depth: 0.14).strokeBorder(Palette.goldDeep.opacity(0.8), lineWidth: size * 0.018) }
            .frame(width: size * 1.30, height: size * 1.30)
            .shadow(color: felt.shade(0.45), radius: size * 0.04, y: size * 0.02)
    }

    /// A steel plate with sixteen teeth and a rivet at each.
    private var steelPlate: some View {
        ZStack {
            Cog(teeth: 16, depth: 0.12)
                .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.59, blue: 0.63), Palette.steel,
                                              Color(red: 0.16, green: 0.18, blue: 0.20)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Cog(teeth: 16, depth: 0.12)
                .strokeBorder(Palette.goldLight.opacity(0.9), lineWidth: size * 0.02)
            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .fill(Palette.goldSheen)
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(y: -size * 0.60)
                    .rotationEffect(.degrees(Double(index) / 16 * 360))
            }
        }
        .frame(width: size * 1.34, height: size * 1.34)
        .shadow(color: felt.shade(0.55), radius: size * 0.05, y: size * 0.025)
    }
}

/// Everything that lies *over* the circle's edge: the ring or bezel, its studs, and the
/// jewels at the top tier.
struct PrestigeRim: View {
    var tier: Prestige
    var size: CGFloat

    /// What the piece drops on the cloth, so the shadow is the table's own colour.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        if tier >= .ring {
            ZStack {
                if tier >= .bezel { bezel } else { hairline }
                if tier >= .studded && tier < .armoured { studs }
                if tier >= .sovereign { jewels }
            }
        }
    }

    /// A single gold line a little way out from the circle, the first thing earned.
    private var hairline: some View {
        Circle()
            .strokeBorder(Palette.goldSheen, lineWidth: size * 0.045)
            .frame(width: size * 1.14, height: size * 1.14)
    }

    /// A thick two-tone bezel with a dark line cut round its inside, so it reads as a
    /// separate piece of metal rather than a fatter ring.
    private var bezel: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.goldSheen, lineWidth: size * 0.10)
            Circle()
                .strokeBorder(Palette.goldDeep.opacity(0.85), lineWidth: size * 0.018)
                .padding(size * 0.075)
            Circle()
                .strokeBorder(.white.opacity(0.55), lineWidth: size * 0.012)
                .padding(size * 0.012)
        }
        .frame(width: size * 1.22, height: size * 1.22)
        .shadow(color: felt.shade(0.4), radius: size * 0.03, y: size * 0.015)
    }

    /// Eight studs set on the ring.
    private var studs: some View {
        let radius = tier >= .bezel ? size * 0.585 : size * 0.545
        return ForEach(0..<8, id: \.self) { index in
            Circle()
                .fill(LinearGradient(colors: [Palette.goldLight, Palette.goldDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Circle().strokeBorder(Palette.goldDeep.opacity(0.7), lineWidth: size * 0.01) }
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(y: -radius)
                .rotationEffect(.degrees(Double(index) / 8 * 360))
        }
    }

    /// Three terracotta cabochons set into the bezel.
    private var jewels: some View {
        ForEach([0.0, 120.0, 240.0], id: \.self) { angle in
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.45), Palette.terracotta,
                                              Color(red: 0.45, green: 0.15, blue: 0.10)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.08))
                .overlay { Circle().strokeBorder(Palette.goldLight, lineWidth: size * 0.018) }
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(y: -size * 0.59)
                .rotationEffect(.degrees(angle))
        }
    }
}

/// A round plate with flat teeth cut round its edge.
struct Cog: InsettableShape {
    var teeth: Int
    /// How deep the teeth are cut, as a fraction of the radius.
    var depth: CGFloat = 0.12
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> Cog {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 - inset
        let inner = outer * (1 - depth)
        let step = .pi * 2 / Double(teeth)
        func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
        }
        var path = Path()
        for index in 0..<teeth {
            let angle = Double(index) * step - .pi / 2
            let corners = [
                point(angle - step * 0.20, outer),
                point(angle + step * 0.20, outer),
                point(angle + step * 0.30, inner),
                point(angle + step * 0.70, inner),
            ]
            if index == 0 { path.move(to: corners[0]) } else { path.addLine(to: corners[0]) }
            for corner in corners.dropFirst() { path.addLine(to: corner) }
        }
        path.closeSubpath()
        return path
    }
}

/// Wedges radiating from the centre.
private struct Sunburst: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.38
        let outer = min(rect.width, rect.height) * 0.5
        let half = .pi / Double(count) * 0.42
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            path.move(to: CGPoint(x: centre.x + cos(angle - half) * inner,
                                  y: centre.y + sin(angle - half) * inner))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer,
                                     y: centre.y + sin(angle) * outer))
            path.addLine(to: CGPoint(x: centre.x + cos(angle + half) * inner,
                                     y: centre.y + sin(angle + half) * inner))
            path.closeSubpath()
        }
        return path
    }
}

#Preview("Marks by prestige") {
    ZStack {
        TableGround()
        VStack(spacing: 28) {
            HStack(spacing: 22) {
                ForEach(SeatMark.allCases) { mark in
                    SeatBadge(name: "Q", tint: Palette.seat(0), size: 44, mark: mark)
                }
            }
            HStack(spacing: 40) {
                SeatBadge(name: "Q", tint: Palette.seat(2), size: 84, mark: .heart)
                SeatBadge(name: "Q", tint: Palette.seat(3), size: 84, mark: .sun)
                SeatBadge(name: "Q", tint: Palette.seat(1), size: 84, mark: .crown)
            }
            HStack(spacing: 14) {
                ForEach(SeatMark.allCases) { mark in
                    SeatBadge(name: "Q", tint: Palette.seat(0), size: 26, mark: mark)
                }
            }
        }
        .padding(40)
    }
}
