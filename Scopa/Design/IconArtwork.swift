import SwiftUI

/// The app icon, drawn rather than painted, so it can be re-rendered at any size.
///
/// Emerald under a gold frame, a burst of rays, three cards fanned above a gold
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

    /// The metal the icon is struck in. `classic` is the one on the App Store; the others
    /// are won on the ranked ladder, one per league from Silver up. Each keeps what the one
    /// below it has: a second line in the frame from Platinum, glints from Diamond, a
    /// terracotta line and stronger light at Maestro, and at Gran Maestro a laurel round the
    /// fan, on the house's own emerald taken nearly to black. See `IconLaurel`.
    ///
    /// `patron` is off the ladder: the no-ads purchase gives it. Lapis and gold leaf, with the
    /// patron's crest on the coin, Ravenna's stars and tesserae where the others have light,
    /// and every gloss taken off in favour of engraved lines. See `PatronCrest`.
    ///
    /// `visconti` is the album's: the Tarocchi volume gives it. The same picture laid on a
    /// tarot card's gold leaf, punched and ruled like the Visconti deck's, the name on
    /// ultramarine, and engraved like the patron's. See `ViscontiLeaf`.
    enum Finish: String, CaseIterable { case classic, silver, gold, platinum, diamond, maestro, granMaestro, patron, visconti }

    /// Everything is expressed against this, so 1024 and 180 draw the same picture.
    var size: CGFloat
    var appearance: Appearance = .light
    var finish: Finish = .classic

    private var unit: CGFloat { size / 1024 }

    /// The ground and the metal for one finish.
    private struct Tones {
        let groundLight: Color
        let ground: Color
        let groundDeep: Color
        let night: Color
        let metalLight: Color
        let metal: Color
        let metalDeep: Color
        /// How bright the burst behind the cards is.
        var rays: Double = 0.42
    }

    private var tones: Tones {
        switch finish {
        case .classic:
            Tones(groundLight: Self.lightGreen, ground: Self.green, groundDeep: Self.deepGreen, night: Self.night,
                  metalLight: Self.goldLight, metal: Self.gold, metalDeep: Self.goldDeep)
        case .silver:
            Tones(groundLight: rgb(0.290, 0.345, 0.408), ground: rgb(0.153, 0.192, 0.243),
                  groundDeep: rgb(0.059, 0.078, 0.106), night: rgb(0.020, 0.027, 0.039),
                  metalLight: rgb(0.965, 0.973, 0.984), metal: rgb(0.722, 0.749, 0.788),
                  metalDeep: rgb(0.408, 0.435, 0.475))
        case .gold:
            Tones(groundLight: rgb(0.490, 0.157, 0.169), ground: rgb(0.325, 0.078, 0.102),
                  groundDeep: rgb(0.157, 0.031, 0.051), night: rgb(0.063, 0.012, 0.020),
                  metalLight: Self.goldLight, metal: Self.gold, metalDeep: Self.goldDeep, rays: 0.5)
        case .platinum:
            Tones(groundLight: rgb(0.196, 0.361, 0.400), ground: rgb(0.086, 0.208, 0.247),
                  groundDeep: rgb(0.027, 0.090, 0.118), night: rgb(0.008, 0.035, 0.047),
                  metalLight: rgb(0.984, 0.992, 1.000), metal: rgb(0.820, 0.859, 0.898),
                  metalDeep: rgb(0.471, 0.529, 0.600), rays: 0.5)
        case .diamond:
            Tones(groundLight: rgb(0.192, 0.267, 0.459), ground: rgb(0.078, 0.129, 0.271),
                  groundDeep: rgb(0.020, 0.039, 0.110), night: rgb(0.008, 0.012, 0.043),
                  metalLight: rgb(1.000, 1.000, 1.000), metal: rgb(0.800, 0.902, 0.965),
                  metalDeep: rgb(0.400, 0.557, 0.698), rays: 0.56)
        case .maestro:
            Tones(groundLight: rgb(0.212, 0.196, 0.176), ground: rgb(0.106, 0.094, 0.082),
                  groundDeep: rgb(0.035, 0.031, 0.027), night: rgb(0.012, 0.012, 0.012),
                  metalLight: rgb(1.000, 0.886, 0.541), metal: Self.gold, metalDeep: Self.goldDeep, rays: 0.72)
        case .granMaestro:
            Tones(groundLight: rgb(0.086, 0.208, 0.149), ground: rgb(0.031, 0.110, 0.075),
                  groundDeep: rgb(0.008, 0.043, 0.027), night: rgb(0.004, 0.016, 0.010),
                  metalLight: rgb(1.000, 0.886, 0.541), metal: Self.gold, metalDeep: Self.goldDeep, rays: 0.78)
        case .patron:
            Tones(groundLight: rgb(0.212, 0.318, 0.624), ground: rgb(0.106, 0.176, 0.427),
                  groundDeep: rgb(0.039, 0.063, 0.204), night: rgb(0.016, 0.024, 0.075),
                  metalLight: Self.goldLight, metal: Self.gold, metalDeep: Self.goldDeep, rays: 0)
        case .visconti:
            // The ground is the leaf's own, in `ViscontiLeaf`; these are what it casts.
            Tones(groundLight: ViscontiTone.leafLight, ground: ViscontiTone.leaf,
                  groundDeep: rgb(0.290, 0.169, 0.051), night: rgb(0.122, 0.071, 0.020),
                  metalLight: Self.goldLight, metal: Self.gold, metalDeep: rgb(0.420, 0.267, 0.071), rays: 0)
        }
    }

    private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }

    private var isPatron: Bool { finish == .patron }
    private var isVisconti: Bool { finish == .visconti }
    /// Drawn with engraved lines rather than lit: the two that are off the ladder.
    private var isEngraved: Bool { isPatron || isVisconti }

    /// How far up the ladder the finish is. The patron's and the album's are not on it.
    private var finishRank: Int { isEngraved ? 0 : Finish.allCases.firstIndex(of: finish) ?? 0 }

    private static let deepGreen = Color(red: 0.020, green: 0.250, blue: 0.137)
    private static let green = Color(red: 0.055, green: 0.447, blue: 0.247)
    private static let lightGreen = Color(red: 0.200, green: 0.620, blue: 0.353)
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
            if isPatron { PatronVault(unit: unit, tones: vaultTones) }
            if isVisconti { ViscontiLeaf(unit: unit) }
            if finishRank >= 6 { IconLaurel(unit: unit, light: tones.metalLight, metal: tones.metal, deep: tones.metalDeep) }
            // Scaled and lifted as one group, so the plaque sits under the picture and the
            // fan keeps its proportions.
            ZStack {
                if !isEngraved { rays }
                fan
                broom
            }
            .scaleEffect(0.84)
            .offset(y: -112 * unit)
            wordmark
        }
        .frame(width: size, height: size)
        .clipped()
        .overlay {
            if isPatron { patronFrame } else if isVisconti { ViscontiFrame(unit: unit) } else { frame }
        }
        .overlay { if finishRank >= 4 { glints } }
        .overlay { if !isEngraved { sheen } }
    }

    // MARK: Ground

    /// Emerald lit from the top left — banked down for the dark icon, and taken to
    /// black for the tinted one so the cards and the broom are what the tint lands on.
    private var ground: some View {
        ZStack {
            switch appearance {
            case .light where isVisconti:
                // Leaf darkens where the gesso under it was laid thick, never lightens to white.
                LinearGradient(colors: [ViscontiTone.leafLight, ViscontiTone.leaf, ViscontiTone.leafDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [tones.groundDeep.opacity(0.4), .clear],
                               center: UnitPoint(x: 0.92, y: 1.04),
                               startRadius: 0, endRadius: 720 * unit)
            case .light:
                LinearGradient(colors: [tones.groundLight, tones.ground, tones.groundDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.26), .clear],
                               center: UnitPoint(x: 0.14, y: 0.02),
                               startRadius: 0, endRadius: 620 * unit)
                RadialGradient(colors: [tones.groundDeep.opacity(0.85), .clear],
                               center: UnitPoint(x: 0.92, y: 1.04),
                               startRadius: 0, endRadius: 720 * unit)
            case .dark:
                LinearGradient(colors: [tones.ground, tones.groundDeep, tones.night],
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
            .fill(RadialGradient(colors: [tones.metalLight.opacity(tones.rays), tones.metal.opacity(tones.rays * 0.38), .clear],
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
            // The gold hairline inside the card edge, ruled twice on the engraved ones.
            RoundedRectangle(cornerRadius: 22 * unit, style: .continuous)
                .strokeBorder(tones.metal.opacity(0.55), lineWidth: 4 * unit)
                .padding(16 * unit)
            if isEngraved {
                RoundedRectangle(cornerRadius: 16 * unit, style: .continuous)
                    .strokeBorder(tones.metalDeep.opacity(0.45), lineWidth: 2 * unit)
                    .padding(27 * unit)
            }
            mark(for: suit)
            if !isEngraved {
                RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                    .fill(LinearGradient(stops: [
                        .init(color: .white.opacity(0.5), location: 0.0),
                        .init(color: .clear, location: 0.4),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            RoundedRectangle(cornerRadius: 30 * unit, style: .continuous)
                .strokeBorder(edge(for: suit), lineWidth: 5 * unit)
        }
        .frame(width: 256 * unit, height: 380 * unit)
        .shadow(color: tones.groundDeep.opacity(0.55), radius: 28 * unit, y: 14 * unit)
    }

    /// The specular edge each card carries, in gold for the coin card at the front.
    private func edge(for suit: IconSuit) -> LinearGradient {
        let colours: [Color] = suit == .coin || isEngraved
            ? [tones.metalLight, tones.metal.opacity(0.55), tones.metalLight.opacity(0.9)]
            : [.white, .white.opacity(0.4), .white.opacity(0.8)]
        return LinearGradient(colors: colours, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private func mark(for suit: IconSuit) -> some View {
        switch suit {
        case .coin where isPatron:
            PatronCrest(size: 190 * unit).offset(y: -40 * unit)
        case .coin where isVisconti:
            ViscontiCoin(unit: unit, light: tones.metalLight, metal: tones.metal, deep: tones.metalDeep)
                .offset(y: -40 * unit)
        case .coin: coinMark
        case .cup: cupMark
        case .sword: swordMark
        }
    }

    private var coinMark: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [tones.metalLight, tones.metal],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(tones.metalDeep.opacity(0.8), lineWidth: 8 * unit).padding(24 * unit)
            Circle().fill(tones.metalDeep.opacity(0.8)).frame(width: 24 * unit)
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
            if !isEngraved {
                Capsule().fill(.white.opacity(0.45))
                    .frame(width: 72 * unit, height: 14 * unit)
                    .offset(y: 17 * unit)
            }
        }
        .offset(y: -40 * unit)
    }

    private var swordMark: some View {
        VStack(spacing: 0) {
            Blade().fill(Self.steel).frame(width: 58 * unit, height: 126 * unit)
            Capsule().fill(tones.metal).frame(width: 146 * unit, height: 19 * unit)
            Rectangle().fill(Self.steel).frame(width: 22 * unit, height: 29 * unit)
            Circle().fill(tones.metal).frame(width: 32 * unit)
        }
        .offset(y: -46 * unit)
    }

    // MARK: The broom

    /// The broom the game is named after, in front of the fan.
    private var broom: some View {
        ZStack {
            if !isEngraved {
                Circle()
                    .fill(tones.metal.opacity(0.30))
                    .frame(width: 500 * unit, height: 500 * unit)
                    .offset(y: 130 * unit)
                    .blur(radius: 100 * unit)
            }
            handle
            bristles
            collar
        }
        .rotationEffect(.degrees(74))
        .offset(x: 62 * unit, y: 137 * unit)
        .shadow(color: tones.groundDeep.opacity(0.6), radius: 30 * unit, y: 18 * unit)
    }

    private var handle: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(red: 0.271, green: 0.235, blue: 0.204), Self.ink],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay {
                if isEngraved {
                    // A gold ferrule at the end, rather than a gloss down the length.
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(tones.metal).frame(height: 16 * unit)
                            .overlay { Rectangle().strokeBorder(tones.metalDeep, lineWidth: 2 * unit) }
                            .padding(.bottom, 26 * unit)
                    }
                    .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                             startPoint: .leading, endPoint: .center))
                }
            }
            .overlay { Capsule().strokeBorder(.white.opacity(isEngraved ? 0.12 : 0.25), lineWidth: 3 * unit) }
            .frame(width: 44 * unit, height: 240 * unit)
            .offset(y: -190 * unit)
    }

    /// Slats hinged just under the collar, narrow enough to separate at the tips.
    private var bristles: some View {
        let count = 11
        return ForEach(0..<count, id: \.self) { index in
            let position = Double(index) / Double(count - 1) * 2 - 1
            Capsule()
                .fill(LinearGradient(colors: [tones.metal, tones.metalLight],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    if isEngraved {
                        // Each slat engraved down its middle and edged, like the crest's.
                        Capsule().strokeBorder(tones.metalDeep.opacity(0.75), lineWidth: 2 * unit)
                        Rectangle().fill(tones.metalDeep.opacity(0.5)).frame(width: 2 * unit).padding(.vertical, 18 * unit)
                    } else {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                 startPoint: .topLeading, endPoint: .center))
                    }
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
                if isEngraved {
                    // A row of gold beads round the band, as on the crest's collar.
                    MidLine(inset: 18 * unit)
                        .stroke(tones.metalLight, style: StrokeStyle(lineWidth: 9 * unit, lineCap: .round,
                                                                    dash: [0, 19 * unit]))
                } else {
                    RoundedRectangle(cornerRadius: 11 * unit, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                             startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11 * unit, style: .continuous)
                    .strokeBorder(isEngraved ? tones.metalDeep : .white.opacity(0.4), lineWidth: 3 * unit)
            }
            .frame(width: 162 * unit, height: 52 * unit)
            .offset(y: -18 * unit)
    }

    // MARK: The name

    /// The name on a glass plaque, dark enough that the gold letters keep their edges over
    /// the bristles behind them.
    private var wordmark: some View {
        letters
            .padding(.horizontal, 44 * unit)
            .padding(.vertical, 10 * unit)
            .background { plaque }
            .offset(y: 318 * unit)
    }

    private var letters: some View {
        Text(verbatim: "SCOPA")
            .font(.system(size: 172 * unit, weight: .black, design: .serif))
            .tracking(8 * unit)
            .foregroundStyle(LinearGradient(colors: [tones.metalLight, tones.metal, tones.metalDeep],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: tones.groundDeep.opacity(0.7), radius: 6 * unit, y: 4 * unit)
    }

    private var plaque: some View {
        let edge = LinearGradient(colors: [tones.metalLight, tones.metal.opacity(0.6),
                                           tones.metalLight.opacity(0.9)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        return ZStack {
            Capsule(style: .continuous).fill(plaqueFill)
            if isEngraved {
                // Ruled twice, the inner line engraved, where the others have glass.
                Capsule(style: .continuous)
                    .strokeBorder(tones.metal.opacity(0.7), lineWidth: 2.5 * unit)
                    .padding(13 * unit)
            } else {
                Capsule(style: .continuous)
                    .fill(LinearGradient(stops: [
                        .init(color: .white.opacity(0.34), location: 0.0),
                        .init(color: .clear, location: 0.45),
                    ], startPoint: .top, endPoint: .bottom))
            }
            Capsule(style: .continuous)
                .strokeBorder(edge, lineWidth: 6 * unit)
        }
        .shadow(color: tones.groundDeep.opacity(0.65), radius: 26 * unit, y: 12 * unit)
    }

    /// Glass in the ground's own colour, or ultramarine on the Visconti's leaf, where the
    /// ground's colour would be gold on gold.
    private var plaqueFill: LinearGradient {
        let colours = isVisconti
            ? [ViscontiTone.ultramarineLight, ViscontiTone.ultramarine, ViscontiTone.ultramarineDeep]
            : [tones.ground.opacity(0.86), tones.groundDeep.opacity(0.94)]
        return LinearGradient(colors: colours, startPoint: .top, endPoint: .bottom)
    }

    // MARK: Edges

    /// The gold border, thinned to a hairline. The system draws its own edge on top, so
    /// this one sits well inside the mask.
    private var frame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 189 * unit, style: .continuous)
                .strokeBorder(LinearGradient(colors: [tones.metalLight, tones.metal.opacity(0.7),
                                                      tones.metalLight.opacity(0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 9 * unit)
                .padding(40 * unit)
            // A second line inside the first from Platinum, in terracotta at Maestro.
            if finishRank >= 3 {
                RoundedRectangle(cornerRadius: 168 * unit, style: .continuous)
                    .strokeBorder(finishRank >= 5 ? Self.terracotta : tones.metal.opacity(0.75),
                                  lineWidth: 4 * unit)
                    .padding(62 * unit)
            }
        }
        .shadow(color: tones.groundDeep.opacity(0.5), radius: 8 * unit, y: 3 * unit)
    }

    /// The patron's border: the same gold hairline, a row of pearls inside it, and an
    /// engraved line inside those. Detail in the drawing, where the ladder has light.
    private var patronFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 189 * unit, style: .continuous)
                .strokeBorder(LinearGradient(colors: [tones.metalLight, tones.metal.opacity(0.75),
                                                      tones.metalLight.opacity(0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 9 * unit)
                .padding(40 * unit)
            RoundedRectangle(cornerRadius: 172 * unit, style: .continuous)
                .inset(by: 4 * unit)
                .stroke(tones.metal, style: StrokeStyle(lineWidth: 8 * unit, lineCap: .round, dash: [0, 21 * unit]))
                .padding(55 * unit)
            RoundedRectangle(cornerRadius: 156 * unit, style: .continuous)
                .strokeBorder(tones.metalDeep.opacity(0.9), lineWidth: 3 * unit)
                .padding(71 * unit)
        }
        .shadow(color: tones.night.opacity(0.6), radius: 6 * unit, y: 3 * unit)
    }

    /// The ground's three tones, for the patron's vault laid over it.
    private var vaultTones: PatronVault.Tones {
        PatronVault.Tones(light: tones.groundLight, deep: tones.groundDeep, night: tones.night)
    }

    /// Four-point glints caught on the frame and the rays, from Diamond up.
    private var glints: some View {
        ZStack {
            ForEach(Array(Self.glintSpots.enumerated()), id: \.offset) { _, spot in
                Glint()
                    .fill(.white)
                    .frame(width: spot.z * unit, height: spot.z * unit)
                    .shadow(color: tones.metalLight.opacity(0.9), radius: 14 * unit)
                    .position(x: spot.x * unit, y: spot.y * unit)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    /// Where the glints sit on a 1024 icon, and how big each is.
    private static let glintSpots: [(x: CGFloat, y: CGFloat, z: CGFloat)] = [
        (132, 118, 92), (884, 214, 64), (802, 880, 74), (218, 606, 48),
    ]

    /// The highlight that runs across every layer at once, plus the darkening at the
    /// bottom right that gives the pane its thickness.
    private var sheen: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: .white.opacity(0.20), location: 0.00),
                .init(color: .white.opacity(0.05), location: 0.32),
                .init(color: .clear, location: 0.50),
                .init(color: tones.groundDeep.opacity(0.30), location: 1.00),
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

/// The patron's ground under the picture: lapis set as tesserae, row on row, and gold stars
/// of every size scattered over it, as on Galla Placidia's vault. Struck gold, never light.
/// Scattered rather than ringed: twelve stars in a circle on blue is a flag.
private struct PatronVault: View {
    struct Tones {
        let light: Color
        let deep: Color
        let night: Color
    }

    let unit: CGFloat
    let tones: Tones

    var body: some View {
        Canvas { context, size in
            tesserae(&context, size)
            // Inside the frame's engraved line, so no star sits out on the bare edge.
            context.clip(to: Path(roundedRect: CGRect(x: 74 * unit, y: 74 * unit, width: 876 * unit, height: 876 * unit),
                                  cornerRadius: 152 * unit, style: .continuous))
            stars(&context)
        }
        .allowsHitTesting(false)
    }

    /// Rows of small glass squares, each a shade off its neighbours, with dark grout between.
    private func tesserae(_ context: inout GraphicsContext, _ size: CGSize) {
        var random = VaultRandom(seed: 0x9A11A)
        let height = 22 * unit
        let grout = 2.6 * unit
        var lighter = Path(), darker = Path(), joints = Path()
        var y: CGFloat = 0
        while y < size.height {
            var x = -CGFloat(random.unit()) * 20 * unit
            while x < size.width {
                let width = (19 + CGFloat(random.unit()) * 6) * unit
                let tile = CGRect(x: x + grout / 2, y: y + grout / 2, width: width - grout, height: height - grout)
                let shade = random.unit()
                if shade < 0.36 { darker.addRect(tile) } else if shade > 0.7 { lighter.addRect(tile) }
                joints.addRect(CGRect(x: x, y: y, width: grout / 2, height: height))
                x += width
            }
            joints.addRect(CGRect(x: 0, y: y, width: size.width, height: grout / 2))
            y += height
        }
        context.fill(darker, with: .color(tones.night.opacity(0.13)))
        context.fill(lighter, with: .color(tones.light.opacity(0.11)))
        context.fill(joints, with: .color(tones.night.opacity(0.26)))
    }

    /// One star to a cell of a loose grid, nudged off it and sized at random, most of them small.
    private func stars(_ context: inout GraphicsContext) {
        var random = VaultRandom(seed: 0x57A125)
        let cell = 104.0
        for row in 0..<10 {
            for column in 0..<10 {
                let x = (Double(column) + 0.15 + random.unit() * 0.7) * cell
                let y = (Double(row) + 0.15 + random.unit() * 0.7) * cell
                let size = random.unit()
                guard size > 0.18 else { continue }
                let radius = size > 0.88 ? 23 : 8 + size * 10
                PatronStar.strike(in: &context, at: CGPoint(x: x * unit, y: y * unit), radius: radius * unit,
                                  faceted: radius * unit > 4, opacity: size > 0.9 ? 1 : 0.8)
            }
        }
    }
}

/// SplitMix64, so the tesserae and the leaf are laid the same way on every render.
struct VaultRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func unit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

/// A horizontal line across the middle, for a row of beads.
private struct MidLine: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
        return path
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
