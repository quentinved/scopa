import SwiftUI
import ScopaCore
import ScopaRewards

/// What a season pays out, by the league it was finished in.
///
/// Scaled against the shop: a game pays about 35 denari and a deck costs 300. The steps
/// widen as they go up because the climb does too, a hundred wider each time, Gran Maestro's
/// included. A Campione is paid the better part of two decks on top: a place held at the top
/// against everybody else, which a league reached is not.
enum SeasonReward {
    static func denari(forLeague league: League) -> Denari {
        switch league {
        case .bronze: 100
        case .silver: 200
        case .gold: 400
        case .platinum: 700
        case .diamond: 1_100
        case .maestro: 1_600
        case .granMaestro: 2_200
        }
    }

    /// On top of Gran Maestro's pay, for a season finished as one of its Campioni.
    static let campioneBonus: Denari = 500

    /// What one finished season pays, the Campione's bonus included.
    static func denari(for finish: Ladder.RankAnswer.Finish) -> Denari {
        let league = denari(forLeague: League(rawValue: finish.standing.league) ?? .bronze)
        return finish.grand?.campione == true ? league + campioneBonus : league
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
    private var reward: Denari { SeasonReward.denari(for: finish) }
    private var isCampione: Bool { finish.grand?.campione == true }

    var body: some View {
        VStack(spacing: 0) {
            heading
            standing
            reward(reward)
                .padding(.bottom, isCampione ? 8 : 20)
            if isCampione {
                Text("\(SeasonReward.campioneBonus.coins) of it for finishing a Campione")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                    .padding(.bottom, 18)
            }
            collectButton
            // Answers "what happened to my divisions", which the card otherwise raises.
            Text(finish.standing.isGrand
                 ? "Gran Maestro is yours to keep. Its points start again from nought, and so does everybody else's."
                 : "Your league is yours to keep. The divisions start again, and so does everybody else's.")
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
                // From Diamond up the medal is drawn past its frame, and it was covering the
                // heading and "You finished" on the card.
                .padding(.vertical, 108 * (LeagueMedal.reach(league: league) - 1) / 2)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 6)
            if let grand = finish.grand { grandLine(grand) }
            recordLine
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.bottom, 22)
        }
    }

    /// Where Gran Maestro was finished: the points and the place in the house voice, and the
    /// laurel under them for a Campione.
    private func grandLine(_ grand: Ladder.RankAnswer.Grand) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: GrandWords.line(points: grand.points, place: grand.place, locale: locale))
                .textCase(.uppercase)
                .font(.system(size: 12.5, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.onTable)
            if grand.campione { CampioneTag() }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder private var recordLine: some View {
        if let rate = Ladder.winRate(wins: finish.wins, games: finish.games, locale: locale) {
            Text("\(finish.wins) wins · \(finish.games) games · \(rate) win rate")
        } else {
            Text("\(finish.wins) wins · \(finish.games) games")
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

#Preview("A Campione's season") {
    ZStack {
        TableGround()
        SeasonCard(finish: .init(season: "2026-08", rating: 2_140, games: 96, wins: 61,
                                 standing: .init(league: 6, division: 1, progress: 340, step: 18, title: "Gran Maestro"),
                                 grand: .init(points: 340, place: 4, campione: true)),
                   isCollecting: false) {}
            .padding(20)
    }
}
