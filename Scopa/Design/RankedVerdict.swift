import SwiftUI
import ScopaCore

/// What a ranked game did to your league, animated rather than stated.
///
/// The bar runs from where it stood before the game, crosses the division if the game
/// crossed it, and the medal is restruck in the next metal partway through.
///
/// Everything is worked out from two ratings, before and after. The Worker sends the
/// rating it settled on and the change it applied, and `Ranking`, the same maths on both
/// sides of the wire, turns those into the league, the division and the bar.
struct RankedVerdict: View {
    /// A finished ranked game, as the ladder settled it.
    struct Move: Equatable {
        /// The rating before the game and after it. `after - before` is the change applied,
        /// not always the change earned: a league once reached is a floor.
        let before: Int
        let after: Int
        let won: Bool
        /// Wins in a row including this one, as the ladder counts them now.
        var streak: Int = 0

        var change: Int { after - before }
        /// A run worth saying out loud: the second win of one is where it starts paying.
        var isOnARun: Bool { won && streak >= 2 }
        /// A loss the floor swallowed.
        var isHeld: Bool { !won && change == 0 }
    }

    let move: Move

    @Environment(\.locale) private var locale
    /// The plate is cut from the cloth, so it changes with the felt.
    @Environment(\.tableFelt) private var felt

    /// The rating the medal and the title are drawn for. It steps to the new one halfway
    /// through, at the moment the bar runs out of division.
    @State private var shownRating: Int
    /// How full the bar is, 0 to 1. Driven on its own rather than read off `shownRating`,
    /// because a division is crossed as two runs: off the end, then on from the start.
    @State private var bar: Double
    @State private var showsChange = false
    @State private var told: Told?
    /// The light behind the medal at the moment it is restruck.
    @State private var burst = false

    /// The one word this game earned, once the bar has stopped.
    private enum Told { case promoted, demoted, held }

    init(move: Move) {
        self.move = move
        _shownRating = State(initialValue: move.before)
        _bar = State(initialValue: Self.fill(of: move.before))
    }

    private static func fill(of rating: Int) -> Double {
        Double(Ranking.standing(for: rating).progress) / Double(Ranking.pointsPerDivision)
    }

    private var shown: Standing { Ranking.standing(for: shownRating) }
    private var metal: LeagueMetal { .league(shown.league.rawValue) }

