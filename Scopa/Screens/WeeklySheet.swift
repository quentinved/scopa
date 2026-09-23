import SwiftUI
import ScopaRewards

/// The week, given a room of its own.
///
/// The week's card used to open the ladder on a third tab, which is why the lobby card felt
/// like a lot of space spent on a signpost: a goal, a bar and a laurel, all to arrive at a
/// column of counts. The board is still here — it is the best part — but it comes after the
/// week itself: the crest, the ring, how long is left, and exactly what is at the end of it.
struct WeeklySheet: View {
    let store: TableStore

    @Environment(\.dismiss) private var dismiss
    @State private var board: Ladder.WeeklyBoard?
    @State private var failed = false
    /// Set a beat after the sheet lands, so the ring is caught filling rather than found
    /// already full.
    @State private var landed = false

    private var book: ChallengeBook { store.challenges }
    private var goals: [WeeklyChallenge.Goal] { book.goals }

    var body: some View {
        SheetScaffold(title: "This week", subtitle: subtitle, close: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                crest
                Caption(text: "Tasks")
                    .padding(.top, 4)
                ForEach(goals.indices, id: \.self) { slot in
                    task(slot)
                }
                Caption(text: "Rewards")
                    .padding(.top, 4)
                reward
                Caption(text: "Who is furthest")
                    .padding(.top, 4)
                boardSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .presentationDetents([.large])
        .task { await load() }
        .task {
            // One beat, then the ring runs out to where the week actually stands.
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.8, bounce: 0.15)) { landed = true }
        }
    }

    private var subtitle: LocalizedStringKey {
        book.isFinished ? "Done. The laurel is yours." : "Three tasks, the same ones for everybody."
    }

    // MARK: The crest

    /// The week on a ring of its own progress: the laurel's symbol struck in the middle, the
    /// tasks done under it, and the week's words alongside. The tasks themselves are listed
    /// under it, each with its own count.
    private var crest: some View {
        HStack(alignment: .center, spacing: 18) {
            GoalRing(symbol: "laurel.leading", count: book.tasksDone, target: goals.count,
                     progress: landed ? book.progress : 0, finished: book.isFinished)
            VStack(alignment: .leading, spacing: 6) {
                if book.isFinished { won }
                Text(book.isFinished ? "All \(goals.count) tasks done" : "\(book.tasksDone) of \(goals.count) tasks done")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if book.isFinished {
                        Text("The laurel is on your seat until the week ends.")
                    } else {
                        Text("Each one pays when it is done. The laurel is for finishing all of them.")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
                timeLeft
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .glassPanel(tint: Palette.gold.opacity(book.isFinished ? 0.28 : 0.14))
        .shadow(color: Palette.gold.opacity(book.isFinished ? 0.35 : 0), radius: 24, y: 8)
    }

    /// The line over a finished week's goal. Small caps in gold: the goal keeps the weight.
    private var won: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold))
            Text("The week is yours")
                .textCase(.uppercase)
                .tracking(1.1)
        }
        .font(.system(size: 12, weight: .bold))
        // Flat gold, not the sheen: a gradient across eighteen small capitals darkens the
        // last word to the point of losing it.
        .foregroundStyle(Palette.goldLight)
    }

    @ViewBuilder private var timeLeft: some View {
        if let end = book.endsAt {
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 11, weight: .semibold))
                Text(end, format: .relative(presentation: .named))
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.goldLight.opacity(0.9))
            .padding(.top, 2)
        }
    }

    // MARK: The tasks

    /// One task: what it asks, the line under it, its count on a bar, and what it pays.
    private func task(_ slot: Int) -> some View {
        let goal = goals[slot]
        let done = book.isFinished(slot)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : goal.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(done ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.goldLight))
                .frame(width: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.onTable)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(verbatim: "\(book.counts[slot])/\(goal.target)")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(done ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.onTable))
                        .contentTransition(.numericText())
                }
                Text(goal.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressBar(progress: landed ? book.progress(slot) : 0)
                    .padding(.top, 2)
                HStack(spacing: 5) {
                    DenariMark(size: 12)
                    Text(done ? "Paid \(goal.denari.coins)" : "Pays \(goal.denari.coins)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(done ? Palette.goldLight : Palette.onTableSoft)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control, tint: done ? Palette.gold.opacity(0.18) : nil)
    }

    // MARK: What it pays

    /// The two things for finishing every task, side by side and drawn big enough to be read
    /// as pictures: a coin with a number on it, and the laurel itself.
    ///
    /// They were a mark in the corner over two lines of prose, which meant the prize had to
    /// be read before it was understood. The mark is the tile now and the words under it are
    /// a caption, not the content.
    ///
    /// The laurel is the bare wreath, not the reader's seat wearing one. A whole badge here
    /// carried their initial, their mark and whatever ring they had bought, none of which
    /// the week is giving them: the prize was the one part of the picture that was new. The
    /// caption says where it goes, and the crest above shows it on the seat.
    private var reward: some View {
        HStack(spacing: 10) {
            prize {
                DenariMark(size: 38)
            } value: {
                Text(verbatim: "+\(WeeklyChallenge.allDoneBonus.coins)")
            } caption: {
                Text("Bonus denari")
            }
            prize {
                // Asked for at 30 rather than 34: the wreath draws out to `reach` past the
                // size it is given, so 34 came to 48 in a 44pt slot and leaned on the word
                // under it. At 30 it sits inside the slot and matches the coin beside it.
                HonourWreath(size: 30)
            } value: {
                Text("Laurel")
            } caption: {
                Text("On your seat")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func prize(@ViewBuilder mark: () -> some View, @ViewBuilder value: () -> Text,
                       @ViewBuilder caption: () -> Text) -> some View {
        VStack(spacing: 6) {
            mark().frame(height: 44)
            value()
                .font(.display(30))
                .foregroundStyle(Palette.goldSheen)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            caption()
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .glassPanel(radius: GlassRadius.control, tint: Palette.gold.opacity(0.12))
    }

    // MARK: The board

    @ViewBuilder private var boardSection: some View {
        if let board, !board.isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(Array(board.top.enumerated()), id: \.element.id) { index, row in
                    WeekRow(place: index + 1, row: row, isYou: board.you?.rank == index + 1)
                }
                if let you = board.you, let rank = you.rank, rank > board.top.count {
                    YourWeek(standing: you).padding(.top, 6)
                }
            }
        } else if failed {
            boardNote(symbol: "wifi.slash", title: "The board is not answering",
                      detail: "Your own progress is safe on this phone. Only the board needs the line.")
        } else if board != nil {
            boardNote(symbol: "figure.walk.departure", title: "Nobody has posted this week",
                      detail: "Play a game and the week's board starts with you.")
        } else {
            ProgressView()
                .tint(Palette.onTableSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 90)
        }
    }

    private func boardNote(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.onTable)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .glassPanel(radius: GlassRadius.control)
    }

    private func load() async {
        failed = false
        guard let answer = await store.weeklyBoard(week: book.week) else {
            failed = true
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { board = answer }
    }
}

/// How far through the week, as a ring round the goal's own symbol.
///
/// A bar says the same thing in a tenth of the space, which is exactly why the lobby keeps
/// one and this does not: here the week is the subject, not a line item.
struct GoalRing: View {
    let symbol: String
    let count: Int
    let target: Int
    let progress: Double
    let finished: Bool
    var size: CGFloat = 104

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            Circle()
                .stroke(felt.shade(0.5), lineWidth: size * 0.085)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Palette.goldSheen,
                        style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                // From the top rather than from three o'clock, which is where a clock face
                // and every progress ring anyone has seen starts.
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .foregroundStyle(finished ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.goldLight))
                Text(verbatim: "\(count)/\(target)")
                    .font(.display(size * 0.21))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.gold.opacity(finished ? 0.45 : 0.15), radius: size * 0.13)
    }
}

