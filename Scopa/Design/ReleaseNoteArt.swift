import ScopaCore
import ScopaRewards
import SwiftUI

/// The drawing at the top of a "What's new" page, made from the game's own pieces: its
/// cards, medals, packs and cloths. Nothing is imported, and nothing here is a screenshot,
/// so a page never shows a screen that has since changed.
struct ReleaseNoteArt: View {
    /// One drawing per kind of news. A release adds a case when nothing here fits.
    enum Kind: Hashable {
        case journey, lobby, volumes, wheel, medals, board, house, cloths, oneTap, videos, codes
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .journey: JourneySketch()
        case .lobby: LobbySketch()
        case .volumes: volumes
        case .wheel: WheelSketch()
        case .medals: medals
        case .board: BoardSketch()
        case .house: house
        case .cloths: cloths
        case .oneTap: OneTapSketch()
        case .videos: videos
        case .codes: CouponTicket()
        }
    }

    /// The settebello four times, once in each volume's deck, fanned.
    private var volumes: some View {
        ZStack {
            ForEach(Array(Volume.allCases.enumerated()), id: \.offset) { place, volume in
                let lean = CGFloat(place) - 1.5
                VStack(spacing: 8) {
                    CardView(card: .settebello, width: 62)
                        .environment(\.cardTheme, volume.theme)
                    Text(verbatim: volume.numeral)
                        .font(.system(size: 12, weight: .heavy, design: .serif))
                        .foregroundStyle(Palette.goldLight)
                }
                .rotationEffect(.degrees(Double(lean) * 7))
                .offset(x: lean * 58, y: abs(lean) * 6)
            }
        }
    }

    /// The medal as it grows up the ladder, and the icon struck in gold.
    private var medals: some View {
        HStack(alignment: .center, spacing: 16) {
            LeagueMedal(league: League.bronze.rawValue, size: 44)
            LeagueMedal(league: League.gold.rawValue, size: 62)
            LeagueMedal(league: League.maestro.rawValue, size: 80)
            LadderIconArt(icon: .gold, size: 64)
                .shadow(color: Palette.ink.opacity(0.35), radius: 6, y: 4)
        }
    }

    /// A few seconds of searching, and a bot offering to sit down.
    private var house: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Palette.onTableSoft.opacity(0.3), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: 0.17)
                    .stroke(Palette.goldLight, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "0:05")
                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.onTable)
            }
            .frame(width: 76, height: 76)
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.onTableSoft)
            BotFace(tint: Palette.seat(3), size: 84)
        }
    }

    /// The newest weaves, each on another cloth.
    private var cloths: some View {
        let weaves = Array(Tapis.allCases.suffix(3))
        let felts = Array(TableFelt.allCases.suffix(3))
        return ZStack {
            ForEach(0..<min(weaves.count, felts.count), id: \.self) { place in
                let lean = CGFloat(place) - 1
                TapisSwatch(tapis: weaves[place], felt: felts[place], height: 150)
                    .rotationEffect(.degrees(Double(lean) * 8))
                    .offset(x: lean * 74, y: abs(lean) * 8)
                    .shadow(color: Palette.ink.opacity(0.3), radius: 8, y: 5)
                    .zIndex(-Double(abs(lean)))
            }
        }
    }

    /// A video, and what it pays.
    private var videos: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Palette.ink.opacity(0.55))
                .frame(width: 110, height: 76)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.cream)
                }
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.gold.opacity(0.45)) }
            VStack(spacing: 6) {
                ZStack {
                    ForEach(0..<3, id: \.self) { coin in
                        DenariMark(size: 38).offset(x: CGFloat(coin) * 9, y: CGFloat(coin) * -7)
                    }
                }
                .frame(width: 60, height: 52)
                Text(verbatim: "+100")
                    .font(.display(26))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldSheen)
            }
        }
    }
}

