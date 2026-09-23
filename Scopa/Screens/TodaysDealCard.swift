import SwiftUI
import ScopaCore
import ScopaRewards

/// Today's deck, as a card on the lobby: the date, and either an invitation or the result.
///
/// Two sizes. The long one is kept for the first visit, when it has something to teach,
/// and the walk back from a deal just played. Every other visit it is half a row.
struct TodaysDealCard: View {
    @Environment(\.lift) private var lift
    let book: DailyDealBook
    let day: String
    /// Yesterday's winner, for a number to beat. Nil until the ladder has said.
    var best: Ladder.Best? = nil
    /// The deal was played out a moment ago, and this is the walk back into the lobby.
    var fresh = false
    let play: () -> Void

    /// Set a beat after the card is on screen, so the fanfare is seen happening.
    @State private var landed = false

    private var result: DailyDealResult? { book.result(for: day) }
    private var streak: Int { book.streak(endingOn: day) }
    private var celebrates: Bool { fresh && result != nil }

    @ViewBuilder var body: some View {
        if isFull {
            full
        } else if let result {
            playedTile(result)
        } else {
            unplayedTile
        }
    }

    /// Whether the long version is due. Static because the lobby asks the same question
    /// before laying out the row.
    static func isFull(book: DailyDealBook, day: String, fresh: Bool) -> Bool {
        book.results.isEmpty || (fresh && book.hasPlayed(day))
    }

    private var isFull: Bool { Self.isFull(book: book, day: day, fresh: fresh) }

    // MARK: The full card

    private var full: some View {
        VStack(alignment: .leading, spacing: 10 * lift) {
            fullHeader
            if let result {
                played(result)
            } else {
                unplayed
            }
            nextStreakLine
        }
        .padding(.horizontal, 16 * lift)
        .padding(.vertical, 12 * lift)
        .glassPanel(tint: Palette.gold.opacity(celebrates && landed ? 0.34 : 0.16))
        // Gold on the way in, back to the house tint as it settles.
        .shadow(color: Palette.gold.opacity(celebrates && landed ? 0.45 : 0), radius: 26, y: 8)
        .scaleEffect(celebrates && landed ? 1 : celebrates ? 0.94 : 1)
        .task(id: celebrates) { await celebrate() }
        .sensoryFeedback(trigger: landed) { _, on in on ? Haptic.reveal : nil }
    }

