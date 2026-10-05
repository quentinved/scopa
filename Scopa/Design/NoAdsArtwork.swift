import SwiftUI

/// The no-ads purchase, drawn: the house broom sweeping an ad strip off the green table.
///
/// Used at the head of the purchase sheet, and rendered square by Tools/render-no-ads.sh
/// for the App Store's promotional image. No words, so one picture serves every language.
/// Colours are written out, as in `IconArtwork`, so the file compiles on its own.
struct NoAdsArtwork: View {
    var size: CGFloat
    /// The App Store image wants a full square ground; the sheet lets the art float.
    var hasGround = true

    private var unit: CGFloat { size / 1024 }

    private static let deepGreen = Color(red: 0.055, green: 0.180, blue: 0.114)
    private static let green = Color(red: 0.153, green: 0.310, blue: 0.204)
    private static let lightGreen = Color(red: 0.278, green: 0.451, blue: 0.302)
    private static let cream = Color(red: 0.988, green: 0.973, blue: 0.933)
    private static let stock = Color(red: 0.937, green: 0.906, blue: 0.827)
    private static let gold = Color(red: 0.851, green: 0.643, blue: 0.267)
    private static let goldLight = Color(red: 0.976, green: 0.855, blue: 0.494)
    private static let goldDeep = Color(red: 0.678, green: 0.478, blue: 0.153)
    private static let steel = Color(red: 0.259, green: 0.290, blue: 0.322)
    private static let ink = Color(red: 0.114, green: 0.098, blue: 0.086)
    private static let terracotta = Color(red: 0.788, green: 0.310, blue: 0.220)

    var body: some View {
        ZStack {
            if hasGround { ground }
            rays
            ZStack {
                trail
                strip
                    .rotationEffect(.degrees(10))
                    .offset(x: 200 * unit, y: 110 * unit)
                sparkles
                broom
                    .scaleEffect(0.82)
                    .rotationEffect(.degrees(-76))
                    .offset(x: -300 * unit, y: 40 * unit)
            }
            .offset(y: -80 * unit)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    // MARK: Ground

    private var ground: some View {
        ZStack {
            LinearGradient(colors: [Self.lightGreen, Self.green, Self.deepGreen],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.24), .clear], center: UnitPoint(x: 0.14, y: 0.02),
                           startRadius: 0, endRadius: 620 * unit)
            RadialGradient(colors: [Self.deepGreen.opacity(0.85), .clear], center: UnitPoint(x: 0.92, y: 1.04),
                           startRadius: 0, endRadius: 720 * unit)
        }
    }

    private var rays: some View {
        Rays(count: 22)
            .fill(RadialGradient(colors: [Self.goldLight.opacity(0.4), Self.gold.opacity(0.15), .clear],
                                 center: .center, startRadius: 100 * unit, endRadius: 480 * unit))
            .blur(radius: 9 * unit)
            .frame(width: 1080 * unit, height: 1080 * unit)
            .blendMode(.plusLighter)
    }

    // MARK: The ad being swept

    /// A banner ad as anyone would know one: a picture, two lines, a button and its badge.
    private var strip: some View {
        HStack(spacing: 26 * unit) {
            RoundedRectangle(cornerRadius: 18 * unit, style: .continuous)
                .fill(Self.steel.opacity(0.35))
                .frame(width: 112 * unit, height: 112 * unit)
            VStack(alignment: .leading, spacing: 18 * unit) {
                Capsule().fill(Self.steel.opacity(0.45)).frame(width: 190 * unit, height: 22 * unit)
                Capsule().fill(Self.steel.opacity(0.25)).frame(width: 140 * unit, height: 18 * unit)
            }
            Capsule().fill(Self.steel.opacity(0.4)).frame(width: 96 * unit, height: 50 * unit)
        }
        .padding(.horizontal, 34 * unit)
        .frame(width: 560 * unit, height: 180 * unit)
        .background {
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .fill(LinearGradient(colors: [Self.cream, Self.stock], startPoint: .top, endPoint: .bottom))
        }
        .overlay(alignment: .topTrailing) { badge.offset(x: -18 * unit, y: 14 * unit) }
        .overlay {
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .strokeBorder(.white.opacity(0.7), lineWidth: 4 * unit)
        }
        // Fading towards the far edge, on its way out.
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .black.opacity(0.15), location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .shadow(color: Self.deepGreen.opacity(0.55), radius: 28 * unit, y: 14 * unit)
    }

