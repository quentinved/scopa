import SwiftUI
import ScopaRewards

/// Every game this phone has finished, told as a record: the totals, a few keepsakes, the
/// people you keep meeting, and the last games. Pushed from the name in Settings.
///
/// A page to look things up on, not a board to climb. No chart and no strangers' ranks:
/// what happened at your own table, in the same type as the rest of the settings.
struct RecordPage: View {
    var book: RecordBook = .shared

    /// The list stops here until asked for the rest: two hundred rows is a long scroll for
    /// somebody looking for last night.
    private static let shortList = 20
    @State private var showsEveryGame = false

    private var log: GameLog { book.log }
    private var totals: RecordTotals { log.totals }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if log.isEmpty { empty } else { record }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            // A beat after the push, once the book is read and the rows are there to scroll to.
            .task {
                guard DebugLaunch.recordOpensOnPeople else { return }
                try? await Task.sleep(for: .milliseconds(800))
                proxy.scrollTo("people", anchor: .top)
            }
        }
        .softScrollEdge(.top)
        .scrollIndicators(.hidden)
        .background(TableGround())
        .navigationTitle("Your record")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { book.load() }
    }

    @ViewBuilder private var record: some View {
        totalsGroup
        keepsakes
        if !rivals.isEmpty { rivalsGroup.id("people") }
        if !bots.isEmpty { botsGroup }
        if !log.games.isEmpty { lastGames }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(text: "Nothing in the book yet")
            Text("Every game you finish from now on is written down here: who sat across from you, how it ended, and who is ahead.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: GlassRadius.panel)
        .padding(.top, 8)
    }

    // MARK: Totals

    private var totalsGroup: some View {
        SettingsGroup(caption: "All told", footnote: beforeNote) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    RecordFigure(value: Text(totals.all.played, format: .number), caption: "Games")
                    RecordFigure(value: Text(totals.all.won, format: .number), caption: "Won")
                    RecordFigure(value: share, caption: "Win rate")
                }
                if groups.count > 1 {
                    Rule()
                    ForEach(groups, id: \.0) { group, record in RecordGroupRow(group: group, record: record) }
                }
            }
            .padding(16)
        }
    }

    private var share: Text {
        let all = totals.all
        guard all.played > 0 else { return Text(verbatim: "–") }
        return Text(Double(all.won) / Double(all.played), format: .percent.precision(.fractionLength(0)))
    }

    /// Only the kinds of table actually played, in the order the lobby offers them.
    private var groups: [(LoggedGame.Group, WonLost)] {
        LoggedGame.Group.allCases.compactMap { group in
            totals.groups[group].flatMap { $0.played > 0 ? (group, $0) : nil }
        }
    }

    /// What the totals carry from before the log, said plainly: they are in, the games are not.
    private var beforeNote: LocalizedStringKey? {
        let before = totals.before
        guard before.played > 0 else { return nil }
        return "Games from before this release were never written down, so only the totals know them: \(before.won) won, \(before.lost) lost, counted in above."
    }

    // MARK: Keepsakes

    private var keepsakes: some View {
        SettingsGroup(caption: "Keepsakes", footnote: sinceNote) {
            if let best = totals.biggestWin, let score = best.score, score.count == 2 {
                KeepsakeRow(symbol: "rosette", tint: Palette.gold, title: "Biggest win",
                            detail: KeepsakeRow.when(best), value: "\(score[0])–\(score[1])")
                Rule()
            }
            if let best = totals.mostScope {
                KeepsakeRow(symbol: nil, tint: Palette.terracotta, title: "Most scope in one game",
                            detail: KeepsakeRow.when(best), value: "\(best.value)")
                Rule()
            }
            if let best = totals.longestRun {
                KeepsakeRow(symbol: "repeat", tint: Palette.seaGlaze, title: "Longest run of wins",
                            detail: runDetail(best), value: "\(best.value)")
                Rule()
            }
            KeepsakeRow(symbol: "7.circle.fill", tint: Palette.gold, title: "Settebelli taken",
                        detail: Text("Rounds you came home with the seven of coins"), value: "\(totals.allSettebelli)")
            if totals.allCappotti > 0 {
                Rule()
                KeepsakeRow(symbol: "checkmark.seal.fill", tint: Palette.steel, title: "Clean sweeps",
                            detail: Text("Rounds with every point to you"), value: "\(totals.allCappotti)")
            }
        }
    }

    private func runDetail(_ best: Best) -> Text {
        totals.run == best.value ? Text("Still going") : Text("Set on \(best.date, format: .dateTime.day().month(.wide))")
    }

    private var sinceNote: LocalizedStringKey? {
        guard let since = totals.since else { return nil }
        return "In the book since \(since, format: .dateTime.day().month(.wide).year())."
    }

    // MARK: People

    private var rivals: [Rivalry] { log.rivals() }

    private var rivalsGroup: some View {
        SettingsGroup(caption: "Across the table", footnote: "The people you have played most, and how it stands between you.") {
            ForEach(Array(rivals.enumerated()), id: \.element.id) { index, rival in
                if index > 0 { Rule() }
                RivalRow(rival: rival, tint: Palette.seat(1 + index % 3))
            }
        }
    }

    /// The house's own cast, in the order they sit down. The strangers who fill an online
    /// table are bots too, but nobody would know them by name.
    private var bots: [(String, WonLost)] {
        BotNames.all.compactMap { name in
            totals.bots[name].flatMap { $0.played > 0 ? (name, $0) : nil }
        }
    }

    private var botsGroup: some View {
        SettingsGroup(caption: "At the table with the bots", footnote: "They do not keep score. You do.") {
            ForEach(Array(bots.enumerated()), id: \.element.0) { index, bot in
                if index > 0 { Rule() }
                BotRow(name: bot.0, record: bot.1, tint: Palette.seat(1 + index % 3))
            }
        }
    }

    // MARK: Last games

    private var shownGames: [LoggedGame] {
        let newest = Array(log.games.reversed())
        return showsEveryGame ? newest : Array(newest.prefix(Self.shortList))
    }

    private var lastGames: some View {
        SettingsGroup(caption: "Last games", footnote: "The last \(GameLog.kept) games are kept here in full. The totals count every one.") {
            VStack(spacing: 0) {
                ForEach(Array(shownGames.enumerated()), id: \.element.id) { index, game in
                    if index > 0 { Rule() }
                    LoggedGameRow(game: game)
                }
            }
            if !showsEveryGame, log.games.count > Self.shortList {
                Rule()
                Button("Show all \(log.games.count)") { showsEveryGame = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// The way into the record, under the level and the purse in the profile and in their hand:
/// how it stands with the person you play most, or how many games there have been.
struct RecordEntryRow: View {
    var book: RecordBook = .shared
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Your record")
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 8)
                detail
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onAppear { book.load() }
    }

    private var detail: Text {
        if let rival = book.log.rivals(limit: 1).first, rival.record.played > 0 {
            return Text(verbatim: rival.line(locale: locale))
        }
        let played = book.log.totals.all.played
        return played > 0 ? Text("^[\(played) game](inflect: true)") : Text("Nothing yet")
    }
}