/// The campaign's road: a lane winding up the page through four stages, the first two
/// starred, the third the one being played, the last still locked, and the region's prize
/// waiting past it.
private struct JourneySketch: View {
    private let size = CGSize(width: 290, height: 160)
    /// Where each stage sits, as a share of the size, and the stars it has won.
    private let stages: [(spot: UnitPoint, stars: Int?)] = [
        (UnitPoint(x: 0.08, y: 0.78), 3), (UnitPoint(x: 0.36, y: 0.62), 2),
        (UnitPoint(x: 0.6, y: 0.4), 0), (UnitPoint(x: 0.82, y: 0.6), nil),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Lane()
                .stroke(Palette.cream.opacity(0.18), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            Lane()
                .stroke(Palette.cream.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 6]))
            ForEach(stages.indices, id: \.self) { index in
                stage(index)
                    .position(x: stages[index].spot.x * size.width, y: stages[index].spot.y * size.height)
            }
            PackArt(tier: .velluto, width: 26)
                .position(x: size.width * 0.99, y: size.height * 0.2)
        }
        .frame(width: size.width, height: size.height)
    }

    private func stage(_ index: Int) -> some View {
        let stars = stages[index].stars
        let isCurrent = stars == 0
        return VStack(spacing: 3) {
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { star in
                    Star(points: 5)
                        .fill(star < (stars ?? 0) ? Palette.goldLight : Palette.onTableSoft.opacity(0.3))
                        .frame(width: 11, height: 11)
                }
            }
            .opacity(stars == nil ? 0 : 1)
            Circle()
                .fill(stars == nil ? AnyShapeStyle(Palette.ink.opacity(0.45)) : AnyShapeStyle(Palette.goldSheen))
                .frame(width: 34, height: 34)
                .overlay {
                    if stars == nil {
                        Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Palette.onTableSoft)
                    } else {
                        Text(verbatim: "\(index + 1)")
                            .font(.system(size: 15, weight: .heavy, design: .serif))
                            .foregroundStyle(Palette.ink.opacity(0.8))
                    }
                }
                .overlay { Circle().strokeBorder(isCurrent ? Palette.terracotta : Palette.goldDeep, lineWidth: isCurrent ? 3 : 1.5) }
                .shadow(color: Palette.ink.opacity(0.35), radius: 4, y: 3)
        }
        .offset(y: -10)
    }

    /// The road, through the four stages and on to the prize.
    private struct Lane: Shape {
        func path(in r: CGRect) -> Path {
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
            var path = Path()
            path.move(to: at(0.0, 0.92))
            path.addQuadCurve(to: at(0.36, 0.72), control: at(0.2, 0.98))
            path.addQuadCurve(to: at(0.6, 0.5), control: at(0.5, 0.45))
            path.addQuadCurve(to: at(0.82, 0.7), control: at(0.72, 0.78))
            path.addQuadCurve(to: at(0.98, 0.3), control: at(0.98, 0.72))
            return path
        }
    }
}

/// The lobby as it now stands: ranked across the top in its league's metal, the campaign
/// under it, and the quick game, here a saved one, beside the friends.
private struct LobbySketch: View {
    private let league = League.gold.rawValue
    private let width: CGFloat = 236

    var body: some View {
        VStack(spacing: 6) {
            ranked
            campaign
            HStack(spacing: 6) {
                tile("play.fill", "Resume")
                tile("person.2.fill", "With friends")
            }
        }
        .frame(width: width)
    }

    /// The big door: the medal, the win rate, and the division's bar.
    private var ranked: some View {
        let metal = LeagueMetal.league(league)
        return HStack(spacing: 10) {
            LeagueMedal(league: league, size: 46)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ranked")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.onTable)
                    Spacer(minLength: 4)
                    Text(0.62, format: .percent)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.onTableSoft)
                }
                Capsule()
                    .fill(Palette.ink.opacity(0.35))
                    .overlay(alignment: .leading) { Capsule().fill(metal.sheen).frame(width: 96) }
                    .frame(width: 150, height: 5)
            }
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .glassPanel(radius: 14, tint: metal.base.opacity(0.16), hairline: false)
        .overlay {
            LeagueRim(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), league: league, weight: 0.7)
        }
    }

    /// The campaign's door, sea glaze, with the road running across it.
    private var campaign: some View {
        HStack(spacing: 8) {
            Image(systemName: "map.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            Text("Campaign")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { stop in
                    Circle()
                        .fill(stop < 2 ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink.opacity(0.35)))
                        .overlay { Circle().strokeBorder(Palette.goldDeep, lineWidth: 1) }
                        .frame(width: 8, height: 8)
                }
                Image(systemName: "flag.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.terracotta)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 34)
        .glassPanel(radius: 12, tint: Palette.seaGlaze.opacity(0.55))
    }

    private func tile(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 32)
        .glassPanel(radius: 10)
    }
}