    private var badge: some View {
        Text(verbatim: "AD")
            .font(.system(size: 26 * unit, weight: .heavy, design: .rounded))
            .foregroundStyle(Self.cream)
            .padding(.horizontal, 12 * unit)
            .padding(.vertical, 4 * unit)
            .background(Capsule().fill(Self.steel.opacity(0.6)))
    }

    /// Streaks behind the strip, where the broom has just passed.
    private var trail: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient(colors: [.clear, Self.cream.opacity(0.35)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: (300 - Double(index) * 40) * unit, height: 10 * unit)
                    .offset(x: (-60 + Double(index) * 18) * unit, y: (-30 + Double(index) * 52) * unit)
            }
        }
        .rotationEffect(.degrees(10))
        .offset(x: -60 * unit, y: 110 * unit)
    }

    private var sparkles: some View {
        ZStack {
            ForEach(Array(Self.sparkleSpots.enumerated()), id: \.offset) { _, spot in
                Sparkle()
                    .fill(Self.goldLight)
                    .frame(width: spot.z * unit, height: spot.z * unit)
                    .shadow(color: Self.goldLight.opacity(0.9), radius: 12 * unit)
                    .offset(x: spot.x * unit, y: spot.y * unit)
            }
        }
    }

    private static let sparkleSpots: [(x: CGFloat, y: CGFloat, z: CGFloat)] = [
        (150, -120, 56), (390, -60, 34), (420, 330, 40), (40, 300, 30), (240, 360, 22),
    ]

    // MARK: The broom

    private var broom: some View {
        ZStack {
            handle
            bristles
            collar
        }
        .shadow(color: Self.deepGreen.opacity(0.6), radius: 30 * unit, y: 18 * unit)
    }

    private var handle: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(red: 0.271, green: 0.235, blue: 0.204), Self.ink],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay {
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                              startPoint: .leading, endPoint: .center))
            }
            .frame(width: 50 * unit, height: 420 * unit)
            .offset(y: -250 * unit)
    }

    private var bristles: some View {
        let count = 11
        return ForEach(0..<count, id: \.self) { index in
            let position = Double(index) / Double(count - 1) * 2 - 1
            Capsule()
                .fill(LinearGradient(colors: [Self.gold, Self.goldLight], startPoint: .top, endPoint: .bottom))
                .overlay {
                    Capsule().fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                  startPoint: .topLeading, endPoint: .center))
                }
                .frame(width: 24 * unit, height: (300 - abs(position) * 40) * unit)
                .offset(y: 160 * unit)
                .rotationEffect(.degrees(position * 26))
        }
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 12 * unit, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.937, green: 0.494, blue: 0.353), Self.terracotta],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * unit, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 3 * unit)
            }
            .frame(width: 180 * unit, height: 58 * unit)
            .offset(y: -20 * unit)
    }
}

/// A burst of thin wedges from the centre.
private struct Rays: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height)
        let half = .pi / Double(count) * 0.32
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            path.move(to: centre)
            path.addLine(to: CGPoint(x: centre.x + radius * cos(angle - half), y: centre.y + radius * sin(angle - half)))
            path.addLine(to: CGPoint(x: centre.x + radius * cos(angle + half), y: centre.y + radius * sin(angle + half)))
            path.closeSubpath()
        }
        return path
    }
}

/// A four-point star, the glint of something freshly swept.
private struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.22
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
