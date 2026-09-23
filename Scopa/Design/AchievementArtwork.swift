import SwiftUI

/// The twelve Game Center badges, drawn rather than painted so the whole set can be
/// re-rendered at any size and stays one family.
///
/// Every badge is the same tile, bottle green under a gold ring, and only the motif
/// changes. What the badge is worth shows in what the motif is made of: cream at five
/// points, gold at twenty-five and fifty, lit gold over a burst at a hundred. Game Center
/// dims the unearned ones, so there is no locked variant to draw.
///
/// As with `IconArtwork` the colours are written out rather than taken from `Palette`, so
/// this file compiles on its own for `Tools/render-achievements.sh` and a badge already
/// uploaded to App Store Connect cannot shift.
struct AchievementArtwork: View {
    /// A badge, by the id it carries in App Store Connect and in `Achievements.ID`.
    enum Badge: String, CaseIterable {
        case firstScopa = "first_scopa"
        case fiftyScope = "scope_50"
        case firstSettebello = "first_settebello"
        case settebello25 = "settebello_25"
        case firstCappotto = "first_cappotto"
        case firstWin = "first_win"
        case wins25 = "wins_25"
        case wins100 = "wins_100"
        case firstDaily = "first_daily"
        case streak7 = "daily_streak_7"
        case streak30 = "daily_streak_30"
        case firstOnlineWin = "first_online_win"

        /// What the badge is worth, which is also what it is made of.
        var tier: Tier {
            switch self {
            case .firstScopa, .firstSettebello, .firstWin, .firstDaily: .cream
            case .fiftyScope, .settebello25, .firstCappotto, .wins25, .streak7, .firstOnlineWin: .gold
            case .wins100, .streak30: .bright
            }
        }
    }

    /// Five points, twenty-five to fifty, a hundred.
    enum Tier { case cream, gold, bright }

    var badge: Badge
    /// Everything is expressed against this, so 512 and 64 draw the same picture.
    var size: CGFloat

    private var unit: CGFloat { size / 1024 }

    private static let deepGreen = Color(red: 0.055, green: 0.180, blue: 0.114)
    private static let green = Color(red: 0.153, green: 0.310, blue: 0.204)
    private static let lightGreen = Color(red: 0.278, green: 0.451, blue: 0.302)
    private static let cream = Color(red: 0.988, green: 0.973, blue: 0.933)
    private static let stock = Color(red: 0.937, green: 0.906, blue: 0.827)
    private static let linenDeep = Color(red: 0.851, green: 0.796, blue: 0.686)
    private static let terracotta = Color(red: 0.788, green: 0.310, blue: 0.220)
    private static let terracottaLight = Color(red: 0.937, green: 0.494, blue: 0.353)
    private static let gold = Color(red: 0.851, green: 0.643, blue: 0.267)
    private static let goldLight = Color(red: 0.976, green: 0.855, blue: 0.494)
    private static let goldDeep = Color(red: 0.678, green: 0.478, blue: 0.153)
    private static let wood = Color(red: 0.361, green: 0.263, blue: 0.196)
    private static let woodLight = Color(red: 0.451, green: 0.337, blue: 0.251)
    private static let seatBlue = Color(red: 0.404, green: 0.573, blue: 0.667)

    var body: some View {
        ZStack {
            ground
            if badge.tier == .bright { burst }
            motif
                .frame(width: 760 * unit, height: 760 * unit)
            ring
            sheen
        }
        .frame(width: size, height: size)
        .clipped()
    }

    // MARK: The metal

