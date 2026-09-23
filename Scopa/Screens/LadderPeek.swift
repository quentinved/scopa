import SwiftUI

/// The top of today's ladder, on the lobby itself.
///
/// It took the place of a row that read "Today's ladder" and had a chevron on the end of
/// it: a button whose whole job was to promise a list, when five lines of the list fit in
/// the same strip and say the same thing with names and numbers on them. Tapping anywhere
/// still opens the board in full.
struct LadderPeek: View {
    @Environment(\.lift) private var lift
    let store: TableStore
    /// How many lines to show. Five is the podium and the two chasing it; a landscape lobby
    /// has room for three.
    var count = 5
    let open: () -> Void

    @State private var board: Ladder.Board?
    /// The request answered nothing: ladder off, Worker down, or no line out. One state,
    /// because the strip says the same short thing for all three.
    @State private var failed = false

    private var rows: [Ladder.Board.Row] { Array(board?.top.prefix(count) ?? []) }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8 * lift) {
                header
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14 * lift)
            .padding(.vertical, 12 * lift)
            .glassPanel(radius: GlassRadius.panel, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Today's ladder"))
        // Reloaded on the walk back from a deal just played, which is the one moment the
        // board is certain to have changed.
        .task(id: store.freshDailyDay) { await load() }
        .animation(.easeInOut(duration: 0.3), value: board)
    }

    /// The name of the strip, and a chevron saying there is more of it.
    ///
    /// The chevron used to have "The whole board" in front of it, in the same grey and
    /// nearly the same size as the label on the left: two captions at opposite ends of one
    /// short row, neither of them louder than the other, with the trailing one sitting
    /// directly over the column of margins underneath. The strip is a button from edge to
    /// edge; a chevron is all the promise it needs.
    private var header: some View {
        HStack(spacing: 8 * lift) {
            Text("Today's ladder")
                .textCase(.uppercase)
                .font(.system(size: 12 * lift, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11 * lift, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    @ViewBuilder private var content: some View {
        if !rows.isEmpty {
            VStack(spacing: 4 * lift) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    PeekRow(place: index + 1, name: row.name, margin: row.margin,
                            isYou: board?.you?.rank == index + 1)
                }
                if let you = board?.you, let rank = you.rank, rank > rows.count {
                    yourLine(you, rank: rank)
                }
            }
            .transition(.opacity)
        } else if failed {
            note("The ladder is not answering")
        } else if board != nil {
            note("Nobody has played today yet. Play the deal and it starts with you.")
        } else {
            waiting
        }
    }

    /// Where the reader came, for a reader below the five lines shown.
    private func yourLine(_ you: Ladder.Standing, rank: Int) -> some View {
        HStack(spacing: 10 * lift) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 13 * lift, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
                .frame(width: 24 * lift, alignment: .trailing)
            Group {
                if let percentile = you.percentile {
                    Text("You — ahead of \(percentile)% of the room")
                } else {
                    Text("Where you came")
                }
            }
            .font(.system(size: 12 * lift, weight: .medium))
            .foregroundStyle(Palette.onTable)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(height: 22 * lift)
        .padding(.top, 2 * lift)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.onTableSoft.opacity(0.25))
                .frame(height: 0.5)
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12 * lift, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 26 * lift, alignment: .center)
    }

    /// Bars where the names will be, at the height the names will take, so the lobby does
    /// not jump when the Worker answers. Three lengths, so it reads as a list rather than
    /// as a broken control.
    private var waiting: some View {
        VStack(spacing: 4 * lift) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 0) {
                    Capsule()
                        .fill(Palette.onTableSoft.opacity(0.12))
                        .frame(height: 11 * lift)
                    Spacer(minLength: 0)
                        .frame(width: [40, 78, 22][index % 3] * lift)
                }
                .frame(height: 26 * lift)
            }
        }
    }

    private func load() async {
        failed = false
        guard let answer = await store.ladderBoard(day: store.today) else {
            failed = true
            return
        }
        board = answer
    }
}

/// One line of the peek: where they came, who they are, and by how much they beat the bot.
private struct PeekRow: View {
    @Environment(\.lift) private var lift
    let place: Int
    let name: String
    let margin: Int
    let isYou: Bool

    /// The top three get a medal: gold, silver, bronze as league 2, 1, 0 — the same reading
    /// the board itself gives a podium.
    private var league: Int? {
        switch place {
        case 1: 2
        case 2: 1
        case 3: 0
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 9 * lift) {
            placeMark
            SeatBadge(name: name, tint: Palette.seat(place), size: 20 * lift)
            Text(verbatim: name)
                .font(.system(size: 13 * lift, weight: isYou ? .bold : .medium))
                .foregroundStyle(isYou ? Palette.goldLight : Palette.onTable)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4 * lift)
            Text(verbatim: signed(margin))
                .font(.system(size: 14 * lift, weight: .bold))
                .monospacedDigit()
                // A flat tint for the top three: the medal is where the metal goes.
                .foregroundStyle(league.map { LeagueMetal.league($0).base } ?? Palette.onTableSoft)
        }
        .frame(height: 26 * lift)
        .padding(.horizontal, isYou ? 7 * lift : 0)
        .background {
            if isYou {
                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                    .fill(Palette.gold.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                            .strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1)
                    }
            }
        }
    }

    @ViewBuilder private var placeMark: some View {
        if let league {
            LeagueMedal(league: league, size: 20 * lift).frame(width: 24 * lift)
        } else {
            Text(verbatim: "\(place)")
                .font(.system(size: 12 * lift, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
                .frame(width: 24 * lift)
        }
    }
}

#Preview {
    LadderPeek(store: TableStore()) {}
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
}