/// A wheel of fortune in the house's colours, its pointer on the jackpot.
private struct WheelSketch: View {
    private let size: CGFloat = 136
    private let slices = 8
    private let colours = [Palette.terracotta, Palette.cream, Palette.seaGlaze, Palette.cream]

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.goldSheen)
                .frame(width: size + 16, height: size + 16)
                .shadow(color: Palette.ink.opacity(0.4), radius: 8, y: 5)
            ForEach(0..<slices, id: \.self) { slice in
                Wedge(index: slice, of: slices)
                    .fill(slice == 0 ? Palette.goldLight : colours[slice % colours.count])
                    .overlay { Wedge(index: slice, of: slices).stroke(Palette.goldDeep.opacity(0.6), lineWidth: 1) }
            }
            .frame(width: size, height: size)
            studs
            DenariMark(size: 30)
                .padding(5)
                .background { Circle().fill(Palette.goldDeep) }
            Pointer()
                .fill(Palette.terracotta)
                .overlay { Pointer().stroke(Palette.cream, lineWidth: 1.5) }
                .frame(width: 22, height: 26)
                .offset(y: -(size / 2 + 12))
        }
        // Down a little, so the pointer clears the top of the well.
        .offset(y: 8)
    }

    /// A gold stud at every seam of the rim.
    private var studs: some View {
        ForEach(0..<slices, id: \.self) { slice in
            Circle()
                .fill(Palette.cream)
                .frame(width: 5, height: 5)
                .offset(y: -(size / 2 + 4))
                .rotationEffect(.degrees((Double(slice) - 0.5) * 360 / Double(slices)))
        }
    }

    /// One slice, centred on the top for the first.
    private struct Wedge: Shape {
        let index: Int
        let of: Int

        func path(in r: CGRect) -> Path {
            let step = 360 / Double(of)
            let start = Double(index) * step - 90 - step / 2
            var path = Path()
            path.move(to: CGPoint(x: r.midX, y: r.midY))
            path.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2,
                        startAngle: .degrees(start), endAngle: .degrees(start + step), clockwise: false)
            path.closeSubpath()
            return path
        }
    }

    /// The flag at the top that says where the wheel stopped.
    private struct Pointer: Shape {
        func path(in r: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: r.minX, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// Three rows of the season's board, with the friends' tab picked and each row's win rate.
private struct BoardSketch: View {
    private let rows: [(name: String, league: League, bar: CGFloat, rate: Double)] = [
        ("Giulia", .diamond, 0.8, 0.71), ("Marco", .platinum, 0.55, 0.64), ("Lucia", .gold, 0.35, 0.58),
    ]

    var body: some View {
        VStack(spacing: 8) {
            tabs
            ForEach(Array(rows.enumerated()), id: \.offset) { place, row in
                HStack(spacing: 10) {
                    Text(verbatim: "\(place + 1)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(place == 0 ? Palette.goldLight : Palette.onTableSoft)
                        .frame(width: 14)
                    LeagueMedal(league: row.league.rawValue, size: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: row.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                        Capsule()
                            .fill(Palette.onTableSoft.opacity(0.25))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Palette.goldLight).frame(width: 100 * row.bar)
                            }
                            .frame(width: 100, height: 5)
                    }
                    Spacer(minLength: 0)
                    Text(row.rate, format: .percent)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
        }
        .padding(12)
        .frame(width: 230)
        .glassPanel(radius: 14)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            Text("Everyone")
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity)
            Text("Friends")
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background { Capsule().fill(Palette.goldLight) }
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(3)
        .background { Capsule().fill(Palette.ink.opacity(0.3)) }
        .padding(.bottom, 4)
    }
}

/// A hand of three, the middle card going down at a touch.
private struct OneTapSketch: View {
    private let hand = [Card(.three, of: .cups), Card(.seven, of: .coins), Card(.king, of: .swords)]

    var body: some View {
        ZStack {
            ForEach(Array(hand.enumerated()), id: \.offset) { place, card in
                let lean = CGFloat(place) - 1
                let lifted = place == 1
                CardView(card: card, width: 64, highlighted: lifted)
                    .rotationEffect(.degrees(lifted ? 0 : Double(lean) * 12))
                    .offset(x: lean * 50, y: lifted ? -30 : abs(lean) * 8 + 10)
                    .zIndex(lifted ? 1 : 0)
            }
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.cream)
                .shadow(color: Palette.ink.opacity(0.45), radius: 4, y: 2)
                .offset(x: 18, y: 26)
                .zIndex(2)
        }
    }
}

/// A coupon off the shop's counter: a code being typed, and the stub it pays from.
private struct CouponTicket: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Have a code?")
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Palette.terracotta)
                HStack(spacing: 5) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill(Palette.ink.opacity(0.55)).frame(width: 12, height: 3)
                    }
                    Rectangle().fill(Palette.terracotta).frame(width: 2, height: 18)
                }
            }
            .padding(.horizontal, 18)
            .frame(width: 160, height: 92, alignment: .leading)
            Line()
                .stroke(Palette.linenDeep, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 1.5, height: 76)
            VStack(spacing: 6) {
                DenariMark(size: 30)
                PackArt(tier: .bottega, width: 22)
            }
            .frame(width: 74, height: 92)
        }
        .background { RoundedRectangle(cornerRadius: 10).fill(Palette.stock) }
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1) }
        .rotationEffect(.degrees(-4))
        .shadow(color: Palette.ink.opacity(0.35), radius: 10, y: 6)
    }

    /// The perforation between the ticket and its stub.
    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: r.midX, y: r.minY))
            path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            return path
        }
    }
}