    var body: some View {
        HStack(spacing: 14) {
            medal
            details
        }
        .padding(14)
        .background { plate }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .task(id: move) { await tell() }
        .sensoryFeedback(Haptic.take, trigger: showsChange)
        .sensoryFeedback(trigger: told) { _, told in Self.feedback(for: told) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // One line always: the panel is narrow, and a league title broken across
                // two lines takes the bar with it.
                Text(verbatim: shown.leagueTitle(locale: locale))
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                if showsChange, move.change != 0 { chip }
            }
            track
            caption
        }
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(felt.plate())
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(metal.base.opacity(0.45), lineWidth: 1)
            }
    }

    private static func feedback(for told: Told?) -> SensoryFeedback? {
        switch told {
        case .promoted: .success
        case .demoted: .warning
        default: nil
        }
    }

    // MARK: The medal

    private var medal: some View {
        LeagueMedal(league: shown.league.rawValue, size: 46)
            .scaleEffect(burst ? 1.16 : 1)
            .background {
                // Light thrown by the restrike, drawn outside the medal's own frame.
                Circle()
                    .fill(RadialGradient(colors: [metal.light.opacity(burst ? 0.5 : 0), .clear],
                                         center: .center, startRadius: 6, endRadius: 52))
                    .frame(width: 104, height: 104)
            }
            .frame(width: 46, height: 46)
    }

    // MARK: The bar

    private var track: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.6))
                Capsule()
                    .fill(metal.sheen)
                    .frame(width: max(geometry.size.width * bar, bar > 0 ? 7 : 0))
            }
        }
        .frame(height: 7)
    }

    /// What the game was worth, in the metal it was paid in.
    @ViewBuilder private var chip: some View {
        let gained = move.change > 0
        Text(verbatim: gained ? "+\(move.change)" : "−\(abs(move.change))")
            .font(.system(size: 15, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(gained ? Palette.ink : Palette.cream)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background {
                if gained {
                    Capsule().fill(Palette.goldSheen)
                } else {
                    Capsule().fill(Palette.terracotta)
                }
            }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
    }

    /// The run this win is on, at the far end of the line under the bar. Part of what the
    /// game paid is the run, and this is what says so.
    private var runTag: some View {
        Text("\(move.streak) IN A ROW")
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(Palette.goldLight)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    // MARK: The line under it

    /// The word this game earned, and the run behind it where there is one. The word has
    /// the room: the run gives way first.
    private var caption: some View {
        HStack(spacing: 6) {
            word
            if showsChange, move.isOnARun {
                Spacer(minLength: 4)
                runTag
            }
        }
    }

    @ViewBuilder private var word: some View {
        switch told {
        case .promoted:
            word("PROMOTED", tint: Palette.goldLight)
        case .demoted:
            word("DEMOTED", tint: Palette.terracotta)
        case .held:
            Text("Your league holds")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.opacity)
        case nil:
            if let climb {
                Text(verbatim: climb)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func word(_ text: LocalizedStringKey, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .layoutPriority(1)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    /// "15 to Gold III": what the next game is for.
    private var climb: String? { Ranking.climb(from: move.after, locale: locale) }

    private var spoken: String {
        let title = Ranking.standing(for: move.after).leagueTitle(locale: locale)
        if move.isHeld { return String(localized: "Your league holds at \(title)", locale: locale) }
        let change = move.change >= 0
            ? String(localized: "up \(move.change)", locale: locale)
            : String(localized: "down \(abs(move.change))", locale: locale)
        let run = move.isOnARun ? ", " + String(localized: "\(move.streak) wins in a row", locale: locale) : ""
        return "\(title), \(change)\(run)"
    }

    // MARK: The telling

    /// The beats, in order: the change lands, the bar runs, and where the run crosses a
    /// division the medal is restruck between the two halves of it.
    private func tell() async {
        try? await Task.sleep(for: .milliseconds(320))
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { showsChange = true }
        Audio.shared.play(.step)

        guard move.change != 0 else { return await tellHeld() }

        try? await Task.sleep(for: .milliseconds(430))
        let climbing = move.change > 0
        guard Ranking.standing(for: move.before).step != Ranking.standing(for: move.after).step else {
            // Inside one division: one run, and the coins that go with it.
            Audio.shared.play(.denaro)
            withAnimation(.easeInOut(duration: 0.75)) { bar = Self.fill(of: move.after) }
            return
        }
        await crossDivision(climbing: climbing)
    }

    private func tellHeld() async {
        guard move.isHeld else { return }
        try? await Task.sleep(for: .milliseconds(360))
        withAnimation(.easeOut(duration: 0.35)) { told = .held }
    }

    /// The bar runs off the end it is heading for, the medal is restruck, and the bar runs
    /// on again from the far end.
    private func crossDivision(climbing: Bool) async {
        Audio.shared.play(.denaro)
        withAnimation(.easeInOut(duration: 0.55)) { bar = climbing ? 1 : 0 }
        try? await Task.sleep(for: .milliseconds(600))

        // The bar is put back with no animation: sliding it end to end would read as the
        // run going the wrong way.
        Audio.shared.play(climbing ? .purchase : .notice)
        withTransaction(Transaction(animation: nil)) { bar = climbing ? 0 : 1 }
        withAnimation(.snappy(duration: 0.3)) { shownRating = move.after }
        withAnimation(.spring(duration: 0.45, bounce: 0.45)) { burst = true }
        withAnimation(.easeOut(duration: 0.45)) { told = climbing ? .promoted : .demoted }

        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.easeInOut(duration: 0.5)) { bar = Self.fill(of: move.after) }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeOut(duration: 0.7)) { burst = false }
    }
}

extension Ranking {
    /// "45 to Gold III": what the next division costs from where a rating stands. Used by
    /// the lobby as well as the summary.
    static func climb(from rating: Int, locale: Locale) -> String {
        guard rating < top else { return String(localized: "The top of the ladder", locale: locale) }
        let toGo = pointsPerDivision - standing(for: rating).progress
        let next = standing(for: rating + toGo)
        return String(localized: "\(toGo) to \(next.leagueTitle(locale: locale))", locale: locale)
    }
}

extension Standing {
    /// "Silver II", in the interface's language. Twin of the ladder's own title in
    /// `Language.swift`, for a standing worked out on the phone.
    func leagueTitle(locale: Locale) -> String {
        let names: [String] = [
            String(localized: "Bronze", locale: locale), String(localized: "Silver", locale: locale),
            String(localized: "Gold", locale: locale), String(localized: "Platinum", locale: locale),
            String(localized: "Diamond", locale: locale), String(localized: "Maestro", locale: locale),
        ]
        let name = names[safe: league.rawValue] ?? names[0]
        return "\(name) \(["I", "II", "III"][safe: division - 1] ?? "")"
    }
}

#Preview("What a ranked game does") {
    ScrollView {
        VStack(spacing: 16) {
            // A win inside the division, a win that promotes, an ordinary loss, a loss
            // that demotes, and a loss the floor swallowed.
            RankedVerdict(move: .init(before: 430, after: 455, won: true))
            RankedVerdict(move: .init(before: 588, after: 613, won: true))
            RankedVerdict(move: .init(before: 430, after: 456, won: true, streak: 4))
            RankedVerdict(move: .init(before: 455, after: 443, won: false))
            RankedVerdict(move: .init(before: 705, after: 685, won: false))
            RankedVerdict(move: .init(before: 600, after: 600, won: false))
        }
        .padding(20)
    }
    .background(TableGround())
}