    /// The motif's fill. Everything drawn in it moves together from tier to tier.
    private var metal: LinearGradient {
        switch badge.tier {
        case .cream:
            LinearGradient(colors: [Self.cream, Self.stock], startPoint: .top, endPoint: .bottom)
        case .gold:
            LinearGradient(colors: [Self.goldLight, Self.gold], startPoint: .top, endPoint: .bottom)
        case .bright:
            LinearGradient(colors: [Color(red: 1.0, green: 0.965, blue: 0.831), Self.goldLight, Self.gold],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    /// The metal as one colour, for pieces too small to carry a gradient.
    private var metalFlat: Color {
        switch badge.tier {
        case .cream: Self.cream
        case .gold: Self.gold
        case .bright: Self.goldLight
        }
    }

    private var metalEdge: Color {
        switch badge.tier {
        case .cream: Self.linenDeep
        case .gold, .bright: Self.goldDeep
        }
    }

    // MARK: The tile

    /// Bottle green lit from the top left, the same pane the app icon sits on.
    private var ground: some View {
        ZStack {
            LinearGradient(colors: [Self.lightGreen, Self.green, Self.deepGreen],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.16, y: 0.04),
                           startRadius: 0, endRadius: 600 * unit)
            RadialGradient(colors: [Self.deepGreen.opacity(0.85), .clear],
                           center: UnitPoint(x: 0.90, y: 1.04),
                           startRadius: 0, endRadius: 700 * unit)
        }
    }

    /// Only the hundred-point pair get this, so they are the two badges that glow.
    private var burst: some View {
        Sunburst(count: 22)
            .fill(RadialGradient(colors: [Self.goldLight.opacity(0.42), Self.gold.opacity(0.16), .clear],
                                 center: .center, startRadius: 110 * unit, endRadius: 440 * unit))
            .blur(radius: 9 * unit)
            .frame(width: 980 * unit, height: 980 * unit)
            .blendMode(.plusLighter)
    }

    /// A circle rather than a rounded square: Game Center masks badges both ways, and a
    /// ring inside both survives either.
    private var ring: some View {
        Circle()
            .strokeBorder(LinearGradient(colors: [Self.goldLight, Self.gold.opacity(0.65),
                                                  Self.goldLight.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                          lineWidth: 10 * unit)
            .padding(40 * unit)
            .shadow(color: Self.deepGreen.opacity(0.5), radius: 8 * unit, y: 3 * unit)
    }

    private var sheen: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.18), location: 0.00),
            .init(color: .white.opacity(0.04), location: 0.32),
            .init(color: .clear, location: 0.52),
            .init(color: Self.deepGreen.opacity(0.30), location: 1.00),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }

    // MARK: The motifs

    @ViewBuilder private var motif: some View {
        switch badge {
        case .firstScopa: sweepMotif
        case .fiftyScope: fiftyScopeMotif
        case .firstSettebello: settebello(width: 330 * unit)
        case .settebello25: settebelloFanMotif
        case .firstCappotto: wholeBoard
        case .firstWin: crowned { plate(width: 210 * unit) { coin(112 * unit) } }
        case .wins25: crowned { numeral("25") }
        case .wins100: crowned(reach: 700) { numeral("100", scale: 168) }
        case .firstDaily: dailyDeal
        case .streak7: weekArc
        case .streak30: monthRing
        case .firstOnlineWin: crowned(reach: 700) { duel }
        }
    }

    /// A motif inside the laurel, for the badges that are about winning. `reach` is the
    /// laurel's size in the 1024 grid.
    private func crowned<Content: View>(reach: CGFloat = 690,
                                        @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            laurel(reach * unit)
            content()
        }
    }

    private var sweepMotif: some View {
        VStack(spacing: 34 * unit) {
            broom(scale: 1.05)
            sweptLine(width: 400 * unit)
        }
    }

    private var fiftyScopeMotif: some View {
        VStack(spacing: 8 * unit) {
            broom(scale: 0.82)
            numeral("50")
        }
    }

    private var settebelloFanMotif: some View {
        VStack(spacing: 20 * unit) {
            ZStack {
                settebello(width: 220 * unit).rotationEffect(.degrees(-16)).offset(x: -110 * unit, y: 16 * unit)
                settebello(width: 220 * unit).rotationEffect(.degrees(16)).offset(x: 110 * unit, y: 16 * unit)
                settebello(width: 220 * unit)
            }
            numeral("25", scale: 150)
        }
    }

    /// The table with nothing left on it, which is what a scopa leaves behind.
    private func sweptLine(width: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [metalFlat.opacity(0.0), metalFlat, metalFlat.opacity(0.0)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: 14 * unit)
    }

