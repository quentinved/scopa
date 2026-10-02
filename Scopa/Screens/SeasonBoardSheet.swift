import SwiftUI
import UIKit
import ScopaCore
import ScopaGameCenter

/// The season's ranked board, read from the Worker's `v1/ranked/board`: everyone who has
/// played ranked this season, highest rating first — or only your Game Center friends.
///
/// A row shows what the rest of the app shows of a rating — the league's medal, its title
/// and how far through the division — and never the number itself. The medal is the
/// player's league, not their place: bronze here is a grade somebody is in, not third.
struct SeasonBoardSheet: View {
    let store: TableStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var who: Who
    @State private var board: Ladder.SeasonBoard?
    /// Ladder off, Worker down, or no network. One state, as on the daily board.
    @State private var failed = false
    /// Why the friends' tab has no friends to rank, when Game Center is the reason.
    @State private var friendsProblem: FriendsProblem?

    init(store: TableStore) {
        self.store = store
        _who = State(initialValue: DebugLaunch.seasonOpensOnFriends ? .friends : .everyone)
    }

    /// The whole season, or only the people you know in it.
    enum Who: Hashable, CaseIterable {
        case everyone, friends

        var title: LocalizedStringKey { self == .everyone ? "Everyone" : "Friends" }
    }

    var body: some View {
        // Named as the row that opens it, so the sheet is the thing that was tapped.
        SheetScaffold(title: "The season's ladder", subtitle: "Everyone in ranked this season, highest league first.",
                      close: { dismiss() }) {
            VStack(spacing: 0) {
                GlassSegments(options: Who.allCases, selection: $who) { $0.title }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                content
            }
        }
        .presentationDetents([.large])
        .task(id: who) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let board, !board.isEmpty {
            rows(board)
        } else if let friendsProblem {
            trouble(friendsProblem)
        } else if failed {
            message(symbol: "wifi.slash", title: "The ladder is not answering",
                    detail: "It needs a line out to the world. Try again in a moment.")
        } else if board != nil {
            empty
        } else {
            ProgressView()
                .tint(Palette.onTableSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
        }
    }

    @ViewBuilder private var empty: some View {
        switch who {
        case .everyone:
            message(symbol: "figure.walk.departure", title: "Nobody has played ranked this season yet",
                    detail: "One ranked game and the ladder has you")
        case .friends:
            message(symbol: "person.2", title: "None of your friends has played ranked this season",
                    detail: "Someone missing? They need Scopa too. Add them on Game Center and they show up here when you come back.",
                    action: ("Find friends on Game Center", findFriends))
        }
    }

    /// Game Center would not hand the friends over, and what to do about it.
    @ViewBuilder private func trouble(_ problem: FriendsProblem) -> some View {
        switch problem {
        case .signedOut:
            message(symbol: "person.crop.circle.badge.questionmark", title: "Sign in to Game Center to see your friends",
                    detail: "Needs Game Center, which is signed in to from the iPhone's Settings.")
        case .denied:
            message(symbol: "lock", detail: "Scopa is not allowed to see your friends. Turn it on in the iPhone's Settings, under Game Center.",
                    action: ("Open Settings", openSettings))
        case .restricted:
            message(symbol: "lock", detail: "Friend lists are turned off on this device. Screen Time settings can turn them back on.")
        case .unavailable:
            message(symbol: "exclamationmark.triangle", detail: "Your Game Center friends could not be loaded just now.",
                    action: ("Try again", reload))
        }
    }

    private func rows(_ board: Ladder.SeasonBoard) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(board.top.enumerated()), id: \.element.id) { index, row in
                SeasonRow(place: index + 1, row: row, isYou: board.you?.rank == index + 1)
            }
            // The Worker sends fifty rows. A reader below that gets their own line.
            if let you = board.you, let rank = you.rank, rank > board.top.count {
                YourPlace(title: "Where you stand", rank: rank, percentile: you.percentile)
                    .padding(.top, 6)
            }
            footnote(board)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func footnote(_ board: Ladder.SeasonBoard) -> some View {
        VStack(spacing: 4) {
            if who == .friends {
                Text("Someone missing? They need Scopa too. Add them on Game Center and they show up here when you come back.")
                    .font(.system(size: 12, weight: .medium))
            } else if let you = board.you {
                Text("^[\(you.played) player](inflect: true) this season")
                    .font(.system(size: 12, weight: .medium))
            }
            if board.you?.rank == nil {
                Text("One ranked game and the ladder has you")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.goldLight.opacity(0.9))
            }
            if let days = board.daysLeft {
                Text(days == 0 ? "Season ends today" : "Season ends in \(days) days")
                    .font(.system(size: 12))
            }
            Text("Your league is yours to keep. The divisions start again, and so does everybody else's.")
                .font(.system(size: 12))
            if who == .friends { link("Find friends on Game Center", action: findFriends).padding(.top, 6) }
        }
        .foregroundStyle(Palette.onTableSoft)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 14)
    }

    /// A page with nothing to rank on it: what happened, and the way on where there is one.
    private func message(symbol: String, title: LocalizedStringKey? = nil, detail: LocalizedStringKey,
                         action: (LocalizedStringKey, () -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.onTable)
            }
            Text(detail)
                .font(.system(size: title == nil ? 15 : 13))
                .foregroundStyle(title == nil ? Palette.onTable : Palette.onTableSoft)
            if let action { link(action.0, action: action.1).padding(.top, 4) }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 50)
    }

    private func link(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.goldLight)
    }

    // MARK: Loading

    private func load() async {
        board = nil
        failed = false
        friendsProblem = nil
        do {
            let answer: Ladder.SeasonBoard?
            if who == .everyone {
                answer = await store.seasonBoard()
            } else {
                answer = try await store.friendsSeasonBoard()
            }
            // A tab left before its answer came back must not have it land on the other one.
            guard !Task.isCancelled else { return }
            guard let answer else {
                failed = true
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) { board = answer }
        } catch let error as GameCenterError {
            friendsProblem = FriendsProblem(error)
        } catch {
            friendsProblem = .unavailable(error.localizedDescription)
        }
    }

    private func reload() {
        Task { await load() }
    }

    /// Apple's friends page, and a fresh look once it comes down: a friend added there
    /// should show up without the sheet being closed and opened again.
    private func findFriends() {
        store.showGameCenterFriends { reload() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// One player's season: place, league medal and name; the league with its division bar
/// beside it; and on the right the win rate, spelled out as wins out of games.
///
/// The bar used to sit under a bare "70%", where it read as a gauge of that number and the
/// number read as some kind of accuracy. Each now sits next to the thing it measures.
private struct SeasonRow: View {
    let place: Int
    let row: Ladder.SeasonBoard.Row
    let isYou: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(place)")
                .font(.system(size: 15, weight: place <= 3 ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(place <= 3 ? Palette.goldLight : Palette.onTableSoft)
                .frame(width: 26)
            // Wider than the medal: Maestro's rays reach past it, and ran into the name.
            LeagueMedal(league: row.standing.league, size: 30)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: row.name)
                    .font(.system(size: 15, weight: isYou ? .bold : .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                grade
            }
            Spacer(minLength: 4)
            record
        }
        .ladderPanel(isYou: isYou)
        .accessibilityElement(children: .combine)
    }

    /// The league, and how far into its division: the bar belongs to the title it follows.
    private var grade: some View {
        HStack(spacing: 7) {
            Text(verbatim: row.standing.leagueTitle(locale: locale))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
            LeagueBar(metal: .league(row.standing.league), progress: Double(row.standing.progress) / 100,
                      width: 34)
        }
    }

    /// "70% won" over "28 of 40": a percentage with its word, and the count it comes from.
    @ViewBuilder private var record: some View {
        if let rate = Ladder.winRate(wins: row.wins, games: row.games, locale: locale) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(rate) won")
                    .font(.system(size: 13.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
                Text("\(row.wins) of \(row.games)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            .lineLimit(1)
            .fixedSize()
        }
    }
}

#if DEBUG
extension Ladder.SeasonBoard {
    /// A dozen players across every league, the reader eighth, for `-season` and the preview.
    static var sample: Self {
        let names = ["Giulia", "Marco", "Élodie", "Salvo", "Nonna Pina", "Luca",
                     "Chiara", "Théo", "Ada", "Renzo", "Bea", "Tommaso"]
        let ratings = [1_612, 1_488, 1_330, 1_207, 1_180, 955, 910, 745, 702, 610, 388, 140]
        let top = zip(names, ratings).enumerated().map { index, pair in
            let standing = Ranking.standing(for: pair.1)
            return Row(id: "sample-\(index)", name: pair.0, rating: pair.1, games: 40 - index * 2,
                       wins: 28 - index * 2,
                       standing: .init(league: standing.league.rawValue, division: standing.division,
                                       progress: standing.progress, step: standing.step, title: standing.title))
        }
        return .init(season: "2026-09", seasonEndsAt: "2026-10-01T00:00:00.000Z", top: top,
                     you: .init(played: 212, rank: 8, percentile: 97))
    }

    /// Four of the same players, the reader third among them, for `-season friends`.
    static var friendsSample: Self {
        let top = [1, 5, 7, 10].map { sample.top[$0] }
        return .init(season: "2026-09", seasonEndsAt: "2026-10-01T00:00:00.000Z", top: top,
                     you: .init(played: top.count, rank: 3, percentile: nil))
    }
}

#Preview {
    SeasonBoardSheet(store: TableStore())
}
#endif
