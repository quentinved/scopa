import SwiftUI
import ScopaCore
import ScopaRewards

/// What happened this round, told as a series of contests: for each category the sides'
/// counts go up first, then the point is awarded and rolls into the winner's total. Then
/// the headline says who took the round. A tap moves to the next beat without waiting.
struct RoundSummary: View {
    let score: RoundScore?
    let view: PlayerView
    /// False when the table is waiting on somebody else to move things on.
    let showsAction: Bool
    /// "Round 3", or "Game over".
    let caption: String
    /// Who took it.
    let title: String
    let isFinal: Bool
    /// Set once the totals have finished rolling, so the strip behind the panel can stop
    /// holding back the round's points. See `TableScreen.stripScore`.
    var totalsTold: Binding<Bool> = .constant(false)
    /// What the game paid, on the last summary of a game.
    var earnings: [PayoutLine] = []
    /// The offer to earn it again for an ad. Nil when there is nothing to offer.
    var doubling: Doubling? = nil
    /// What the game was worth in experience, on the last summary of a game.
    var experience: Experience.Gain? = nil
    /// Opens the review of the finished game. Nil until there is one to open.
    var review: (() -> Void)? = nil
    /// The review in a glance, shown on the panel once it has been read back.
    var glance: GameReview.Summary? = nil
    /// False on a one-round table, where there is no race to a target.
    var showsTarget = true
    /// One line under everything else: the league after a ranked game.
    var footnote: String? = nil
    /// What the ladder did about a ranked game. Takes the footnote's place once the ladder
    /// has answered with a change to show.
    var verdict: RankedVerdict.Move? = nil
    /// True while the phone is still waiting on the ladder.
    var awaitingLadder = false
    /// Deals the same table again, where this phone is allowed to. Nil for a guest.
    var again: (() -> Void)? = nil
    let action: () -> Void