    private var fullHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            // Not a `Caption`: that takes a plain string, looked up in the phone's language.
            Text("Today's deal")
                .font(.system(size: 12 * lift, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Spacer()
            if celebrates, let result {
                Text(result.won ? "You beat Hugo today" : "Played, and in the book")
                    .font(.system(size: 12 * lift, weight: .bold))
                    .foregroundStyle(Palette.goldLight)
                    .transition(.opacity)
            } else {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 12 * lift, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    /// The next mark on the run, and what it pays.
    @ViewBuilder private var nextStreakLine: some View {
        if let next = Streaks.next(after: streak) {
            let more = next.days - streak
            Group {
                if let felt = next.felt {
                    Text("\(more) more days for the \(felt.title) felt")
                } else {
                    Text("\(more) more days for +\(next.denari.coins) denari")
                }
            }
            .font(.system(size: 11 * lift, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
        }
    }

    private func celebrate() async {
        guard celebrates else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.32)) { landed = true }
        Audio.shared.play(.reveal)
        try? await Task.sleep(for: .seconds(2.4))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.9)) { landed = false }
    }

    /// The goal in two lines, then the streak and the button on a row of their own.
    private var unplayed: some View {
        VStack(alignment: .leading, spacing: 12 * lift) {
            VStack(alignment: .leading, spacing: 3 * lift) {
                Text("Everyone gets the same deck today")
                    .font(.system(size: 14 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text("One round against Hugo. Beat him by more than anyone else and you top the day's ladder. One go.")
                    .font(.system(size: 12 * lift))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
            if streak > 0 || best != nil {
                HStack(spacing: 12 * lift) {
                    if streak > 0 {
                        Streak(days: streak)
                    }
                    Spacer(minLength: 0 * lift)
                    if let best {
                        Text("Yesterday's best: \(signed(best.margin))")
                            .font(.system(size: 12 * lift, weight: .semibold))
                            .foregroundStyle(Palette.onTableSoft)
                            .lineLimit(1)
                    }
                }
            }
            Button(action: play) {
                Label("Play today's deal", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(FilledButtonStyle(tint: Palette.gold, foreground: Palette.ink, minHeight: 46))
        }
    }

    private func played(_ result: DailyDealResult) -> some View {
        HStack(alignment: .center, spacing: 16 * lift) {
            VStack(alignment: .leading, spacing: 0 * lift) {
                Text(verbatim: signed(result.margin))
                    .font(.display(36 * lift))
                    .foregroundStyle(result.won ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.onTable))
                    .monospacedDigit()
                Text(result.won ? "Over Hugo" : "Against Hugo")
                    .font(.system(size: 12 * lift, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            VStack(alignment: .leading, spacing: 4 * lift) {
                if let accuracy = result.accuracy {
                    Detail(value: "\(accuracy)%", label: "Accuracy")
                }
                Detail(value: "\(result.mine) – \(result.theirs)", label: "Points")
                if let rank = result.rank, let played = result.played {
                    Detail(value: "#\(rank)", label: "of \(played) today")
                }
            }
            Spacer(minLength: 0 * lift)
            VStack(alignment: .trailing, spacing: 6 * lift) {
                Streak(days: streak)
                Text("Back tomorrow")
                    .font(.system(size: 12 * lift))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    // MARK: The half-row tiles

    /// Not played yet: the coin that plays it, the streak, and the number to beat.
    private var unplayedTile: some View {
        Button(action: play) {
            GoalTile(title: Text("Today's deal"), tint: Palette.gold.opacity(0.16), interactive: true) {
                ZStack {
                    Circle().fill(Palette.goldSheen)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13 * lift, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .offset(x: 1 * lift)
                }
                .frame(width: 30 * lift, height: 30 * lift)
            } stat: {
                Streak(days: streak, tight: true)
            } foot: {
                Group {
                    if let best {
                        Text("\(signed(best.margin)) to beat")
                    } else {
                        Text("One round, one go")
                    }
                }
                .font(.system(size: 11 * lift, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
        }
        .buttonStyle(.plain)
    }

    /// Played: the margin, the streak, and where it put you. Not a button, since today's
    /// deck is spent and the ladder has a row of its own.
    private func playedTile(_ result: DailyDealResult) -> some View {
        GoalTile(title: Text("Today's deal")) {
            Text(verbatim: signed(result.margin))
                .font(.display(26 * lift))
                .monospacedDigit()
                .foregroundStyle(result.won ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.onTable))
        } stat: {
            Streak(days: streak, tight: true)
        } foot: {
            Group {
                if let rank = result.rank, let played = result.played {
                    Text("#\(rank) of \(played)")
                } else if result.won {
                    Text("Over Hugo")
                } else {
                    Text("Against Hugo")
                }
            }
            .font(.system(size: 11 * lift, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }

    private struct Detail: View {
        @Environment(\.lift) private var lift
        let value: String
        let label: LocalizedStringKey

        var body: some View {
            HStack(spacing: 6 * lift) {
                Text(verbatim: value)
                    .font(.system(size: 14 * lift, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
                Text(label)
                    .textCase(.lowercase)
                    .font(.system(size: 12 * lift))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    /// Days in a row, as a small flame. Hidden at zero.
    private struct Streak: View {
        @Environment(\.lift) private var lift
        let days: Int
        /// The row-sized one: the flame and the count, without the capsule.
        var tight = false

        var body: some View {
            if days > 0 {
                if tight {
                    HStack(spacing: 5 * lift) {
                        flame
                        Text(verbatim: "\(days)")
                            .font(.system(size: 13 * lift, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.onTable)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(days) day streak"))
                } else {
                    HStack(spacing: 5 * lift) {
                        flame
                        Text("\(days) day streak")
                            .font(.system(size: 12 * lift, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                    }
                    .padding(.horizontal, 10 * lift)
                    .padding(.vertical, 6 * lift)
                    .glassCapsule()
                }
            }
        }

        private var flame: some View {
            Image(systemName: "flame.fill")
                .font(.system(size: 12 * lift, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
        }
    }
}

/// Made once, after the second deal, and answered either way. Only a yes goes on to the
/// system prompt.
struct ReminderOffer: View {
    let reminders: Reminders
    let book: DailyDealBook

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            Text("A nudge when tomorrow's deal is ready?")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("No") { withAnimation { reminders.decline() } }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            Button("Yes") { Task { await reminders.turnOn(book) } }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.goldLight)
        }
        .padding(.top, 4)
        .transition(.opacity)
    }
}
