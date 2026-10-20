import SwiftUI
import ScopaCore

/// The coach at a practice table, where the coach's strip sits at any other: the rule and
/// how far through the hand you are, what is happening and why, and while a bot waits to
/// move, the tap that lets it. The card to play wears the coach's star; see `RulePractice.marks`.
struct PracticeCoach: View {
    let store: TableStore
    let practice: RulePractice
    let view: PlayerView
    let stage: Stage

    /// The move whose wait has been let go, so its button goes the moment it is tapped.
    @State private var released: Int?

    private var beat: Int? { practice.beat(in: view) }
    private var line: PracticeLine { practice.line(in: view) }
    private var holdsTheBots: Bool { line.waits && !view.isMyTurn && beat != nil && released != beat }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                progress
                Spacer(minLength: 6)
                if holdsTheBots { nextButton }
            }
            .frame(height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(line.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(line.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // A new line fades in, so a change is noticed without anything moving.
            .id(beat)
            .transition(.opacity)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(minHeight: stage.pick(tall: 104, wide: 96), alignment: .top)
        .glassPanel(radius: GlassRadius.control)
        .animation(.easeInOut(duration: 0.3), value: beat)
        .animation(.easeOut(duration: 0.2), value: holdsTheBots)
        .onChange(of: beat, initial: true) { _, _ in holdIfWaiting() }
        .task(id: holdsTheBots ? beat : nil) { await readForMe() }
    }

    /// "Napola · 2/6" through the laid-out hand, "Practice · Napola" after it.
    @ViewBuilder private var progress: some View {
        if let beat, let count = practice.deal?.moves.count {
            Caption(verbatim: "\(practice.rule.name) · \(beat + 1)/\(count)")
        } else {
            Caption(text: "Practice · \(practice.rule.name)")
        }
    }

    private var nextButton: some View {
        Button(beat == 0 ? "Start" : "Next", action: release)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .glassCapsule(tint: Palette.terracotta)
            .contentShape(.capsule)
            .buttonStyle(.plain)
            .transition(.opacity)
    }

    /// The bots wait while a line that asks to be read is up. Set on arrival as well as on
    /// each move: the bot's pause before it plays outlasts the view reaching here.
    private func holdIfWaiting() {
        guard holdsTheBots else { return }
        store.holdBots(for: RulePractice.hold)
    }

    private func release() {
        released = beat
        Audio.shared.play(.tap)
        store.releaseBots()
    }

    /// `-autoPlay` taps "Next" after a reader's pause, so a practice hand plays itself through.
    private func readForMe() async {
        guard DebugLaunch.playsItself, holdsTheBots else { return }
        try? await Task.sleep(for: .seconds(2))
        if !Task.isCancelled, holdsTheBots { release() }
    }
}

/// The end of a practice table: the round counted the usual way, the rule's own line in
/// it, then the way on. It pays nothing and offers no review.
struct PracticeSummary: View {
    let store: TableStore
    let practice: RulePractice
    let view: PlayerView
    var totalsTold: Binding<Bool>

    @Environment(\.locale) private var locale

    var body: some View {
        RoundSummary(score: store.lastRoundScore, view: view, home: store.homeSeat, showsAction: true,
                     caption: String(localized: "Practice · \(practice.rule.name)", locale: locale),
                     title: title, isFinal: true, totalsTold: totalsTold,
                     showsTarget: practice.deal == nil,
                     again: { store.playPractice(practice.rule, free: true) },
                     againTitle: "Keep playing",
                     leaveTitle: "Back to the campaign") {
            store.leaveTable()
        }
    }

    /// The laid-out hand is about the rule, not the result. A free game says who won it.
    private var title: String {
        guard practice.deal == nil, case .finished(let winner) = view.phase else {
            return String(localized: "You've got it", locale: locale)
        }
        let teams = view.configuration.teams
        if winner == view.mySide { return String(localized: teams ? "We win!" : "You win!", locale: locale) }
        let name = view.configuration.players[safe: winner]?.name ?? ""
        return teams ? String(localized: "They win", locale: locale) : String(localized: "\(name) wins", locale: locale)
    }
}

// MARK: - The way in

extension EnvironmentValues {
    /// Sits down at the practice table for a house rule. Set by the campaign's map, nil elsewhere.
    @Entry var practiseRule: ((HouseRule) -> Void)? = nil
}

/// "Try it": the practice table for a rule, wherever the campaign names one.
struct TryRuleButton: View {
    let rule: HouseRule

    @Environment(\.practiseRule) private var practise

    var body: some View {
        if let practise {
            Button {
                Audio.shared.play(.tap)
                practise(rule)
            } label: {
                Label("Try it", systemImage: "graduationcap.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .glassCapsule(tint: Palette.terracotta)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }
}
