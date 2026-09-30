import SwiftUI

/// The app icon, drawn rather than painted, so it can be re-rendered at any size.
///
/// One card on the felt: the settebello, the seven of coins every hand is fought over,
/// printed on parchment with its coins struck in the icon's metal. Flat, the way a card
/// is printed, with one shadow under it and one lit edge on each coin.
///
/// The colours are written out rather than taken from `Palette`, so the icon does not
/// shift when the interface palette is tuned and this file compiles on its own for
/// `Tools/render-icon.sh`.
struct IconArtwork: View {
    /// The three home-screen appearances iOS asks for. `tinted` is drawn in grey on black
    /// because the system maps a grey icon through the colour the player picked: light
    /// pixels take the tint, dark ones stay dark.
    enum Appearance { case light, dark, tinted }

    /// The metal the coins are struck in. `classic` is the one on the App Store; the others
    /// are won on the ranked ladder, one per league from Silver up. Each keeps what the one
    /// below it has: a gilt edge from Gold, a double frame in the metal from Platinum, a
    /// stone in every coin and glints from Diamond, and rubies and a terracotta line at
    /// Maestro.
    enum Finish: String, CaseIterable { case classic, silver, gold, platinum, diamond, maestro }

    /// Everything is expressed against this, so 1024 and 40 draw the same picture.
    var size: CGFloat
    var appearance: Appearance = .light
    var finish: Finish = .classic

    private var unit: CGFloat { size / 1024 }
    private var rank: Int { Finish.allCases.firstIndex(of: finish) ?? 0 }

    /// The cloth and the metal for one finish. The cloth runs from `felt` at the top to
    /// `feltDeep` at the foot; the dark icon uses `night` and `nightDeep` instead.
    private struct Tones {
        let felt: Color
        let feltDeep: Color
        let night: Color
        let nightDeep: Color
        let metalLight: Color
        let metal: Color
        let metalDeep: Color
    }

    /// The tinted icon strikes its coins near white, so they take the full tint.
    private var tones: Tones {
        guard appearance != .tinted else { return Self.tintable }
        switch finish {
        case .classic: return Self.bottleGreen
        case .silver: return Self.slate
        case .gold: return Self.claret
        case .platinum: return Self.teal
        case .diamond: return Self.navy
        case .maestro: return Self.ebony
        }
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }

    private static let gold = rgb(0.851, 0.604, 0.153)
    private static let goldLight = rgb(0.973, 0.808, 0.380)
    private static let goldDeep = rgb(0.604, 0.388, 0.063)
    private static let terracotta = rgb(0.808, 0.353, 0.243)
    private static let ruby = rgb(0.702, 0.114, 0.157)
    private static let sky = rgb(0.694, 0.859, 0.965)
    private static let parchment = rgb(0.957, 0.925, 0.851)
    private static let parchmentEdge = rgb(0.788, 0.729, 0.604)
    private static let charcoal = rgb(0.157, 0.176, 0.165)
    private static let charcoalEdge = rgb(0.078, 0.086, 0.082)

