import SwiftUI
import ScopaCore

/// The daily ladder, read from the Worker's `v1/daily/<day>`. Only today and yesterday are
/// shown: nothing older can still be climbed.
///
/// The week used to be a third tab here. It has a room of its own now — `WeeklySheet` — so
/// this screen is one thing: who beat the day's deck, and by how much.
struct LeaderboardView: View {
    let store: TableStore

    @Environment(\.dismiss) private var dismiss
    @State private var day: Day
    @State private var board: Ladder.Board?
    /// The request answered nothing: ladder off, Worker down, or no network. One state,
    /// because the screen says the same thing for all three.
    @State private var failed = false

    /// Which board it opens on. The lobby's peek leads to today; nothing else asks for
    /// yesterday, but the picker is there for the comparison.
    init(store: TableStore, opensOn day: Day = .today) {
        self.store = store
        _day = State(initialValue: day)
    }

    enum Day: Hashable, CaseIterable {
        case today, yesterday

        var title: LocalizedStringKey {
            switch self {
            case .today: "Today"
            case .yesterday: "Yesterday"
            }
        }
    }

    private func name(of day: Day) -> String {
        switch day {
        case .today: store.today
        case .yesterday: store.yesterday
        }
    }

    var body: some View {
        SheetScaffold(title: "The ladder", subtitle: "Same deck for everybody, ranked by margin over Hugo.",
                      close: { dismiss() }) {
            VStack(spacing: 0) {
                picker
                content
            }
        }
        .presentationDetents([.large])
        .task(id: day) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let board, !board.isEmpty {
            rows(board)
        } else if failed {
            message(
                symbol: "wifi.slash",
                title: "The ladder is not answering",
                detail: "It needs a line out to the world. Try again in a moment."
            )
        } else if board != nil {
            message(
                symbol: "figure.walk.departure",
                title: day == .today ? "Nobody has played today yet" : "Nobody played yesterday",
                detail: day == .today
                    ? "Play today's deal and the ladder starts with you."
                    : "The deal was there; the room was empty."
            )
        } else {
            // A spinner rather than an empty board while the request is in flight.
            waiting
        }
    }

    private var waiting: some View {
        ProgressView()
            .tint(Palette.onTableSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
    }

    private var picker: some View {
        GlassSegments(options: Day.allCases, selection: $day) { $0.title }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)
    }

    private func rows(_ board: Ladder.Board) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(board.top.enumerated()), id: \.element.id) { index, row in
                // The Worker ranks the board and the reader the same way, so a row is
                // the reader's when its place matches their rank.
                LadderRow(place: index + 1, row: row, isYou: board.you?.rank == index + 1)
            }
            // The Worker sends fifty rows. A reader below that gets their own line.
            if let you = board.you, let rank = you.rank, rank > board.top.count {
                YourPlace(standing: you)
                    .padding(.top, 6)
            }
            footnote(board)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func footnote(_ board: Ladder.Board) -> some View {
        VStack(spacing: 4) {
            if let you = board.you {
                Text("^[\(you.played) player](inflect: true) today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            if day == .today {
                Text("Still being played. It settles at midnight.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(.top, 14)
    }

    private func message(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.onTable)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 50)
    }

    private func load() async {
        board = nil
        failed = false
        guard let answer = await store.ladderBoard(day: name(of: day)) else {
            failed = true
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { board = answer }
    }
}

/// One line of the ladder: place, name, score and margin over the bot.
private struct LadderRow: View {
    let place: Int
    let row: Ladder.Board.Row
    let isYou: Bool

    /// The top three get a medal: gold, silver, bronze as league 2, 1, 0.
    private var league: Int? {
        switch place {
        case 1: 2
        case 2: 1
        case 3: 0
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            placeMark(size: 34)
            SeatBadge(name: row.name, tint: Palette.seat(place), size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.name)
                    .font(.system(size: 15, weight: isYou ? .bold : .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                score
            }
            Spacer(minLength: 0)
            Text(verbatim: signed(row.margin))
                .font(.display(24))
                .monospacedDigit()
                // A flat tint for the top three: the medal is where the metal goes.
                .foregroundStyle(league.map { LeagueMetal.league($0).base } ?? Palette.onTable)
        }
        .ladderPanel(isYou: isYou)
    }

    private var score: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(row.mine) – \(row.theirs)")
                .monospacedDigit()
            if row.scope > 0 {
                Label("\(row.scope)", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            }
            if let accuracy = row.accuracy {
                Text(verbatim: "\(accuracy)%").monospacedDigit()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.onTableSoft)
    }

    @ViewBuilder private func placeMark(size: CGFloat) -> some View {
        if let league {
            LeagueMedal(league: league, size: size)
        } else {
            Text(verbatim: "\(place)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
                .frame(width: size)
        }
    }
}

/// The reader's own place, for a player on the ladder but below the top fifty.
private struct YourPlace: View {
    let standing: Ladder.Standing

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(standing.rank ?? 0)")
                .font(.display(24))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
            VStack(alignment: .leading, spacing: 2) {
                Text("Where you came")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                if let percentile = standing.percentile {
                    Text("Ahead of \(percentile)% of the room")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control, tint: Palette.gold.opacity(0.22))
    }
}

private extension View {
    /// The row panel, lit when the row is the reader's own.
    func ladderPanel(isYou: Bool) -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPanel(radius: GlassRadius.control, tint: isYou ? Palette.gold.opacity(0.22) : nil)
            .overlay {
                if isYou {
                    RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                        .strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1)
                }
            }
    }
}

#Preview {
    LeaderboardView(store: TableStore())
}
