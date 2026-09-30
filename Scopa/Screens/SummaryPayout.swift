import SwiftUI
import ScopaRewards

/// What a finished game paid, on the panel the player is already reading: the experience,
/// which a wager that lost everything still earns, the denari straight under it in the same
/// hand, then the lines they came from and the offer to earn them again.
///
/// The coins used to come first, with their lines and the offer between them and the bar,
/// so the total was the first thing a tall panel scrolled away.
struct SummaryPayout: View {
    let earnings: [PayoutLine]
    let doubling: Doubling?
    let experience: Experience.Gain?

    var body: some View {
        VStack(spacing: 9) {
            // Not `Rule`: that one is mixed for the table ground and vanishes on paper.
            Rectangle()
                .fill(Palette.ink.opacity(0.15))
                .frame(height: 1)
            if let experience { ExperienceGainRow(gain: experience) }
            if !earnings.isEmpty {
                total.padding(.top, experience == nil ? 0 : 3)
                ForEach(earnings) { line in self.line(line) }
                if let doubling { doublingButton(doubling) }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: doubling == nil)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: earnings.isEmpty)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// Built like the experience row above it: mark, label, number, at the same sizes.
    private var total: some View {
        let total = earnings.reduce(Denari.zero) { $0 + $1.value }
        return HStack(spacing: 8) {
            DenariMark(size: 15)
            Text(total.isCredit ? "Denari earned" : "Denari lost")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 0)
            Text(verbatim: total.signed)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(total.isCredit ? Palette.ink : Palette.terracotta)
        }
    }

    /// Set in under the total's label, so the lines read as what it is made of.
    private func line(_ line: PayoutLine) -> some View {
        HStack(spacing: 10) {
            Text(line.title)
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 8)
            Text(verbatim: line.value.signed)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.leading, 23)
    }

    private func doublingButton(_ doubling: Doubling) -> some View {
        Button(action: doubling.watch) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                Text("Watch an ad, earn it again")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                if doubling.isWatching {
                    ProgressView().tint(Palette.terracotta)
                } else {
                    DenariLabel(amount: doubling.amount, size: 14, tint: Palette.terracotta, signed: true)
                }
            }
            .foregroundStyle(Palette.terracotta)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Palette.terracotta.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(doubling.isWatching)
        .padding(.top, 2)
        .transition(.opacity)
    }
}

/// The experience a game earned, and the level bar it moved: filling from where it stood
/// before, so the player sees how far this one game took them.
private struct ExperienceGainRow: View {
    let gain: Experience.Gain

    /// Starts where the bar stood before the game and is let go once the row is up.
    @State private var filled = false

    /// A new level starts its bar empty, rather than running backwards from the old one.
    private var startFraction: Double { gain.levelledUp ? 0 : gain.before.fraction }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 15)
                Text("Experience")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                Text(verbatim: "+\(gain.gained) XP")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            bar
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "+\(gain.gained) XP"))
        .accessibilityValue(Text("\(gain.after.toGo) XP to level \(gain.after.number + 1)"))
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.9)) { filled = true }
        }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Text("Level \(gain.after.number)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(gain.levelledUp ? Palette.goldDeep : Palette.inkSoft)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.1))
                    Capsule()
                        .fill(Palette.goldSheen)
                        .frame(width: geometry.size.width * (filled ? gain.after.fraction : startFraction))
                }
            }
            .frame(height: 6)
            // A level just reached is the news; what the next one costs can wait.
            Text(gain.levelledUp ? "Level up!" : "\(gain.after.toGo) XP to level \(gain.after.number + 1)")
                .font(.system(size: 12, weight: gain.levelledUp ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(gain.levelledUp ? Palette.goldDeep : Palette.inkSoft)
        }
    }
}

/// One line of the end-of-game payout: what it was for, and what it came to.
struct PayoutLine: Identifiable, Equatable {
    let id: String
    let title: String
    let value: Denari

    init(id: String, title: String, value: Denari) {
        self.id = id
        self.title = title
        self.value = value
    }

    /// The ledger names an award in English. The panel speaks the interface's language.
    init(_ award: Award, locale: Locale) {
        self.init(id: award.earning.rawValue, title: award.line(locale: locale), value: award.value)
    }
}

/// The offer on the last summary of a game: an ad, watched to the end, for the game's
/// earnings a second time.
struct Doubling {
    let amount: Denari
    /// The ad is up or on its way, so the row takes no second tap.
    let isWatching: Bool
    let watch: () -> Void
}

extension Denari {
    /// "+25", "−200": always with its sign, the way a ledger line reads.
    var signed: String { isCredit ? "+\(coins)" : coins == 0 ? "0" : "−\(-coins)" }
}