    private static let bottleGreen = Tones(
        felt: rgb(0.063, 0.345, 0.216), feltDeep: rgb(0.031, 0.247, 0.149),
        night: rgb(0.031, 0.102, 0.067), nightDeep: rgb(0.008, 0.035, 0.024),
        metalLight: goldLight, metal: gold, metalDeep: goldDeep)
    private static let slate = Tones(
        felt: rgb(0.196, 0.239, 0.298), feltDeep: rgb(0.106, 0.137, 0.184),
        night: rgb(0.063, 0.075, 0.098), nightDeep: rgb(0.016, 0.024, 0.035),
        metalLight: rgb(0.980, 0.984, 0.992), metal: rgb(0.722, 0.749, 0.788),
        metalDeep: rgb(0.376, 0.408, 0.455))
    private static let claret = Tones(
        felt: rgb(0.412, 0.086, 0.122), feltDeep: rgb(0.271, 0.039, 0.071),
        night: rgb(0.122, 0.027, 0.039), nightDeep: rgb(0.043, 0.008, 0.016),
        metalLight: goldLight, metal: gold, metalDeep: goldDeep)
    private static let teal = Tones(
        felt: rgb(0.059, 0.259, 0.302), feltDeep: rgb(0.027, 0.161, 0.200),
        night: rgb(0.020, 0.071, 0.082), nightDeep: rgb(0.004, 0.027, 0.035),
        metalLight: rgb(0.992, 0.996, 1.000), metal: rgb(0.784, 0.824, 0.859),
        metalDeep: rgb(0.380, 0.447, 0.518))
    private static let navy = Tones(
        felt: rgb(0.086, 0.141, 0.345), feltDeep: rgb(0.035, 0.071, 0.212),
        night: rgb(0.031, 0.043, 0.106), nightDeep: rgb(0.008, 0.012, 0.043),
        metalLight: rgb(1.000, 1.000, 1.000), metal: rgb(0.698, 0.839, 0.949),
        metalDeep: rgb(0.259, 0.431, 0.612))
    private static let ebony = Tones(
        felt: rgb(0.106, 0.094, 0.082), feltDeep: rgb(0.039, 0.035, 0.031),
        night: rgb(0.051, 0.047, 0.043), nightDeep: rgb(0.008, 0.008, 0.008),
        metalLight: rgb(1.000, 0.886, 0.541), metal: gold, metalDeep: goldDeep)
    private static let tintable = Tones(
        felt: .black, feltDeep: .black, night: .black, nightDeep: .black,
        metalLight: .white, metal: rgb(0.925, 0.925, 0.925), metalDeep: rgb(0.560, 0.560, 0.560))

    var body: some View {
        ZStack {
            ground
            card
                .rotationEffect(.degrees(-6))
                .offset(x: 4 * unit, y: -6 * unit)
            if rank >= 4 { glints }
        }
        .frame(width: size, height: size)
        .clipped()
        .grayscale(appearance == .tinted ? 1 : 0)
    }

    /// The cloth, lit a shade from above. Banked down to near black for the dark icon, and
    /// black for the tinted one.
    @ViewBuilder private var ground: some View {
        switch appearance {
        case .light:
            LinearGradient(colors: [tones.felt, tones.feltDeep], startPoint: .top, endPoint: .bottom)
        case .dark:
            LinearGradient(colors: [tones.night, tones.nightDeep], startPoint: .top, endPoint: .bottom)
        case .tinted:
            Color.black
        }
    }

    // MARK: The card

    private static let cardWidth: CGFloat = 480
    private static let cardHeight: CGFloat = 712
    private var corner: CGFloat { 50 * unit }

    /// The dark and tinted icons turn the paper dark, the way the system's own icons do, so
    /// the coins are what the eye and the tint land on.
    private var night: Bool { appearance != .light }

    /// Parchment rather than white, or charcoal at night.
    private var stock: Color { night ? Self.charcoal : Self.parchment }

