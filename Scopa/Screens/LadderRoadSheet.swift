import SwiftUI
import ScopaCore
import ScopaRewards

/// The whole ladder as a road: the six leagues in order and Gran Maestro past them, where
/// you stand on it, and what each league gives. Ranked's prizes are won nowhere else, so this
/// is also where ranked explains how it is climbed, and what Gran Maestro's points are for.
struct LadderRoadSheet: View {
    @Bindable var store: TableStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// Set just after the sheet arrives, so the road is seen filling rather than full.
    @State private var drawn = false
    @State private var icon = LadderIcon.current

    /// The rating the ladder last gave. Nil until a ranked game has been played.
    private var rating: Int? {
        guard let rank = store.rank, rank.games > 0 || rank.rating > 0 else { return nil }
        return rank.rating
    }

    /// The league you are in, or the best one reached while the ladder has not answered.
    private var here: League? {
        rating.map { Ranking.standing(for: $0).league } ?? LadderPrizes.best
    }

    var body: some View {
        ScrollViewReader { reader in sheet(reader) }
    }

    private func sheet(_ reader: ScrollViewProxy) -> some View {
        SheetScaffold(title: "The road", subtitle: "Six leagues, Gran Maestro past them, and what each one gives. Only ranked climbs it.",
                      close: { dismiss() }) {
            VStack(alignment: .leading, spacing: 26) {
                if here == nil { startNote }
                road
                // Under the road, so its last stop is explained where it is seen.
                granMaestro
                climbing
                seasons
                if icon != nil, LadderIcon.isSupported { classicIcon }
            }
            .padding(20)
        } bottom: {
            EmptyView()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            drawn = true
            // `-road grand` opens on Gran Maestro, for a screenshot of the end of the road.
            if DebugLaunch.roadOpensAtGrand { reader.scrollTo(League.granMaestro, anchor: .top) }
        }
        .presentationDetents([.large])
    }

    // MARK: The road

    private var road: some View {
        VStack(spacing: 0) {
            ForEach(League.allCases, id: \.self) { league in
                RoadStop(league: league, state: state(of: league), fill: fill(of: league), drawn: drawn,
                         title: league.title(locale: locale), line: line(for: league),
                         pin: state(of: league) == .here ? AnyView(pin) : nil) {
                    prizes(for: league)
                }
                .id(league)
            }
        }
    }

    private func state(of league: League) -> RoadPlace {
        guard let here else { return .ahead }
        if league < here { return .passed }
        return league == here ? .here : .ahead
    }

    /// How far along its own three divisions the road runs past this league. Gran Maestro
    /// has none, so its stretch is the way to the next Reliquia on its road.
    private func fill(of league: League) -> Double {
        switch state(of: league) {
        case .passed: return 1
        case .ahead: return 0
        case .here:
            guard let rating else { return 0 }
            let into = rating - Ranking.floor(of: league)
            if !league.hasDivisions {
                let stretch = GrandGifts.stride * GrandGifts.packEvery
                return Double(into % stretch) / Double(stretch)
            }
            return min(max(Double(into) / Double(Ranking.pointsPerDivision * Ranking.divisionsPerLeague), 0), 1)
        }
    }

    /// Under the name: how far the next division is from here, the division it follows and
    /// how far that is, or where everyone starts. Never the rating itself: "From 1,800
    /// points" sat under a bar that counts to a hundred.
    private func line(for league: League) -> String {
        if state(of: league) == .here, let rating {
            return store.rank?.grandLine(locale: locale) ?? Ranking.climb(from: rating, locale: locale)
        }
        if league == .bronze { return String(localized: "Where everyone starts", locale: locale) }
        let floor = Ranking.floor(of: league)
        let after = Ranking.standing(for: floor - 1).leagueTitle(locale: locale)
        if let rating, rating < floor {
            return String(localized: "After \(after) · \(floor - rating) to go", locale: locale)
        }
        return String(localized: "After \(after)", locale: locale)
    }

