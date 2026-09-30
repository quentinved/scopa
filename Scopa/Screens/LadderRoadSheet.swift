import SwiftUI
import ScopaCore
import ScopaRewards

/// The whole ladder as a road: the six leagues in order, where you stand on it, and what
/// each league gives. Ranked's prizes are won nowhere else, so this is also where ranked
/// explains how it is climbed.
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
        SheetScaffold(title: "The road", subtitle: "Six leagues, and what each one gives. Only ranked climbs it.",
                      close: { dismiss() }) {
            VStack(alignment: .leading, spacing: 26) {
                if here == nil { startNote }
                road
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
            }
        }
    }

    private func state(of league: League) -> RoadPlace {
        guard let here else { return .ahead }
        if league < here { return .passed }
        return league == here ? .here : .ahead
    }

    /// How far along its own three divisions the road runs past this league.
    private func fill(of league: League) -> Double {
        switch state(of: league) {
        case .passed: return 1
        case .ahead: return 0
        case .here:
            guard let rating else { return 0 }
            let into = rating - Ranking.floor(of: league)
            return min(max(Double(into) / Double(Ranking.pointsPerDivision * Ranking.divisionsPerLeague), 0), 1)
        }
    }

    /// Under the name: how far the next division is from here, what it takes to get here
    /// from below, or where everyone starts.
    private func line(for league: League) -> String {
        if state(of: league) == .here, let rating { return Ranking.climb(from: rating, locale: locale) }
        if league == .bronze { return String(localized: "Where everyone starts", locale: locale) }
        let floor = Ranking.floor(of: league)
        if let rating, rating < floor {
            return String(localized: "From \(floor) points · \(floor - rating) to go", locale: locale)
        }
        return String(localized: "From \(floor) points", locale: locale)
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

    private var climbing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(text: "How you climb")
            VStack(alignment: .leading, spacing: 14) {
                rule(signed(Ranking.points(won: true, opponentAbove: 0, in: .gold)),
                     "A win against someone of your level. More against a higher league, less against a lower one.")
                rule(signed(Ranking.houseWin),
                     "A win against the house, for the first \(Ranking.houseGamesPerDay) games of the day.")
                rule(signed(Ranking.streakStep),
                     "For each win in a row against real players before it, up to \(signed(Ranking.streakCap)).")
                rule(signed(Ranking.points(won: false, opponentAbove: 0, in: .gold)),
                     "A loss against someone of your level. Half that in Bronze and Silver, and \(signed(Ranking.houseLoss)) against the house.")
                rule("\(Ranking.pointsPerDivision)",
                     "Points make a division, three divisions a league. A league once reached is never lost.")
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

private enum RoadPlace { case passed, here, ahead }

/// One league on the road: its medal on the rail, the stretch of rail down to the next,
/// its name and where it starts, and what it gives.
private struct RoadStop<Prizes: View>: View {
    let league: League
    let state: RoadPlace
    /// How much of the rail below this league is run, 0 to 1.
    let fill: Double
    let drawn: Bool
    let title: String
    let line: String
    /// Drawn on the rail where the fill stops.
    let pin: AnyView?
    @ViewBuilder var prizes: Prizes

    private var metal: LeagueMetal { .league(league.rawValue) }
    private var nextMetal: LeagueMetal { .league(league.next?.rawValue ?? league.rawValue) }
    private var shownFill: Double { drawn ? fill : 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rail.frame(width: 50)
            VStack(alignment: .leading, spacing: 10) {
                header
                prizes
            }
            .padding(.top, 6)
            .padding(.bottom, league.next == nil ? 6 : 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: title)
                    .font(.display(26))
                    .foregroundStyle(state == .ahead ? Palette.onTableSoft : Palette.onTable)
                Spacer(minLength: 4)
                tag
            }
            Text(verbatim: line)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    @ViewBuilder private var tag: some View {
        switch state {
        case .passed:
            Label { Text("Reached") } icon: { Image(systemName: "checkmark") }
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(metal.light)
        case .here:
            Text("You are here")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(metal.light)
        case .ahead:
            EmptyView()
        }
    }

    // MARK: The rail

    private var rail: some View {
        VStack(spacing: 0) {
            node
            GeometryReader { geometry in
                let height = geometry.size.height
                ZStack(alignment: .top) {
                    Capsule().fill(Palette.onTableSoft.opacity(0.18)).frame(width: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [metal.light, nextMetal.base], startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: height * shownFill)
                        .shadow(color: metal.light.opacity(0.7), radius: 4)
                    if let pin { pin.offset(y: height * shownFill - 13) }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.55).delay(0.15 + Double(league.rawValue) * 0.14), value: drawn)
            }
            .padding(.vertical, 5)
        }
    }

    private var node: some View {
        LeagueMedal(league: league.rawValue, size: 42)
            .saturation(state == .ahead ? 0 : 1)
            .opacity(state == .ahead ? 0.5 : 1)
            .frame(width: 50, height: 50)
            .background {
                if state == .here {
                    Circle()
                        .fill(metal.base.opacity(0.25))
                        .overlay { Circle().strokeBorder(metal.light.opacity(0.7), lineWidth: 1.5) }
                        .frame(width: 60, height: 60)
                }
            }
    }
}

/// A prize on the road: the thing itself and one word under it. Tapped, it is worn or
/// put on the home screen, or refused while it is still ahead.
private struct RoadPrize<Art: View>: View {
    let label: LocalizedStringKey
    let isEarned: Bool
    let isChosen: Bool
    let metal: LeagueMetal
    let action: () -> Void
    @ViewBuilder var art: Art

    @Environment(\.tableFelt) private var felt

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                art
                    .saturation(isEarned ? 1 : 0)
                    .opacity(isEarned ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) { if !isEarned { LockGlyph().offset(x: 4, y: 4) } }
                    .frame(height: 40)
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isChosen ? metal.light : Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .frame(width: 80)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(felt.shade(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isChosen ? metal.light : Palette.onTableSoft.opacity(0.15),
                                          lineWidth: isChosen ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
