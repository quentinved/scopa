import SwiftUI

/// The app icon, drawn rather than painted, so it can be re-rendered at any size.
///
/// Bottle green under a gold frame, a burst of rays, three cards fanned above a gold
/// broom, and the name on a glass plaque.
///
/// The colours are written out rather than taken from `Palette`, so the icon does not
/// shift when the interface palette is tuned and this file compiles on its own for
/// `Tools/render-icon.sh`.
struct IconArtwork: View {
    /// The three home-screen appearances iOS asks for. `tinted` is drawn in grey on black
    /// because the system maps a grey icon through the colour the player picked: light
    /// pixels take the tint, dark ones stay dark.
    enum Appearance { case light, dark, tinted }

    /// Everything is expressed against this, so 1024 and 180 draw the same picture.
    var size: CGFloat
    var appearance: Appearance = .light

    private var unit: CGFloat { size / 1024 }

    private static let deepGreen = Color(red: 0.055, green: 0.180, blue: 0.114)
    private static let green = Color(red: 0.153, green: 0.310, blue: 0.204)
    private static let lightGreen = Color(red: 0.278, green: 0.451, blue: 0.302)
    private static let cream = Color(red: 0.988, green: 0.973, blue: 0.933)
    private static let stock = Color(red: 0.937, green: 0.906, blue: 0.827)
    private static let terracotta = Color(red: 0.788, green: 0.310, blue: 0.220)
    private static let gold = Color(red: 0.851, green: 0.643, blue: 0.267)
    private static let goldLight = Color(red: 0.976, green: 0.855, blue: 0.494)
    private static let goldDeep = Color(red: 0.678, green: 0.478, blue: 0.153)
    private static let steel = Color(red: 0.259, green: 0.290, blue: 0.322)
    private static let ink = Color(red: 0.114, green: 0.098, blue: 0.086)
    /// The bottom of the dark icon's ground: green gone almost to black.
    private static let night = Color(red: 0.020, green: 0.067, blue: 0.043)

    var body: some View {
        drawing.grayscale(appearance == .tinted ? 1 : 0)
    }

    private var drawing: some View {
        ZStack {
            ground
            // Scaled and lifted as one group, so the plaque sits under the picture and the
            // fan keeps its proportions.
            ZStack {
                rays
                fan
                broom
            }
            .scaleEffect(0.86)
            .offset(y: -84 * unit)
            wordmark
        }
        .frame(width: size, height: size)
        .clipped()
        .overlay { frame }
        .overlay { sheen }
    }

    // MARK: Ground

