import SwiftUI
import ScopaCore

/// A banner over the opening deal: what kind of game this is, who is across the table, and
/// what it pays either way.
///
/// The numbers come from `Ranking`, the same maths the Worker settles with, so what is
/// promised here is what the ladder pays.
struct RankedStakes: View {
    /// The two leagues and the two numbers, ready to print.
    struct Odds: Equatable {
        let mine: Standing
        /// The far side as one standing. In a duo it is the pair averaged, which is what
        /// the ladder measures a loss against.
        let theirs: Standing?
        /// What a win pays, the run included.
        let win: Int
        /// What a loss costs, already put through the league floor.
        let loss: Int
        /// Wins standing in a row behind this table.
        var streak: Int = 0
        /// A table against the house, which neither lengthens a run nor ends one.
        var isHouse = false
        /// House games already played today, and how many a day the ladder counts.
        var housePlayed: Int? = nil
        var housePerDay: Int = Ranking.houseGamesPerDay
        /// Each side's season so far, for a win rate under the medal. Nil where unknown.
        var myRecord: Record? = nil
        var theirRecord: Record? = nil

        /// What the run is worth of `win`, and 0 where there is no run to pay.
        var streakBonus: Int { isHouse ? 0 : Ranking.streakBonus(after: streak) }
        /// The floor would swallow this loss.
        var isSafe: Bool { loss == 0 }
        /// The day's house games are spent, so this one is played for itself.
        var isSpent: Bool { win == 0 && loss == 0 }
    }

    /// Ranked games won out of games played this season.
    struct Record: Equatable {
        let wins: Int
        let games: Int
    }

    let odds: Odds

    @Environment(\.locale) private var locale
    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 11) {
            title
            sides
            // Fixed width: a rule with none of its own stretches the banner to the screen.
            Rectangle()
                .fill(Palette.gold.opacity(0.28))
                .frame(width: 220, height: 1)
            if odds.isSpent {
                note("No house games left to count today, so this one is for fun")
            } else {
                chips
                if odds.isSafe { note("Your league holds if you lose") }
            }
            if odds.streak > 0 { run }
            if odds.isHouse, !odds.isSpent, let count = houseCount { note(count) }
        }
        .frame(width: 270)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background { plate }
        .shadow(color: felt.shade(0.5), radius: 26, y: 12)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    // MARK: The parts

    /// What kind of table this is, in the house voice.
    private var title: some View {
        Text(odds.isHouse ? LocalizedStringKey("Ranked · against the house") : LocalizedStringKey("Ranked game"))
            .font(.system(size: 12.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(Palette.goldLight)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var sides: some View {
        HStack(alignment: .top, spacing: 10) {
            side(odds.mine, name: String(localized: "You", locale: locale), record: odds.myRecord)
            Text("vs")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
                .padding(.top, 10)
            if let theirs = odds.theirs {
                side(theirs, name: String(localized: "Them", locale: locale), record: odds.theirRecord)
            } else {
                unrankedSide
            }
        }
    }

    /// A stranger with no ranked games behind them, rather than a Bronze medal they have
    /// not been given.
    private var unrankedSide: some View {
        VStack(spacing: 3) {
            Circle()
                .strokeBorder(Palette.onTableSoft.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 30, height: 30)
            Text("Unranked")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.onTable)
            Text("Them")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
        }
        .frame(width: 110)
    }

    private func side(_ standing: Standing, name: String, record: Record?) -> some View {
        VStack(spacing: 3) {
            LeagueMedal(league: standing.league.rawValue, size: 30)
            Text(verbatim: standing.leagueTitle(locale: locale).uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
            if let record, let rate = Ladder.winRate(wins: record.wins, games: record.games, locale: locale) {
                Text("\(rate) won")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .frame(width: 110)
    }

    /// Both outcomes side by side, each a word and a number, so neither needs reading twice.
    private var chips: some View {
        HStack(spacing: 10) {
            StakeChip(label: "Win", value: "+\(odds.win)", tint: Palette.goldLight)
            StakeChip(label: "Lose", value: odds.isSafe ? "0" : "−\(abs(odds.loss))",
                      tint: odds.isSafe ? felt.accent : Palette.terracotta)
        }
    }

    /// The run behind this table: a flame a win, and what it means for this game. Against
    /// the house it is kept, not played for, and the flames are banked rather than lit.
    private var run: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                RunFlames(count: odds.streak, lit: !odds.isHouse)
                Text("\(odds.streak) in a row")
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(odds.isHouse ? Palette.onTableSoft : Palette.goldLight)
                if !odds.isHouse, odds.streakBonus > 0 {
                    Text("+\(odds.streakBonus) more if you win")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            note(odds.isHouse ? LocalizedStringKey("The house neither adds to a run nor ends it")
                              : LocalizedStringKey("A loss ends the run"))
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "House game 4 of 10 today": which of the day's counted games this one is.
    private var houseCount: LocalizedStringKey? {
        guard let played = odds.housePlayed else { return nil }
        return "House game \(min(played + 1, odds.housePerDay)) of \(odds.housePerDay) that count today"
    }

    /// Opaque rather than glass: it sits over a freshly dealt cloth, and four bright cards
    /// read through a translucent panel.
    private var plate: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(felt.plate())
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1.5)
            }
    }

    private var spoken: String {
        let against = odds.theirs.map { $0.leagueTitle(locale: locale) } ?? String(localized: "an unranked player", locale: locale)
        let run = odds.streakBonus > 0
            ? " " + String(localized: "\(odds.streak) wins in a row, worth \(odds.streakBonus) of that.", locale: locale)
            : ""
        // Before `isSafe`, which a spent day also satisfies: nothing is lost because nothing
        // is paid, and "0 to win" is not what that means.
        if odds.isSpent {
            return String(localized: "Against \(against). The ladder has had its games from the house today, so this one is for itself.", locale: locale)
        }
        if odds.isSafe {
            return String(localized: "Against \(against). \(odds.win) to win, and your league holds if you lose.", locale: locale) + run
        }
        return String(localized: "Against \(against). \(odds.win) to win, \(abs(odds.loss)) to lose.", locale: locale) + run
    }
}

// MARK: The maths

extension RankedStakes {
    /// What the table is worth to one player, from the ratings on both sides of it.
    ///
    /// The win sums over every loser, is capped, and is paid the run on top; the loss is
    /// measured against the winning side's average, which is how the Worker settles a duo.
    /// The floor used is this league's, which is at or below the ladder's season
    /// high-water mark, so the figure shown can only ever promise a bigger fall than the
    /// ladder will take.
    static func odds(mine: Int, theirs: [Int], streak: Int = 0) -> Odds {
        let standing = Ranking.standing(for: mine)
        let win = Ranking.change(for: mine, others: theirs, won: true, winner: nil, streak: streak)
        let average = theirs.isEmpty ? mine : theirs.reduce(0, +) / theirs.count
        let raw = Ranking.change(for: mine, others: [], won: false, winner: average)
        let landed = Ranking.apply(raw, to: mine, floor: Ranking.floor(of: standing.league))
        return Odds(mine: standing,
                    theirs: theirs.isEmpty ? nil : Ranking.standing(for: average),
                    win: win,
                    loss: landed.rating - mine,
                    streak: streak)
    }

    /// What a table against the house is worth: a win in full and a much smaller loss,
    /// nothing once the day's allowance is spent, and never a run — the house is not
    /// somebody to beat five times in a row. `streak` is the run it leaves standing.
    ///
    /// `win` and `loss` are the Worker's own price where it has told us one: it is the
    /// Worker that settles the game, and a phone quoting its own copy of the rule promised
    /// +25 while a Worker still on the old price paid +5.
    static func houseOdds(mine: Int, theirs: Int?, counting: Bool, streak: Int = 0,
                          win: Int = Ranking.houseWin, loss: Int = Ranking.houseLoss) -> Odds {
        let standing = Ranking.standing(for: mine)
        let across = theirs.map { Ranking.standing(for: $0) }
        guard counting else {
            return Odds(mine: standing, theirs: across, win: 0, loss: 0, streak: streak, isHouse: true)
        }
        let landed = Ranking.apply(loss, to: mine, floor: Ranking.floor(of: standing.league))
        return Odds(mine: standing, theirs: across, win: win, loss: landed.rating - mine,
                    streak: streak, isHouse: true)
    }
}

/// One outcome of the game: "WIN +28" or "LOSE −12", in a capsule of its own colour.
private struct StakeChip: View {
    let label: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: value)
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(tint.opacity(0.14))
                .overlay { Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1) }
        }
    }
}