    /// How far the telling has got. Zero is the caption and the totals before the round.
    @State private var revealed = 0
    /// The portrait column's height, so the panel is only as tall as its content and
    /// scrolls when that outgrows a smaller phone.
    @State private var columnHeight: CGFloat?
    /// The landscape details' height, which says when the payout has been laid out.
    @State private var detailsHeight: CGFloat?
    /// Bumped by a tap, so the pacing restarts from the beat just made.
    @State private var pacing = 0

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.locale) private var locale
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    /// The sides, everyone else first and you last: the order the tiles are laid out in.
    private var order: [Int] {
        view.scores.indices.filter { $0 != view.mySide } + [view.mySide]
    }

    /// One category contested: what each side had, and what each side got for it.
    /// Both indexed like `order`.
    struct Contest: Identifiable {
        let id: String
        let label: String
        let values: [String]
        let points: [Int]
        let sweeps: Bool
        /// Under each value, what it is made of. Only the primiera has one.
        var details: [String]? = nil

        var isTied: Bool { points.allSatisfy { $0 == 0 } }
        /// Level, at a table that pays both sides for it. Sweeps are never shared.
        var isShared: Bool { !sweeps && points.count { $0 > 0 } > 1 }
    }

    private var contests: [Contest] {
        guard let score else { return [] }
        var list = ScoreCategory.allCases.map { contest(for: $0, in: score) }
        if score.scope.contains(where: { $0 > 0 }) {
            list.append(Contest(id: "scopa", label: String(localized: "Scopa", locale: locale),
                                values: order.map { "\(score.scope[$0])" },
                                points: order.map { score.scope[$0] }, sweeps: true))
        }
        return list
    }

    private func contest(for category: ScoreCategory, in score: RoundScore) -> Contest {
        let tallies = score.tallies[category] ?? Array(repeating: 0, count: score.points.count)
        return Contest(
            id: category.rawValue,
            label: label(for: category),
            values: order.map { side in
                // The seven is had or not had. A count of one would read as a score.
                category == .settebello ? (tallies[side] > 0 ? "✓" : "–") : "\(tallies[side])"
            },
            // Read off the score, not worked out from the winner: a shared category pays
            // with no winner at all.
            points: order.map { score.points(for: category, side: $0) },
            sweeps: false,
            details: primieraDetails(in: score, for: category)
        )
    }

    /// "7 7 6 1" under a primiera score. Under the sevens rule the value already is the
    /// count of sevens, so there is nothing to explain.
    private func primieraDetails(in score: RoundScore, for category: ScoreCategory) -> [String]? {
        guard category == .primiera, view.configuration.primiera != .mostSevens else { return nil }
        return order.map { side in
            (score.primieraCards[safe: side] ?? []).map { "\($0.rank.rawValue)" }.joined(separator: " ")
        }
    }

    // The beats, counted from one. Every contest takes two: the counts, then the point.
    private func countsStep(_ index: Int) -> Int { index * 2 + 1 }
    private func pointStep(_ index: Int) -> Int { index * 2 + 2 }
    private var headlineStep: Int { contests.count * 2 + 1 }
    private var detailStep: Int { headlineStep + 1 }

    /// Whether the game just ended this player's way. Only meaningful on the last summary.
    private var wonIt: Bool {
        if case .finished(let winner) = view.phase { return winner == view.mySide }
        return false
    }

    /// Where a side stood before the round.
    private func base(_ side: Int) -> Int {
        view.scores[side] - (score?.points[side] ?? 0)
    }

    /// Where a side stands once the points awarded so far are counted.
    private func running(_ index: Int) -> Int {
        var total = base(order[index])
        for (contest, item) in contests.enumerated() where revealed >= pointStep(contest) {
            total += item.points[index]
        }
        return total
    }

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.32).ignoresSafeArea()
            Group {
                if stage.isWide { wide } else { tall }
            }
            .padding(24)
            .glassPanel(tint: Palette.stock.opacity(0.9))
            .padding(.horizontal, 24)
            .padding(.vertical, stage.pick(tall: 0, wide: 12))
            .contentShape(.rect)
            .onTapGesture { skipAhead() }
        }
        .task(id: pacing) { await tell() }
        .sensoryFeedback(trigger: revealed) { old, new in
            new == headlineStep && new > old ? Haptic.reveal : nil
        }
        .sound(trigger: revealed) { old, new in beatSound(from: old, to: new) }
        .onChange(of: earnings.isEmpty || revealed < detailStep) { hidden, _ in
            guard hidden else { return }
            Audio.shared.play(.denaro)
            Audio.shared.play(.denaro, gain: 0.7, after: .milliseconds(150))
        }
        .onChange(of: totalsAreTold, initial: true) { _, told in totalsTold.wrappedValue = told }
    }

    /// Every category has been given out and the totals have stopped moving.
    private var totalsAreTold: Bool { revealed >= contests.count * 2 }

    /// Every beat ticks. The headline plays the round's own sound.
    private func beatSound(from old: Int, to new: Int) -> Sound? {
        guard new > old else { return nil }
        if new < headlineStep { return .step }
        guard new == headlineStep else { return nil }
        return isFinal ? (wonIt ? .victory : .defeat) : .reveal
    }

    private func skipAhead() {
        guard revealed < detailStep else { return }
        advance()
        pacing += 1
    }

    private func advance() {
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { revealed += 1 }
    }

    /// One beat at a time. The counts hang for a second before the point is given, and the
    /// point waits for the total to finish rolling before the next category comes up.
    private func tell() async {
        try? await Task.sleep(for: .milliseconds(revealed == 0 ? 800 : 300))
        while revealed < detailStep, !Task.isCancelled {
            let next = revealed + 1
            advance()
            try? await Task.sleep(for: pause(after: next))
        }
    }

    private func pause(after step: Int) -> Duration {
        guard step < headlineStep else { return .milliseconds(800) }
        let index = (step - 1) / 2
        guard step != countsStep(index) else { return .milliseconds(1000) }
        let rolled = contests[index].points.max() ?? 0
        return .milliseconds(500 + 170 * rolled + (index == contests.count - 1 ? 300 : 0))
    }

    // MARK: Layouts

    /// Portrait: one column. Sized to its content until that is taller than the phone,
    /// then it scrolls and the last beat brings the buttons into view.
    private var tall: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    heading
                    tiles
                    if !contests.isEmpty { rows }
                    if hasPayout && revealed >= detailStep { payout }
                    if let glance, revealed >= detailStep { ReviewGlance(summary: glance) }
                    if revealed >= detailStep { ladder }
                    actionArea.id("actions")
                }
                .animation(.spring(duration: 0.45, bounce: 0.2), value: glance == nil)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .frame(maxHeight: columnHeight ?? .infinity)
            // Keyed on the column's height and let settle first: on the beat itself the
            // payout and the review were still springing in, and there was nothing to scroll.
            .task(id: revealed >= detailStep ? columnHeight : nil) {
                guard revealed >= detailStep, await settled() else { return }
                withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo("actions", anchor: .bottom) }
            }
        }
    }

    /// Landscape: the totals on the left, the contests on the right in their own scroll.
    private var wide: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                heading
                tiles
                Spacer(minLength: 0)
            }
            VStack(spacing: 14) {
                wideDetails
                actionArea
            }
        }
    }

    /// The contests, then what the game paid. Too short a column for both, so once the
    /// payout is up it is scrolled to: the experience at the top, the coins under it.
    private var wideDetails: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if !contests.isEmpty { rows }
                    if hasPayout && revealed >= detailStep { payout.id("payout") }
                    if let glance, revealed >= detailStep { ReviewGlance(summary: glance) }
                    if revealed >= detailStep { ladder }
                }
                .animation(.spring(duration: 0.45, bounce: 0.2), value: glance == nil)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { detailsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Waits for the payout to be laid out, like the portrait column.
            .task(id: hasPayout && revealed >= detailStep ? detailsHeight : nil) {
                guard hasPayout, revealed >= detailStep, await settled() else { return }
                withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo("payout", anchor: .top) }
            }
        }
    }

    /// Waits out the spring a new section arrives on. False when the layout moved again first.
    private func settled() async -> Bool {
        (try? await Task.sleep(for: .milliseconds(500))) != nil
    }

    // MARK: Sections

    /// The ladder's answer: the moving league, the wait for it, or a line of small type.
    @ViewBuilder private var ladder: some View {
        if let verdict {
            RankedVerdict(move: verdict)
        } else if awaitingLadder {
            counting
        } else if let footnote {
            note(footnote)
        }
    }

    private var counting: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(Palette.inkSoft)
            Text("The ladder is counting…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .transition(.opacity)
    }

    private func note(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "rosette")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.gold)
            Text(verbatim: text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .transition(.opacity)
    }

    /// The caption from the start, the headline after the last point has gone home.
    private var heading: some View {
        VStack(spacing: 4) {
            // "Game over" at the top would give the ending away before the counts have
            // told it, so the last summary keeps the round's caption until the headline.
            Group {
                if isFinal && revealed < headlineStep && showsTarget {
                    Text("Round \(view.roundNumber)")
                } else {
                    Text(verbatim: caption)
                }
            }
            .textCase(.uppercase)
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Palette.inkSoft)
            Text(title.uppercased())
                .font(.display(stage.pick(tall: 38, wide: 30)))
                .multilineTextAlignment(stage.pick(tall: TextAlignment.center, wide: .leading))
                .foregroundStyle(isFinal ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink))
                .opacity(revealed >= headlineStep ? 1 : 0)
                .scaleEffect(revealed >= headlineStep ? 1 : 0.7)
        }
        .frame(maxWidth: .infinity, alignment: stage.pick(tall: Alignment.center, wide: .leading))
        .animation(.spring(duration: 0.5, bounce: 0.4), value: revealed >= headlineStep)
    }

    /// One tile per side, carrying the running total.
    private var tiles: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(order.enumerated()), id: \.element) { index, side in
                ScoreTile(
                    name: name(of: side),
                    tint: Palette.seat(side, teams: view.configuration.teams),
                    before: base(side),
                    value: running(index),
                    target: showsTarget ? view.configuration.targetScore : nil,
                    emphasised: side == view.mySide,
                    compact: order.count > 2
                )
            }
        }
    }

    /// The contests, each appearing with its counts and then getting its verdict.
    private var rows: some View {
        VStack(spacing: 10) {
            ForEach(Array(contests.enumerated()), id: \.element.id) { index, contest in
                if revealed >= countsStep(index) {
                    ContestRow(contest: contest,
                               tints: order.map(Palette.seat),
                               decided: revealed >= pointStep(index))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    private var actionArea: some View {
        Group {
            if showsAction {
                buttons
            } else {
                Text("Waiting for the host")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .opacity(revealed >= detailStep ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: revealed >= detailStep)
        .allowsHitTesting(revealed >= detailStep)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if let review {
                Button("Review the game", action: review)
                    .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink,
                                                   minHeight: stage.pick(tall: 50, wide: 44)))
            }
            if isFinal, let again {
                Button("Play again", action: again)
                    .buttonStyle(FilledButtonStyle(minHeight: stage.pick(tall: 56, wide: 48)))
                Button("Back to the lobby", action: action)
                    .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink,
                                                   minHeight: stage.pick(tall: 50, wide: 44)))
            } else {
                Button(isFinal ? "Back to the lobby" : "Deal again", action: action)
                    .buttonStyle(FilledButtonStyle(minHeight: stage.pick(tall: 56, wide: 48)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: review == nil)
    }

    private var hasPayout: Bool { !earnings.isEmpty || experience != nil }

    private var payout: some View {
        SummaryPayout(earnings: earnings, doubling: doubling, experience: experience)
    }

    // MARK: Copy

    private func label(for category: ScoreCategory) -> String {
        switch category {
        case .cards: String(localized: "Most cards", locale: locale)
        case .coins: String(localized: "Most coins", locale: locale)
        case .settebello: String(localized: "Seven of coins", locale: locale)
        case .primiera: view.configuration.primiera == .mostSevens
            ? String(localized: "Sevens", locale: locale)
            : String(localized: "Primiera", locale: locale)
        }
    }

    private func name(of side: Int) -> String {
        guard view.configuration.teams else {
            return view.configuration.players[safe: side]?.name
                ?? String(localized: "Seat \(side + 1)", locale: locale)
        }
        return side == view.mySide
            ? String(localized: "Us", locale: locale)
            : String(localized: "Them", locale: locale)
    }
}