/// One line of the week's board: how far they got, and the laurel if they finished.
private struct WeekRow: View {
    let place: Int
    let row: Ladder.WeeklyBoard.Row
    let isYou: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(place)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTableSoft)
                .frame(width: 30)
            SeatBadge(name: row.name, tint: Palette.seat(place), size: 30, honoured: row.finished)
                // The laurel reaches past the badge. Reserve its width so the name does not shift.
                .frame(width: 30 * HonourWreath.reach)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.name)
                    .font(.system(size: 15, weight: isYou ? .bold : .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                if row.goal > 0 {
                    Text(row.finished ? "Finished" : "\(row.count) of \(row.goal)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(row.finished ? Palette.goldLight : Palette.onTableSoft)
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: "\(row.count)")
                .font(.display(24))
                .monospacedDigit()
                .foregroundStyle(row.finished ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.onTable))
        }
        .padding(.horizontal, 12)
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

/// The reader's own standing this week, for a player below the top of the board.
private struct YourWeek: View {
    let standing: Ladder.WeeklyStanding

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(standing.rank ?? 0)")
                .font(.display(24))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
            VStack(alignment: .leading, spacing: 2) {
                Text("Where you are")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                Text(standing.finished
                     ? "Finished, with \(standing.count)."
                     : "\(standing.count) of \(standing.goal) so far.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control, tint: Palette.gold.opacity(0.22))
    }
}

#Preview {
    WeeklySheet(store: TableStore())
}
