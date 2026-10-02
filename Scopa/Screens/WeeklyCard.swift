import SwiftUI
import ScopaRewards

/// The week's tasks on the lobby: what they ask, how far along each is, and what is at the
/// end of them.
///
/// It sits under the daily deal: the deal takes one round, this takes the week, and the
/// lobby should not ask for a commitment before it offers a game.
struct WeeklyCard: View {
    @Environment(\.lift) private var lift
    let book: ChallengeBook
    /// Half a row, beside the day's deal: the task in hand, its count and a bar per task, and
    /// none of the small print. The card keeps its full size only on the days the deal takes
    /// the row.
    var narrow = false
    /// The seat the laurel is worn on, so a finished week shows the reader's own badge
    /// rather than an empty disc.
    var name = ""
    var mark: SeatMark = .initial
    var cornice: Cornice = .none
    /// Opens the week's own room, which is where the goal, what it pays and everybody
    /// else's count are.
    let open: () -> Void

    @Environment(\.locale) private var locale
    /// Set a beat after the card lands, so the laurel is caught arriving rather than found
    /// already there.
    @State private var landed = false
    /// Tasks finished since the card was last seen, given their flourish once.
    @State private var fresh: Set<Int> = []

    private var goals: [WeeklyChallenge.Goal] { book.goals }

    /// The task the tile names: the first one still open, or the last once all are done.
    private var slot: Int { goals.indices.first { !book.isFinished($0) } ?? goals.count - 1 }

    /// The circle the week's laurel is struck on. The tile's corner is cut for a laurel
    /// and no more; a bought ring round the same badge reaches half as far again, which
    /// put flowers through the goal's own title. The ring is paid for out of the circle
    /// instead, so a decorated seat takes exactly the room a bare one does.
    private func laurel(_ size: CGFloat) -> CGFloat {
        SeatBadge.fitted(size, mark: mark, honoured: true, cornice: cornice)
    }

    var body: some View {
        Button(action: open) {
            if narrow {
                tile
            } else {
                VStack(alignment: .leading, spacing: 10 * lift) {
                    header
                    if book.isFinished { finished } else { unfinished }
                }
                .padding(.horizontal, 16 * lift)
                .padding(.vertical, 12 * lift)
                .glassPanel(tint: book.isFinished ? Palette.gold.opacity(0.26) : nil, interactive: true)
            }
        }
        .buttonStyle(.plain)
        .task(id: book.isFinished) {
            guard book.isFinished else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { landed = true }
        }
        .task(id: book.tasksDone) { fresh = book.spendNewlyDone() }
    }

