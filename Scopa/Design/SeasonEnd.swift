import SwiftUI
import ScopaCore
import ScopaRewards

/// What a season pays out, by the league it was finished in.
///
/// Scaled against the shop: a game pays about 35 denari and a deck costs 300. The steps
/// widen as they go up because the climb does too.
enum SeasonReward {
    static func denari(forLeague league: League) -> Denari {
        switch league {
        case .bronze: 100
        case .silver: 200
        case .gold: 400
        case .platinum: 700
        case .diamond: 1_100
        case .maestro: 1_600
        }
    }
}

/// The season-over card: the league reached, what it paid, and a button to collect it.
struct SeasonCard: View {
    let finish: Ladder.RankAnswer.Finish
    /// True while the denari are being granted, so the button can say so.
    var isCollecting: Bool
    let collect: () -> Void

    @Environment(\.locale) private var locale
    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    private var league: Int { finish.standing.league }
    private var metal: LeagueMetal { .league(league) }
    private var reward: Denari { SeasonReward.denari(forLeague: League(rawValue: league) ?? .bronze) }

    var body: some View {
        VStack(spacing: 0) {
            heading
            standing
            reward(reward)
                .padding(.bottom, 20)
            collectButton
            // Answers "what happened to my divisions", which the card otherwise raises.
            Text("Your league is yours to keep. The divisions start again, and so does everybody else's.")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(26)
        .frame(maxWidth: 380)
        .background { cardBackground }
    }

    private var heading: some View {
        VStack(spacing: 0) {
            Text("SEASON OVER")
                .font(.system(size: 12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Palette.onTableSoft)
                .padding(.bottom, 18)
            LeagueMedal(league: league, size: 108)
                .padding(.bottom, 16)
        }
    }

    private var standing: some View {
        VStack(spacing: 0) {
            Text("You finished")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Text(verbatim: finish.standing.leagueTitle(locale: locale))
                .font(.display(44))
                .foregroundStyle(Palette.onTable)
                .padding(.bottom, 6)
            Text("\(finish.wins) wins · \(finish.games) games")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.bottom, 22)
        }
    }

    private var collectButton: some View {
        Button(action: collect) {
            Text(isCollecting ? "Collecting…" : "Collect")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { Capsule().fill(Palette.terracotta) }
        }
        .buttonStyle(.plain)
        .disabled(isCollecting)
        .padding(.bottom, 14)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(felt.plate(from: .top, to: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 28).strokeBorder(metal.base.opacity(0.5), lineWidth: 1.5)
            }
            .shadow(color: Palette.ink.opacity(0.4), radius: 30, y: 14)
    }

    /// The payout, in the same denari chip the rest of the app uses.
    private func reward(_ amount: Denari) -> some View {
        HStack(spacing: 10) {
            DenariMark(size: 26)
            Text(verbatim: "+\(amount.coins)")
                .font(.display(30))
                .monospacedDigit()
                .foregroundStyle(Palette.goldSheen)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background { Capsule().fill(felt.shade(0.5)) }
        .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1) }
    }
}

#Preview("The end of a season") {
    ZStack {
        TableGround()
        SeasonCard(finish: .init(season: "2026-08", rating: 745, games: 58, wins: 32,
                                 standing: .init(league: 2, division: 2, progress: 45, step: 7, title: "Gold II")),
                   isCollecting: false) {}
            .padding(20)
    }
}
