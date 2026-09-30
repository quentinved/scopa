import SwiftUI
import ScopaCore
import ScopaRewards

/// The review at a glance on the last summary: accuracy, best moves, lessons, and the one
/// lesson most worth going back to.
struct ReviewGlance: View {
    let summary: GameReview.Summary

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Palette.ink.opacity(0.15))
                .frame(height: 1)
            numbers
            if let lesson = summary.lessons.first {
                self.lesson(lesson)
            } else {
                Text("Every move was the one to make.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var numbers: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: "\(summary.accuracy)%")
                .font(.display(26))
                .monospacedDigit()
                .foregroundStyle(Palette.goldSheen)
            Text("Accuracy")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 8)
            Text("\(summary.praiseCount) best")
                .foregroundStyle(Palette.goldDeep)
            Text(verbatim: "·").foregroundStyle(Palette.inkSoft)
            Text("\(summary.lessonCount) lessons")
                .foregroundStyle(summary.lessonCount > 0 ? Palette.terracotta : Palette.inkSoft)
        }
        .font(.system(size: 13, weight: .semibold))
        .monospacedDigit()
    }

    private func lesson(_ lesson: MoveReview) -> some View {
        HStack(spacing: 8) {
            CardView(card: lesson.move.card, width: 24)
            Text(lesson.verdict.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.terracotta)
            Text("Better:")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
            CardView(card: lesson.best.card, width: 24)
            Text(lesson.best.captures.isEmpty
                 ? String(localized: "laid on the table", locale: locale)
                 : String(localized: "taking \(lesson.best.captures.rankList)", locale: locale))
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}

/// One category: its name, what each side had, and once decided, who got the point.
struct ContestRow: View {
    let contest: RoundSummary.Contest
    let tints: [Color]
    let decided: Bool

    var body: some View {
        layout {
            label
            if !stacked { Spacer(minLength: 8) }
            HStack(spacing: stacked ? 0 : 10) {
                ForEach(contest.values.indices, id: \.self) { index in
                    count(at: index)
                        .frame(minWidth: 44, alignment: .trailing)
                        .frame(maxWidth: stacked ? CGFloat.infinity : nil, alignment: stacked ? .center : .trailing)
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: decided)
    }

    private var label: some View {
        HStack(spacing: 6) {
            if contest.sweeps { BroomMark(size: 15) }
            Text(contest.label)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if decided && (contest.isTied || contest.isShared) {
                Text("Tied")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func count(at index: Int) -> some View {
        let won = decided && contest.points[index] > 0
        let lost = decided && contest.points[index] == 0 && !contest.isTied
        return HStack(spacing: 5) {
            Circle()
                .fill(tints[index])
                .frame(width: 7, height: 7)
                .opacity(lost ? 0.4 : 1)
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: contest.values[index])
                    .font(.system(size: 15, weight: won ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(lost ? Palette.inkSoft : Palette.ink)
                    .fixedSize()
                if let detail = contest.details?[safe: index], !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize()
                }
            }
            if won { pointChip(contest.points[index]) }
        }
    }

    private func pointChip(_ points: Int) -> some View {
        Text("+\(points)")
            .font(.system(size: 12, weight: .bold))
            // Its own size: squeezed beside a two-digit count, "+1" came out as a prime mark.
            .fixedSize()
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .glassCapsule(tint: Palette.terracotta)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    /// Three or four sides do not fit beside the label, so it takes a line of its own.
    private var stacked: Bool { contest.values.count > 2 }

    private var layout: AnyLayout {
        stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))
    }
}

/// One side's running total, rolling up a point at a time as the contests are decided.
struct ScoreTile: View {
    let name: String
    let tint: Color
    /// Where the side stood before the round.
    let before: Int
    /// Where it stands now, counting the points awarded so far.
    let value: Int
    /// What the game is played to. Nil on a one-round table.
    let target: Int?
    let emphasised: Bool
    /// Four tiles across a phone: smaller type, tighter padding.
    let compact: Bool

    /// The number on the tile right now, trailing `value` one tick at a time.
    @State private var shown: Int?

    private var numberSize: CGFloat { compact ? 34 : 46 }
    private var gained: Int { (shown ?? before) - before }

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            Text(name)
                .font(.system(size: compact ? 12 : 14, weight: emphasised ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Palette.ink)
            Text(verbatim: "\(shown ?? before)")
                .font(.display(numberSize))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shown ?? before)))
                .foregroundStyle(Palette.ink)
            // Held to one chip of height with or without a chip, so the tiles never jump.
            gainChip.frame(height: 22)
            if let target { race(to: target) }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 10 : 14)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: GlassRadius.control)
                .fill(tint.opacity(emphasised ? 0.16 : 0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassRadius.control)
                .strokeBorder(tint.opacity(gained > 0 ? 0.8 : 0.45), lineWidth: 1.5)
        }
        .animation(.snappy(duration: 0.22), value: shown)
        .task(id: value) { await roll() }
        .sensoryFeedback(trigger: shown) { old, new in old != nil && new != nil ? Haptic.step : nil }
        .sound(trigger: shown) { old, new in old != nil && new != nil ? .clock : nil }
    }

    @ViewBuilder private var gainChip: some View {
        if gained > 0 {
            Text("+\(gained)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .glassCapsule(tint: Palette.terracotta)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    /// How far along the road to the target the side is.
    private func race(to target: Int) -> some View {
        let current = shown ?? before
        let fraction = min(Double(current) / Double(max(target, 1)), 1)
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geometry.size.width * fraction, current > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
            Text(verbatim: "\(target)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Counts up to the new total one tick at a time.
    private func roll() async {
        let from = shown ?? before
        guard value > from else { shown = value; return }
        for next in (from + 1)...value {
            if next > from + 1 { try? await Task.sleep(for: .milliseconds(170)) }
            guard !Task.isCancelled else { return }
            shown = next
        }
    }
}