/// A run of wins as a row of flames, one a win, five at most and a count past that. Banked
/// flames, for a run the house cannot touch, are drawn as outlines.
struct RunFlames: View {
    let count: Int
    var lit = true
    /// The newest flame catches a beat after the rest, so a win can be seen adding to it.
    var catches = false

    @State private var caught = false
    private static let most = 5

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<min(max(count, 0), Self.most), id: \.self) { index in
                let newest = index == min(count, Self.most) - 1
                Image(systemName: lit ? "flame.fill" : "flame")
                    .font(.system(size: 11 + CGFloat(index) * 0.8, weight: .semibold))
                    .foregroundStyle(lit ? Palette.goldLight : Palette.onTableSoft)
                    .scaleEffect(catches && newest && !caught ? 0.2 : 1, anchor: .bottom)
                    .opacity(catches && newest && !caught ? 0 : 1)
            }
            if count > Self.most {
                Text(verbatim: "+\(count - Self.most)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(lit ? Palette.goldLight : Palette.onTableSoft)
            }
        }
        .task {
            guard catches else { return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.45, bounce: 0.55)) { caught = true }
        }
        .accessibilityHidden(true)
    }
}

#Preview("What the table is worth") {
    ZStack {
        TableGround()
        ScrollView {
            VStack(spacing: 24) {
                RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: [720]))
                RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: [455], streak: 4))
                RankedStakes(odds: RankedStakes.houseOdds(mine: 600, theirs: 640, counting: true, streak: 3))
                RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: []))
            }
        }
    }
}

extension RankedStakes.Record {
    /// A season's record as the ladder answered it, or nil before a first game.
    init?(_ rank: Ladder.RankAnswer) {
        guard rank.games > 0 else { return nil }
        self.init(wins: rank.wins, games: rank.games)
    }
}
