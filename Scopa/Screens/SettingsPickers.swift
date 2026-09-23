import SwiftUI
import ScopaCore
import ScopaRewards

/// A label over a row of chips. The explanation, if any, goes under the chips and
/// changes with the selection.
struct ChipPicker<Option: Hashable, Label: View>: View {
    let title: LocalizedStringKey
    let options: [Option]
    @Binding var selection: Option
    var explanation: LocalizedStringKey?
    @ViewBuilder var label: (Option) -> Label

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button { selection = option } label: { chip(option) }
                        .buttonStyle(.plain)
                }
            }
            if let explanation {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .sound(.toggle, trigger: selection)
    }

    private func chip(_ option: Option) -> some View {
        let picked = selection == option
        return label(option)
            .font(.system(size: 13, weight: picked ? .semibold : .medium))
            .foregroundStyle(picked ? Palette.cream : Palette.onTableSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 36)
            .glass(picked ? .riviera(tint: Palette.terracotta.opacity(0.8), interactive: true) : .identity,
                   in: .rect(cornerRadius: GlassRadius.chip))
            .overlay {
                if !picked {
                    RoundedRectangle(cornerRadius: GlassRadius.chip)
                        .strokeBorder(Palette.onTableSoft.opacity(0.25))
                }
            }
            .contentShape(.rect(cornerRadius: GlassRadius.chip))
    }
}

struct AssistPicker: View {
    @Binding var assist: AssistLevel

    var body: some View {
        ChipPicker(title: "How much help you want", options: AssistLevel.allCases,
                   selection: $assist, explanation: assist.explanation) { level in
            Text(level.label)
        }
    }
}

/// Bot strength for the tables the player sets up. It changes how long a bot thinks, not
/// what it can see.
struct BotPicker: View {
    @Binding var level: BotLevel

    var body: some View {
        ChipPicker(title: "How well the bots play", options: BotLevel.allCases,
                   selection: $level, explanation: level.explanation) { option in
            Text(option.label)
        }
    }
}

/// The game's language, independent of the phone's.
struct LanguagePicker: View {
    @Binding var language: Language

    var body: some View {
        ChipPicker(title: "Language", options: Language.allCases, selection: $language) { option in
            Text(verbatim: option.title)
        }
    }
}

/// The seat marks, each drawn on the player's seat colour, the chosen one ringed.
struct MarkPicker: View {
    let name: String
    @Binding var mark: SeatMark
    let progress: MarkProgress
    /// The marks bought rather than earned.
    let owned: Set<SeatMark>
    /// The colour the marks are struck in, so the picker shows the badge as it will be worn
    /// rather than in a colour the player has already changed.
    var livery: SeatLivery = .tavolo

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(SeatMark.allCases) { option in
                    let unlocked = option.isUnlocked(by: progress) || owned.contains(option)
                    Button {
                        if unlocked { mark = option } else { Audio.shared.play(.refused) }
                    } label: {
                        tile(option, unlocked: unlocked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityHint(unlocked ? "" : option.requirement.map { _ in "Not earned yet" } ?? "")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: mark)
        .sensoryFeedback(.selection, trigger: mark)
    }

    private func tile(_ option: SeatMark, unlocked: Bool) -> some View {
        VStack(spacing: 5) {
            badge(option, unlocked: unlocked)
            if let requirement = option.requirement, !unlocked {
                Text(requirement.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: 72)
    }

    private func badge(_ option: SeatMark, unlocked: Bool) -> some View {
        SeatBadge(name: name, tint: Palette.seat(0), size: 44, mark: option, livery: livery)
            .saturation(unlocked ? 1 : 0)
            .opacity(unlocked ? 1 : 0.4)
            // The ring sits outside whatever the mark wears, so it never cuts across a bezel.
            .overlay {
                Circle()
                    .strokeBorder(Palette.cream, lineWidth: mark == option ? 3 : 0)
                    .padding(-(option.prestige.reach - 1) * 22 - 4)
            }
            .overlay(alignment: .bottomTrailing) {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.cream)
                        .padding(4)
                        .background(Palette.ink.opacity(0.7), in: Circle())
                }
            }
            .scaleEffect(mark == option ? 1.08 : 1)
    }
}