    /// The sheet's thickness, showing under its bottom edge. Gilt from Gold up.
    private var edge: Color {
        if rank >= 2 { return tones.metalDeep }
        return night ? Self.charcoalEdge : Self.parchmentEdge
    }

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(edge)
                .offset(y: 14 * unit)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(stock)
            printedFrame
            coins
        }
        .frame(width: Self.cardWidth * unit, height: Self.cardHeight * unit)
        .background { shadow }
    }

    private var shadow: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.black.opacity(night ? 0.5 : 0.30))
            .offset(x: 10 * unit, y: 30 * unit)
            .blur(radius: 16 * unit)
    }

    /// The line printed round the face: terracotta, struck in the metal from Platinum with a
    /// finer line outside it, which Maestro prints in terracotta.
    private var printedFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner - 24 * unit, style: .continuous)
                .strokeBorder(rank >= 3 ? tones.metalDeep : Self.terracotta, lineWidth: 8 * unit)
                .padding(24 * unit)
            if rank >= 3 {
                RoundedRectangle(cornerRadius: corner - 12 * unit, style: .continuous)
                    .strokeBorder(rank >= 5 ? Self.terracotta : tones.metalDeep.opacity(0.7),
                                  lineWidth: 4 * unit)
                    .padding(12 * unit)
            }
        }
    }

    // MARK: The coins

    private static let coin: CGFloat = 120

    /// Two, three, two: the seven as the deck lays it out.
    private static let spots: [CGPoint] = {
        let pair = coin * 0.64, row = coin + 10, rise: CGFloat = 214
        return [CGPoint(x: -pair, y: -rise), CGPoint(x: pair, y: -rise),
                CGPoint(x: -row, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: row, y: 0),
                CGPoint(x: -pair, y: rise), CGPoint(x: pair, y: rise)]
    }()

    private var coins: some View {
        ZStack {
            ForEach(Self.spots.indices, id: \.self) { index in
                coinMark.offset(x: Self.spots[index].x * unit, y: Self.spots[index].y * unit)
            }
        }
    }

    /// The coins-suit rosette: a struck disc with a rim and a ring, eight petals and a boss,
    /// and one lit arc at the top left as the only shading.
    private var coinMark: some View {
        let side = Self.coin * unit
        return ZStack {
            Circle().fill(tones.metalDeep).offset(y: side * 0.04)
            Circle().fill(tones.metal)
            Circle().strokeBorder(tones.metalDeep, lineWidth: side * 0.035)
            Circle().strokeBorder(tones.metalDeep, lineWidth: side * 0.04).padding(side * 0.10)
            ForEach(0..<8, id: \.self) { petal in
                Petal()
                    .fill(tones.metalDeep)
                    .frame(width: side * 0.17, height: side * 0.30)
                    .offset(y: -side * 0.17)
                    .rotationEffect(.degrees(Double(petal) * 45 + 22.5))
            }
            boss(side)
            Circle()
                .trim(from: 0.56, to: 0.76)
                .stroke(tones.metalLight, style: StrokeStyle(lineWidth: side * 0.045, lineCap: .round))
                .padding(side * 0.03)
        }
        .frame(width: side, height: side)
    }

    /// Terracotta enamel, or from Diamond up a cut stone: pale blue, then rubies at Maestro.
    @ViewBuilder private func boss(_ side: CGFloat) -> some View {
        if rank >= 4 {
            let stone = rank >= 5 ? Self.ruby : Self.sky
            ZStack {
                Stone().fill(stone)
                // The table facet, a paler octagon inside the girdle.
                Stone().fill(.white.opacity(0.38)).scaleEffect(0.56)
                Stone().stroke(tones.metalDeep, lineWidth: side * 0.025)
            }
            .frame(width: side * 0.30, height: side * 0.30)
        } else {
            Circle().fill(Self.terracotta).frame(width: side * 0.20)
        }
    }

    // MARK: Glints

    /// Four-point glints caught on the card's corners, from Diamond up, and a third at Maestro.
    private var glints: some View {
        ZStack {
            ForEach(Array(Self.glintSpots.prefix(rank >= 5 ? 3 : 2).enumerated()), id: \.offset) { _, spot in
                Glint()
                    .fill(tones.metalLight)
                    .frame(width: spot.z * unit, height: spot.z * unit)
                    .position(x: spot.x * unit, y: spot.y * unit)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    /// Where the glints sit on a 1024 icon, and how big each is.
    private static let glintSpots: [(x: CGFloat, y: CGFloat, z: CGFloat)] = [
        (262, 190, 88), (786, 838, 72), (712, 142, 52),
    ]
}

/// A petal, pointed at the tip and round at the foot.
private struct Petal: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX + r.width * 0.25, y: r.midY + r.height * 0.18))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX - r.width * 0.25, y: r.midY + r.height * 0.18))
        p.closeSubpath()
        return p
    }
}

/// A cut stone seen from above: an octagon.
private struct Stone: Shape {
    func path(in r: CGRect) -> Path {
        let centre = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        var p = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 + .pi / 8
            let point = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            if index == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// A four-pointed star with hollowed sides.
private struct Glint: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<4 {
            let angle = Double(index) * .pi / 2 - .pi / 2
            let tip = CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer)
            let next = Double(index + 1) * .pi / 2 - .pi / 2
            let following = CGPoint(x: centre.x + cos(next) * outer, y: centre.y + sin(next) * outer)
            if index == 0 { path.move(to: tip) }
            path.addQuadCurve(to: following, control: centre)
        }
        path.closeSubpath()
        return path
    }
}

#Preview("The ladder's icons") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 18) {
        ForEach(IconArtwork.Finish.allCases, id: \.self) { finish in
            IconArtwork(size: 110, finish: finish)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
    .padding(30)
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