    /// Half the goals row: the task in hand is the title here, since at this size a caption
    /// saying "this week" over a line saying what to do is a line spent on nothing. The foot
    /// keeps the other tasks in sight, one bar each, so the tile never pretends there is only
    /// one.
    ///
    /// A won week says how many tasks it took rather than naming the last one, which would
    /// hang a laurel on a third of the week.
    private var tile: some View {
        GoalTile(title: book.isFinished ? Text("All \(goals.count) tasks done") : Text(goals[slot].title),
                 tint: book.isFinished ? Palette.gold.opacity(0.26) : nil, interactive: true) {
            tileMark
        } stat: {
            Text(verbatim: book.isFinished ? "\(goals.count)/\(goals.count)"
                                           : "\(book.counts[slot])/\(goals[slot].target)")
                .font(.system(size: 14 * lift, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(book.isFinished ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.onTable))
                .contentTransition(.numericText())
        } foot: {
            tileFoot
        }
        .animation(.snappy, value: book.counts)
    }

    /// How long is left goes beside the symbol rather than with the count, so the tile has
    /// one figure on each side. Without it a goal of forty sweeps looks the same on Sunday
    /// night as it did on Monday morning.
    @ViewBuilder private var tileMark: some View {
        if book.isFinished {
            SeatBadge(name: name, tint: Palette.seat(0), size: laurel(28 * lift), mark: mark,
                      honoured: true, cornice: cornice)
                .scaleEffect(landed ? 1 : 0.8)
        } else {
            HStack(spacing: 7 * lift) {
                Image(systemName: goals[slot].symbol)
                    .font(.system(size: 19 * lift, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                if let daysLeft {
                    daysLeft
                        .font(.system(size: 11 * lift, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }

    @ViewBuilder private var tileFoot: some View {
        if book.isFinished {
            Text("The week is yours")
                .font(.system(size: 11 * lift, weight: .bold))
                .foregroundStyle(Palette.goldLight)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } else {
            // Centred in the foot, so it lines up with the deal's small print rather than
            // hanging under it.
            TaskBars(book: book, fresh: fresh)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    /// How much of the week is left, in whole days: the question is how many evenings are
    /// left. The last day says so in words, since "1 day left" promises more than it has.
    private var daysLeft: Text? {
        guard let end = book.endsAt else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        guard days > 1 else { return days > 0 ? Text("Last day") : nil }
        return Text("\(days) days left")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("This week")
                .font(.system(size: 12 * lift, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 8 * lift)
            // How long is left, so a week that is nearly over reads as one.
            if let end = book.endsAt {
                Text(end, format: .relative(presentation: .named))
                    .font(.system(size: 12 * lift, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
            }
        }
    }

    /// Still going: every task with its own bar, and what the lot pays.
    private var unfinished: some View {
        VStack(alignment: .leading, spacing: 10 * lift) {
            ForEach(goals.indices, id: \.self) { slot in
                goalRow(slot)
            }
            HStack(spacing: 6 * lift) {
                DenariMark(size: 13 * lift)
                Text("\(WeeklyChallenge.allDoneBonus.coins) more and the laurel for all \(goals.count)")
                    .font(.system(size: 11 * lift, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .animation(.snappy, value: book.counts)
    }

    /// One task: its symbol, what it asks, and its count over a bar of its own. A done task
    /// trades its symbol for a seal, its count for "Done" and its bar for a gold ribbon, so
    /// a full bar is never mistaken for a nearly full one.
    private func goalRow(_ slot: Int) -> some View {
        let goal = goals[slot]
        let done = book.isFinished(slot)
        return HStack(spacing: 12 * lift) {
            Image(systemName: done ? "checkmark.seal.fill" : goal.symbol)
                .font(.system(size: 16 * lift, weight: .semibold))
                .foregroundStyle(done ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.goldLight))
                .frame(width: 26 * lift)
            VStack(alignment: .leading, spacing: 5 * lift) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.title)
                        .font(.system(size: 14 * lift, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    Spacer(minLength: 6 * lift)
                    if done {
                        DoneTag()
                    } else {
                        Text(verbatim: "\(book.counts[slot])/\(goal.target)")
                            .font(.system(size: 13 * lift, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.onTable)
                            .contentTransition(.numericText())
                    }
                }
                TaskBar(progress: book.progress(slot), done: done, flourish: fresh.contains(slot), height: 4)
            }
        }
    }

    /// Done: the laurel itself, at a size worth looking at, and where it goes.
    private var finished: some View {
        HStack(spacing: 14 * lift) {
            SeatBadge(name: name, tint: Palette.seat(0), size: laurel(34 * lift), mark: mark,
                      honoured: true, cornice: cornice)
                .padding(.horizontal, 6 * lift)
                .scaleEffect(landed ? 1 : 0.8)
            VStack(alignment: .leading, spacing: 2 * lift) {
                Text("All \(goals.count) tasks done")
                    .font(.system(size: 15 * lift, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                Text("Won. The laurel is on your seat until the week ends.")
                    .font(.system(size: 12 * lift))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0 * lift)
            Text(verbatim: "\(goals.count)/\(goals.count)")
                .font(.display(28 * lift))
                .monospacedDigit()
                .foregroundStyle(Palette.goldSheen)
        }
    }
}

/// The week's tasks as a row of short bars, one each, for places with room for one line.
/// A single bar averaged over three tasks would fill to a third with one of them done and
/// the other two untouched, which reads as a third of the way to nothing in particular.
struct TaskBars: View {
    @Environment(\.lift) private var lift
    let book: ChallengeBook
    var fresh: Set<Int> = []

    var body: some View {
        HStack(spacing: 4 * lift) {
            ForEach(book.goals.indices, id: \.self) { slot in
                TaskBar(progress: book.progress(slot), done: book.isFinished(slot),
                        flourish: fresh.contains(slot))
            }
        }
    }
}

/// One task's bar: how far along while it is open, a sealed gold ribbon once it is done.
struct TaskBar: View {
    let progress: Double
    let done: Bool
    var flourish = false
    var height: CGFloat = 6

    var body: some View {
        if done {
            DoneRibbon(height: height, flourish: flourish)
        } else {
            ProgressBar(progress: progress, height: height)
        }
    }
}

/// A finished task's bar: solid gold, a shade taller than the open ones, with a struck seal
/// at its end. A full bar on its own read as one that was nearly full.
///
/// The first time a finish is seen a light runs along the ribbon once and the seal is
/// struck; nothing moves after that, since the lobby keeps no forever animations.
struct DoneRibbon: View {
    @Environment(\.lift) private var lift
    var height: CGFloat = 6
    var flourish = false

    @State private var sweep: CGFloat = -0.6
    @State private var struck = true

    private var ribbon: CGFloat { (height + 2) * lift }
    private var seal: CGFloat { max(height * 2.2, 13) * lift }

    var body: some View {
        Capsule()
            .fill(Palette.goldSheen)
            .overlay { shine }
            .clipShape(.capsule)
            .overlay { Capsule().strokeBorder(Palette.goldLight.opacity(0.7), lineWidth: 0.5) }
            .frame(height: ribbon)
            .padding(.trailing, seal * 0.35)
            .overlay(alignment: .trailing) { DoneSeal(size: seal).scaleEffect(struck ? 1 : 0.2) }
            .frame(height: seal)
            .shadow(color: Palette.gold.opacity(0.45), radius: 3)
            .task(id: flourish) { await strike() }
            .sensoryFeedback(trigger: struck) { old, new in !old && new ? Haptic.step : nil }
    }

    /// A band of light, parked off the end until the flourish runs it across once.
    private var shine: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, Palette.cream.opacity(0.9), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.5)
                .offset(x: sweep * proxy.size.width)
        }
    }

    private func strike() async {
        guard flourish else { return }
        struck = false
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 0.9)) { sweep = 1.1 }
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.spring(duration: 0.45, bounce: 0.55)) { struck = true }
    }
}

/// The seal at the end of a finished task's ribbon: a gold disc with a tick struck in ink.
struct DoneSeal: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.52, weight: .black))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background { Circle().fill(Palette.goldSheen) }
            .overlay { Circle().strokeBorder(Palette.goldDeep, lineWidth: max(size * 0.07, 1)) }
    }
}

/// "Done", in place of a finished task's count: "5/5" read too much like "4/5".
struct DoneTag: View {
    @Environment(\.lift) private var lift
    var size: CGFloat = 11

    var body: some View {
        Text("Done")
            .textCase(.uppercase)
            .font(.system(size: size * lift, weight: .heavy))
            .tracking(1)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8 * lift)
            .padding(.vertical, 3 * lift)
            .background { Capsule().fill(Palette.goldSheen) }
            .fixedSize()
    }
}

/// How far along, as a bar. Its own view because the lobby, the board and the summary all
/// want the same one and a rounded rectangle is easy to draw three slightly different ways.
struct ProgressBar: View {
    @Environment(\.lift) private var lift
    let progress: Double
    var height: CGFloat = 6

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.45))
                Capsule()
                    .fill(Palette.goldSheen)
                    // Never a sliver of nothing: a bar showing one game's worth of progress
                    // should be visible, and zero should be honestly empty.
                    .frame(width: progress > 0 ? max(proxy.size.width * min(progress, 1), height) : 0)
            }
        }
        .frame(height: height)
        .overlay { Capsule().strokeBorder(Palette.goldDeep.opacity(0.35), lineWidth: 0.5) }
    }
}