    /// Bottle green lit from the top left — banked down for the dark icon, and taken to
    /// black for the tinted one so the cards and the broom are what the tint lands on.
    private var ground: some View {
        ZStack {
            switch appearance {
            case .light:
                LinearGradient(colors: [Self.lightGreen, Self.green, Self.deepGreen],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.26), .clear],
                               center: UnitPoint(x: 0.14, y: 0.02),
                               startRadius: 0, endRadius: 620 * unit)
                RadialGradient(colors: [Self.deepGreen.opacity(0.85), .clear],
                               center: UnitPoint(x: 0.92, y: 1.04),
                               startRadius: 0, endRadius: 720 * unit)
            case .dark:
                LinearGradient(colors: [Self.green, Self.deepGreen, Self.night],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.10), .clear],
                               center: UnitPoint(x: 0.14, y: 0.02),
                               startRadius: 0, endRadius: 620 * unit)
            case .tinted:
                Color.black
                RadialGradient(colors: [.white.opacity(0.12), .clear],
                               center: UnitPoint(x: 0.14, y: 0.02),
                               startRadius: 0, endRadius: 620 * unit)
            }
        }
    }

    /// The burst behind the cards, as light rather than drawn gold.
    private var rays: some View {
        Sunburst(count: 22)
            .fill(RadialGradient(colors: [Self.goldLight.opacity(0.42), Self.gold.opacity(0.16), .clear],
                                 center: .center, startRadius: 120 * unit, endRadius: 470 * unit))
            .blur(radius: 9 * unit)
            .frame(width: 1080 * unit, height: 1080 * unit)
            .offset(y: -110 * unit)
            .blendMode(.plusLighter)
    }

    // MARK: The fan

    /// Three cards, the middle one in front.
    private var fan: some View {
        ZStack {
            card(suit: .cup)
                .rotationEffect(.degrees(-22))
                .offset(x: -198 * unit, y: 44 * unit)
            card(suit: .sword)
                .rotationEffect(.degrees(22))
                .offset(x: 198 * unit, y: 44 * unit)
            card(suit: .coin)
                .offset(y: -24 * unit)
        }
    }

    private enum IconSuit { case cup, coin, sword }

    private func card(suit: IconSuit) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .fill(LinearGradient(colors: [Self.cream, Self.stock],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            // The gold hairline inside the card edge.
            RoundedRectangle(cornerRadius: 22 * unit, style: .continuous)
                .strokeBorder(Self.gold.opacity(0.55), lineWidth: 4 * unit)
                .padding(16 * unit)
            mark(for: suit)
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.5), location: 0.0),
                    .init(color: .clear, location: 0.4),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .strokeBorder(edge(for: suit), lineWidth: 5 * unit)
        }
        .frame(width: 256 * unit, height: 380 * unit)
        .shadow(color: Self.deepGreen.opacity(0.55), radius: 28 * unit, y: 14 * unit)
    }

    /// The specular edge each card carries, in gold for the coin card at the front.
    private func edge(for suit: IconSuit) -> LinearGradient {
        let colours: [Color] = suit == .coin
            ? [Self.goldLight, Self.gold.opacity(0.55), Self.goldLight.opacity(0.9)]
            : [.white, .white.opacity(0.4), .white.opacity(0.8)]
        return LinearGradient(colors: colours, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private func mark(for suit: IconSuit) -> some View {
        switch suit {
        case .coin: coinMark
        case .cup: cupMark
        case .sword: swordMark
        }
    }

    private var coinMark: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Self.goldLight, Self.gold],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Self.goldDeep.opacity(0.8), lineWidth: 8 * unit).padding(24 * unit)
            Circle().fill(Self.goldDeep.opacity(0.8)).frame(width: 24 * unit)
            Circle().strokeBorder(.white.opacity(0.7), lineWidth: 4 * unit)
        }
        .frame(width: 176 * unit, height: 176 * unit)
        .offset(y: -40 * unit)
    }

    private var cupMark: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(bottomLeadingRadius: 54 * unit, bottomTrailingRadius: 54 * unit,
                                   style: .continuous)
                .fill(Self.terracotta)
                .frame(width: 128 * unit, height: 94 * unit)
            Rectangle().fill(Self.terracotta).frame(width: 24 * unit, height: 34 * unit)
            Capsule().fill(Self.terracotta).frame(width: 104 * unit, height: 22 * unit)
        }
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.45))
                .frame(width: 72 * unit, height: 14 * unit)
                .offset(y: 17 * unit)
        }
        .offset(y: -40 * unit)
    }

    private var swordMark: some View {
        VStack(spacing: 0) {
            Blade().fill(Self.steel).frame(width: 58 * unit, height: 126 * unit)
            Capsule().fill(Self.gold).frame(width: 146 * unit, height: 19 * unit)
            Rectangle().fill(Self.steel).frame(width: 22 * unit, height: 29 * unit)
            Circle().fill(Self.gold).frame(width: 32 * unit)
        }
        .offset(y: -46 * unit)
    }

    // MARK: The broom

    /// The broom the game is named after, in front of the fan.
    private var broom: some View {
        ZStack {
            Circle()
                .fill(Self.gold.opacity(0.30))
                .frame(width: 500 * unit, height: 500 * unit)
                .offset(y: 130 * unit)
                .blur(radius: 100 * unit)
            handle
            bristles
            collar
        }
        .rotationEffect(.degrees(74))
        .offset(x: 62 * unit, y: 137 * unit)
        .shadow(color: Self.deepGreen.opacity(0.6), radius: 30 * unit, y: 18 * unit)
    }

    private var handle: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(red: 0.271, green: 0.235, blue: 0.204), Self.ink],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay {
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                         startPoint: .leading, endPoint: .center))
            }
            .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 3 * unit) }
            .frame(width: 44 * unit, height: 240 * unit)
            .offset(y: -190 * unit)
    }

    /// Slats hinged just under the collar, narrow enough to separate at the tips.
    private var bristles: some View {
        let count = 11
        return ForEach(0..<count, id: \.self) { index in
            let position = Double(index) / Double(count - 1) * 2 - 1
            Capsule()
                .fill(LinearGradient(colors: [Self.gold, Self.goldLight],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                             startPoint: .topLeading, endPoint: .center))
                }
                .frame(width: 21 * unit, height: (272 - abs(position) * 36) * unit)
                .offset(y: 146 * unit)
                .rotationEffect(.degrees(position * 26))
        }
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 11 * unit, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.937, green: 0.494, blue: 0.353),
                                          Color(red: 0.827, green: 0.337, blue: 0.239)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 11 * unit, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                         startPoint: .top, endPoint: .center))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11 * unit, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 3 * unit)
            }
            .frame(width: 162 * unit, height: 52 * unit)
            .offset(y: -18 * unit)
    }

    // MARK: The name

    /// The name on a glass plaque, dark enough that the gold letters keep their edges over
    /// the bristles behind them.
    private var wordmark: some View {
        letters
            .padding(.horizontal, 54 * unit)
            .padding(.vertical, 20 * unit)
            .background { plaque }
            .offset(y: 330 * unit)
    }

    private var letters: some View {
        Text(verbatim: "SCOPA")
            .font(.system(size: 126 * unit, weight: .heavy, design: .serif))
            .tracking(13 * unit)
            .foregroundStyle(LinearGradient(colors: [Self.goldLight, Self.gold, Self.goldDeep],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: Self.deepGreen.opacity(0.7), radius: 6 * unit, y: 4 * unit)
    }

    private var plaque: some View {
        let edge = LinearGradient(colors: [Self.goldLight, Self.gold.opacity(0.6),
                                           Self.goldLight.opacity(0.9)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        return ZStack {
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [Self.green.opacity(0.86),
                                              Self.deepGreen.opacity(0.94)],
                                     startPoint: .top, endPoint: .bottom))
            Capsule(style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.34), location: 0.0),
                    .init(color: .clear, location: 0.45),
                ], startPoint: .top, endPoint: .bottom))
            Capsule(style: .continuous)
                .strokeBorder(edge, lineWidth: 6 * unit)
        }
        .shadow(color: Self.deepGreen.opacity(0.65), radius: 26 * unit, y: 12 * unit)
    }

    // MARK: Edges

    /// The gold border, thinned to a hairline. The system draws its own edge on top, so
    /// this one sits well inside the mask.
    private var frame: some View {
        RoundedRectangle(cornerRadius: 189 * unit, style: .continuous)
            .strokeBorder(LinearGradient(colors: [Self.goldLight, Self.gold.opacity(0.7),
                                                  Self.goldLight.opacity(0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                          lineWidth: 9 * unit)
            .padding(40 * unit)
            .shadow(color: Self.deepGreen.opacity(0.5), radius: 8 * unit, y: 3 * unit)
    }

    /// The highlight that runs across every layer at once, plus the darkening at the
    /// bottom right that gives the pane its thickness.
    private var sheen: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: .white.opacity(0.20), location: 0.00),
                .init(color: .white.opacity(0.05), location: 0.32),
                .init(color: .clear, location: 0.50),
                .init(color: Self.deepGreen.opacity(0.30), location: 1.00),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.softLight)

            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: 1500 * unit, height: 240 * unit)
                .rotationEffect(.degrees(-32))
                .offset(x: -150 * unit, y: -320 * unit)
                .blur(radius: 90 * unit)
        }
        .allowsHitTesting(false)
    }
}

/// Wedges radiating from the centre.
private struct Sunburst: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.09
        let outer = min(rect.width, rect.height) * 0.5
        let half = .pi / Double(count) * 0.44
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
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

/// A blade: flat shoulders, then straight down.
private struct Blade: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.20))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.20))
        p.closeSubpath()
        return p
    }
}

#Preview("App icon") {
    VStack(spacing: 24) {
        IconArtwork(size: 260)
            .clipShape(RoundedRectangle(cornerRadius: 58, style: .continuous))
        HStack(spacing: 18) {
            ForEach([120.0, 80.0, 40.0], id: \.self) { size in
                IconArtwork(size: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }
        }
    }
    .padding(40)
}
