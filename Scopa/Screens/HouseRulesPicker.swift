import SwiftUI
import ScopaCore

/// The regional rules a table may add, any mix at once, two by two. Scopone needs four at
/// the table, so below that it sits greyed with the reason underneath.
struct HouseRulesPicker: View {
    let selection: Set<HouseRule>
    /// How many sit at the table.
    let seats: Int
    /// False for a guest, who sees what the host chose but cannot change it.
    var enabled = true
    let change: (Set<HouseRule>) -> Void

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(text: "House rules")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(HouseRule.allCases, id: \.self) { rule in
                    chip(rule)
                }
            }
            explanations
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .sound(.toggle, trigger: selection)
    }

    private func offered(_ rule: HouseRule) -> Bool { rule != .scopone || seats == 4 }

    private func chip(_ rule: HouseRule) -> some View {
        let picked = selection.contains(rule)
        return Button {
            change(picked ? selection.subtracting([rule]) : selection.union([rule]))
        } label: {
            Text(rule.label)
                .font(.system(size: 14, weight: picked ? .semibold : .medium))
                .foregroundStyle(picked ? Palette.cream : Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
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
        .buttonStyle(.plain)
        .disabled(!enabled || !offered(rule))
        .opacity(offered(rule) ? 1 : 0.4)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    /// What each chosen rule changes, or that nothing does.
    @ViewBuilder private var explanations: some View {
        let chosen = HouseRule.allCases.filter(selection.contains)
        VStack(alignment: .leading, spacing: 4) {
            if chosen.isEmpty {
                line("None: Scopa as the rulebook has it")
            }
            ForEach(chosen, id: \.self) { line($0.explanation) }
            if !offered(.scopone), enabled {
                line("Scopone needs four at the table")
            }
        }
    }

    private func line(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.onTableSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}
