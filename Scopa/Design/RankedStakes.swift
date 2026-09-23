import SwiftUI
import ScopaCore

/// A banner over the opening deal: who is across the table, and what the game pays.
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

        /// What the run is worth of `win`, and 0 where there is no run to pay.
        var streakBonus: Int { Ranking.streakBonus(after: streak) }
        /// The floor would swallow this loss.
        var isSafe: Bool { loss == 0 }
        /// The day's house games are spent, so this one is played for itself.
        var isSpent: Bool { win == 0 && loss == 0 }
    }

    let odds: Odds

    @Environment(\.locale) private var locale
    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 10) {
            sides
            // Fixed width: a rule with none of its own stretches the banner to the screen.
            Rectangle()
                .fill(Palette.gold.opacity(0.28))
                .frame(width: 200, height: 1)
            if odds.isSpent {
                Text("The ladder has had its games from the house today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
            } else {
                payout
                if odds.streakBonus > 0 { run }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background { plate }
        .shadow(color: felt.shade(0.5), radius: 26, y: 12)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var sides: some View {
        HStack(spacing: 12) {
            side(odds.mine, name: String(localized: "You", locale: locale))
            Text("vs")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            if let theirs = odds.theirs {
                side(theirs, name: String(localized: "Them", locale: locale))
            } else {
                unrankedSide
            }
        }
    }

    /// A stranger with no ranked games behind them, rather than a Bronze medal they have
    /// not been given.
    private var unrankedSide: some View {
        VStack(spacing: 2) {
            Text("Unranked")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.onTable)
            Text("Them")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    private var payout: some View {
        HStack(spacing: 8) {
            Text(verbatim: "+\(odds.win)")
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.goldSheen)
            Text("to win")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: "·").foregroundStyle(Palette.onTableSoft)
            if odds.isSafe {
                Text("your league holds")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(felt.accent)
            } else {
                Text(verbatim: "−\(abs(odds.loss))")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.terracotta)
                Text("to lose")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    /// What the run behind you is adding to the win, said only when there is one. A loss
    /// ends it, which is the other half of why the line is there.
    private var run: some View {
        Text("\(odds.streak) in a row · +\(odds.streakBonus) for the run")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.goldLight)
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

    private func side(_ standing: Standing, name: String) -> some View {
        VStack(spacing: 3) {
            LeagueMedal(league: standing.league.rawValue, size: 30)
            Text(verbatim: standing.leagueTitle(locale: locale).uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Palette.onTable)
            Text(verbatim: name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
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
    /// somebody to beat five times in a row.
    ///
    /// `win` and `loss` are the Worker's own price where it has told us one: it is the
    /// Worker that settles the game, and a phone quoting its own copy of the rule promised
    /// +25 while a Worker still on the old price paid +5.
    static func houseOdds(mine: Int, theirs: Int?, counting: Bool,
                          win: Int = Ranking.houseWin, loss: Int = Ranking.houseLoss) -> Odds {
        let standing = Ranking.standing(for: mine)
        let across = theirs.map { Ranking.standing(for: $0) }
        guard counting else { return Odds(mine: standing, theirs: across, win: 0, loss: 0) }
        let landed = Ranking.apply(loss, to: mine, floor: Ranking.floor(of: standing.league))
        return Odds(mine: standing, theirs: across, win: win, loss: landed.rating - mine)
    }
}

#Preview("What the table is worth") {
    ZStack {
        TableGround()
        VStack(spacing: 24) {
            RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: [720]))
            RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: [455], streak: 4))
            RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: [180]))
            RankedStakes(odds: RankedStakes.odds(mine: 600, theirs: [640]))
            RankedStakes(odds: RankedStakes.odds(mine: 455, theirs: []))
        }
    }
}