    /// All four scoring categories taken in one round, as four cards lit at once.
    private var wholeBoard: some View {
        let tilt: [Double] = [-7, 7, -5, 5]
        return VStack(spacing: 26 * unit) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 30 * unit) {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        plate(width: 200 * unit, rim: true) { coin(102 * unit) }
                            .rotationEffect(.degrees(tilt[index]))
                    }
                }
            }
        }
    }

    /// A day's deal: the calendar tile with a card already turned on it.
    private var dailyDeal: some View {
        ZStack {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 48 * unit, style: .continuous)
                    .fill(LinearGradient(colors: [Self.cream, Self.stock],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                UnevenRoundedRectangle(topLeadingRadius: 48 * unit, topTrailingRadius: 48 * unit,
                                       style: .continuous)
                    .fill(LinearGradient(colors: [Self.terracottaLight, Self.terracotta],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 116 * unit)
            }
            .frame(width: 440 * unit, height: 420 * unit)
            .overlay(alignment: .top) {
                HStack(spacing: 150 * unit) {
                    ForEach(0..<2, id: \.self) { _ in
                        Capsule().fill(Self.wood)
                            .frame(width: 34 * unit, height: 76 * unit)
                    }
                }
                .offset(y: -34 * unit)
            }
            .shadow(color: Self.deepGreen.opacity(0.55), radius: 24 * unit, y: 14 * unit)
            .offset(x: -46 * unit, y: -40 * unit)

            plate(width: 200 * unit) { coin(104 * unit) }
                .rotationEffect(.degrees(11))
                .offset(x: 130 * unit, y: 120 * unit)
        }
    }

    /// Seven days in an arc, the last one ringed so it reads as a run just completed.
    private var weekArc: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let sweep = (Double(index) / 6 * 2 - 1) * 68
                Circle()
                    .fill(metal)
                    .overlay { Circle().strokeBorder(metalEdge.opacity(0.5), lineWidth: 5 * unit) }
                    .frame(width: 96 * unit, height: 96 * unit)
                    .overlay {
                        if index == 6 {
                            Circle().strokeBorder(.white.opacity(0.85), lineWidth: 9 * unit)
                                .padding(-20 * unit)
                        }
                    }
                    .offset(y: -300 * unit)
                    .rotationEffect(.degrees(sweep))
            }
        }
        // The arch is drawn across the top half, then dropped so it sits on the tile centre.
        .offset(y: 206 * unit)
        .shadow(color: Self.deepGreen.opacity(0.55), radius: 18 * unit, y: 10 * unit)
    }

    /// Thirty days closed into a ring.
    private var monthRing: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { index in
                Circle()
                    .fill(metal)
                    .frame(width: 40 * unit, height: 40 * unit)
                    .offset(y: -330 * unit)
                    .rotationEffect(.degrees(Double(index) / 30 * 360))
            }
            numeral("30", scale: 200)
        }
        .shadow(color: Self.deepGreen.opacity(0.55), radius: 18 * unit, y: 10 * unit)
    }

    /// Two seats across a table.
    private var duel: some View {
        VStack(spacing: 26 * unit) {
            HStack(spacing: -46 * unit) {
                seat(Self.seatBlue)
                seat(Self.terracotta).zIndex(-1)
            }
            sweptLine(width: 300 * unit)
        }
    }

    private func seat(_ colour: Color) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [colour.opacity(0.95), colour],
                                     startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(metalFlat.opacity(0.9), lineWidth: 10 * unit)
            Circle()
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.4), location: 0.0),
                    .init(color: .clear, location: 0.55),
                ], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: 232 * unit, height: 232 * unit)
        .shadow(color: Self.deepGreen.opacity(0.6), radius: 18 * unit, y: 10 * unit)
    }

    // MARK: Pieces

    /// The broom the icon uses, for the sweeping badges.
    private func broom(scale: CGFloat) -> some View {
        let u = unit * scale
        return ZStack {
            broomHandle(u)
            broomBristles(u)
            broomCollar(u)
        }
        .frame(width: 430 * u, height: 560 * u)
        .shadow(color: Self.deepGreen.opacity(0.6), radius: 24 * unit, y: 14 * unit)
    }

    private func broomHandle(_ u: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Self.woodLight, Self.wood],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay {
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.32), .clear],
                                              startPoint: .leading, endPoint: .center))
            }
            .frame(width: 44 * u, height: 300 * u)
            .offset(y: -218 * u)
    }

    private func broomBristles(_ u: CGFloat) -> some View {
        ForEach(0..<11, id: \.self) { index in
            let position = Double(index) / 10 * 2 - 1
            Capsule()
                .fill(metal)
                .frame(width: 22 * u, height: (252 - abs(position) * 34) * u)
                .offset(y: 142 * u)
                .rotationEffect(.degrees(position * 26))
        }
    }

    private func broomCollar(_ u: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12 * u, style: .continuous)
            .fill(LinearGradient(colors: [Self.terracottaLight, Self.terracotta],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * u, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 3 * u)
            }
            .frame(width: 152 * u, height: 48 * u)
            .offset(y: -24 * u)
    }

    /// A card, cream under a gold hairline. `rim` lights the whole edge.
    private func plate<Face: View>(width: CGFloat, rim: Bool = false,
                                   @ViewBuilder face: () -> Face) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .fill(LinearGradient(colors: [Self.cream, Self.stock],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: width * 0.085, style: .continuous)
                .strokeBorder(Self.gold.opacity(0.55), lineWidth: width * 0.016)
                .padding(width * 0.055)
            face()
            if rim {
                RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                    .strokeBorder(metal, lineWidth: width * 0.035)
            }
        }
        .frame(width: width, height: width * 1.48)
        .shadow(color: Self.deepGreen.opacity(0.55), radius: 20 * unit, y: 12 * unit)
    }

    /// The seven of coins.
    private func settebello(width: CGFloat) -> some View {
        plate(width: width) {
            VStack(spacing: width * 0.04) {
                Text(verbatim: "7")
                    .font(.system(size: width * 0.40, weight: .heavy, design: .serif))
                    .foregroundStyle(LinearGradient(colors: [Self.terracottaLight, Self.terracotta],
                                                    startPoint: .top, endPoint: .bottom))
                coin(width * 0.50)
            }
        }
    }

    /// The rosette the coins suit is built from.
    private func coin(_ diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Self.goldLight, Self.gold],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(Self.goldDeep.opacity(0.75), lineWidth: diameter * 0.05)
                .padding(diameter * 0.13)
            ForEach(0..<8, id: \.self) { petal in
                Capsule()
                    .fill(Self.goldDeep.opacity(0.5))
                    .frame(width: diameter * 0.085, height: diameter * 0.27)
                    .offset(y: -diameter * 0.19)
                    .rotationEffect(.degrees(Double(petal) * 45))
            }
            Circle().fill(Self.goldDeep.opacity(0.65)).frame(width: diameter * 0.15)
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: diameter * 0.03)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Two arcs of leaves, the wreath the winning badges share.
    private func laurel(_ diameter: CGFloat) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { side in
                let mirror: Double = side == 0 ? -1 : 1
                ForEach(0..<8, id: \.self) { index in
                    let along = Double(index) / 7
                    Ellipse()
                        .fill(metal)
                        .overlay {
                            Ellipse().strokeBorder(metalEdge.opacity(0.4), lineWidth: diameter * 0.005)
                        }
                        .frame(width: diameter * (0.098 - along * 0.028),
                               height: diameter * (0.235 - along * 0.075))
                        .rotationEffect(.degrees(-22 * mirror))
                        .offset(y: -diameter * 0.43)
                        .rotationEffect(.degrees((162 - along * 118) * mirror))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Self.deepGreen.opacity(0.5), radius: 16 * unit, y: 9 * unit)
    }

    private func numeral(_ text: String, scale: CGFloat = 190) -> some View {
        Text(verbatim: text)
            .font(.system(size: scale * unit, weight: .heavy, design: .serif))
            .tracking(4 * unit)
            .foregroundStyle(metal)
            .shadow(color: Self.deepGreen.opacity(0.75), radius: 8 * unit, y: 5 * unit)
    }
}

/// Wedges radiating from the centre, the burst from behind the app icon's cards.
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

#Preview("Achievements") {
    let columns = Array(repeating: GridItem(.fixed(150), spacing: 16), count: 4)
    return LazyVGrid(columns: columns, spacing: 16) {
        ForEach(AchievementArtwork.Badge.allCases, id: \.self) { badge in
            AchievementArtwork(badge: badge, size: 150)
                .clipShape(Circle())
        }
    }
    .padding(30)
}