    /// You, on the road: your own seat badge, pinned where your rating stands.
    private var pin: some View {
        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 26, mark: store.seatMark, livery: store.livery)
            .overlay { Circle().strokeBorder(Palette.cream, lineWidth: 2).padding(-2) }
            .shadow(color: Palette.ink.opacity(0.5), radius: 5, y: 2)
    }

    // MARK: The prizes

    private func prizes(for league: League) -> AnyView {
        let earned = LadderPrizes.isEarned(league)
        return AnyView(HStack(alignment: .top, spacing: 8) {
            medal(of: league, earned: earned)
            if let prize = league.icon { iconPrize(prize, earned: earned) }
            pay(for: league)
        })
    }

    private func medal(of league: League, earned: Bool) -> some View {
        let medal = league.medal
        let worn = store.seatMark == medal
        return RoadPrize(label: worn ? "Worn" : "Seat medal", isEarned: earned, isChosen: worn,
                         metal: .league(league.rawValue)) {
            guard earned else { return Audio.shared.play(.refused) }
            store.seatMark = medal
            Audio.shared.play(.toggle)
        } art: {
            SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 40, mark: medal, livery: store.livery)
        }
    }

    private func iconPrize(_ prize: LadderIcon, earned: Bool) -> some View {
        let inUse = icon == prize
        return RoadPrize(label: inUse ? "In use" : "App icon", isEarned: earned, isChosen: inUse,
                         metal: .league(prize.league.rawValue)) {
            guard earned, LadderIcon.isSupported else { return Audio.shared.play(.refused) }
            Task {
                await LadderIcon.use(prize)
                icon = LadderIcon.current
            }
        } art: {
            LadderIconArt(icon: prize, size: 40)
        }
    }

    /// What a season finished in this league pays, which every league has.
    private func pay(for league: League) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                DenariMark(size: 15)
                Text(verbatim: "+\(SeasonReward.denari(forLeague: league).coins)")
                    .font(.system(size: 14, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldLight)
                    // Gran Maestro's pay is the first with five figures' worth of width.
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(height: 40)
            Text("each season")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(8)
        .frame(width: 80)
    }

    // MARK: How it works

    private var startNote: some View {
        Text("One ranked game puts you on the road, at Bronze. Everything past it is climbed.")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.onTable)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
    }

    /// The house quoted at the price it is to this player: Gran Maestro's is its own.
    private var climbing: some View {
        let house = Ranking.houseStakes(for: rating ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            Caption(text: "How you climb")
            VStack(alignment: .leading, spacing: 14) {
                rule(signed(Ranking.points(won: true, opponentAbove: 0, in: .gold)),
                     "A win against someone of your level. More against a higher league, less against a lower one.")
                rule(signed(house.win),
                     "A win against the house, for the first \(Ranking.houseGamesPerDay) games of the day.")
                rule(signed(Ranking.streakStep),
                     "For each win in a row before it, the house included, up to \(signed(Ranking.streakCap)).")
                rule(signed(Ranking.points(won: false, opponentAbove: 0, in: .gold)),
                     "A loss against someone of your level. Half that in Bronze and Silver, and \(signed(house.loss)) against the house.")
                rule("\(Ranking.pointsPerDivision)",
                     "Points make a division, three divisions a league. A league once reached is never lost.")
                rule("+1",
                     "Pack in the album for each division climbed, once a season.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
        }
    }

    /// Past Maestro I: what the points are, what the house is worth there, what the road
    /// pays, and who the Campioni are.
    private var granMaestro: some View {
        let house = Ranking.houseStakes(for: Ranking.grandFloor)
        return VStack(alignment: .leading, spacing: 12) {
            Caption(verbatim: "Gran Maestro")
            VStack(alignment: .leading, spacing: 14) {
                rule("0", "Where its points start each season. They have no top, and Gran Maestro itself is never lost.")
                rule(signed(house.win),
                     "A win against the house there, and \(signed(house.loss)) for a loss: up here the points say how often you beat it.")
                rule("+\(GrandGifts.denari.coins)",
                     "Denari for every \(GrandGifts.stride) points, and a Reliquia pack every \(GrandGifts.stride * GrandGifts.packEvery), once a season.")
                rule("\(Ranking.campioni)",
                     "The season's \(Ranking.campioni) best Gran Maestri with \(Ranking.campionePoints) points or more are its Campioni.")
                rule("+\(SeasonReward.campioneBonus.coins)",
                     "On top of the season's pay, for finishing it as a Campione.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
        }
    }

    private func rule(_ value: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: value)
                .font(.system(size: 16, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
                .frame(width: 44, alignment: .trailing)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var seasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(text: "Seasons")
            VStack(alignment: .leading, spacing: 8) {
                Text("A season lasts a month. When it ends you are paid by the league you finished in, and the divisions start again from the bottom of that league, never below it.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
                if let days = store.rank?.daysLeftInSeason {
                    Text(days == 0 ? "This one ends today." : "This one ends in ^[\(days) day](inflect: true).")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
        }
    }

    private var classicIcon: some View {
        Button {
            Task {
                await LadderIcon.use(nil)
                icon = LadderIcon.current
            }
        } label: {
            HStack(spacing: 12) {
                LadderIconArt(icon: nil, size: 30)
                Text("Back to the classic icon")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassPanel(radius: GlassRadius.control)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "+20", "−12": a real minus, which a hyphen only pretends to be.
    private func signed(_ value: Int) -> String {
        value < 0 ? "−\(abs(value))" : "+\(value)"
    }
}
