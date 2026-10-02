import SwiftUI
import ScopaCore
import ScopaRewards

/// The card a tapped table opens at the foot of the map: who is sitting there, how hard
/// they play, what the table is, what each star asks, and what winning it pays.
struct CampaignStageCard: View {
    let stage: CampaignStage
    let stars: Int
    let close: () -> Void
    let play: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            facts
            goals
            reward
            Button(action: play) {
                Label(stars > 0 ? "Play again" : "Play", systemImage: "play.fill")
            }
            .buttonStyle(FilledButtonStyle(minHeight: 50))
        }
        .padding(16)
        .glassPanel(tint: stage.region.ground.deep.opacity(0.55))
        .shadow(color: Palette.ink.opacity(0.4), radius: 16, y: 6)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BotFace(tint: Palette.seat(1), size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: stage.place)
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: "\(stage.opponent) · \(stage.region.title) · \(stage.number)/\(Campaign.stages.count)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                closeButton
                StarRow(stars: stars, size: 13)
            }
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.onTable)
                .frame(width: 28, height: 28)
                .glass(.riviera(interactive: true), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: The table

    private var facts: some View {
        FlowRow(spacing: 6) {
            chip { pips }
            chip { Text("To \(stage.target) points") }
            chip { Text(seatingTitle) }
            if let seconds = stage.clock.seconds { chip { Label("\(seconds)-second turns", systemImage: "timer") } }
            if stage.primiera == .classic { chip { Text("Classic primiera") } }
        }
    }

    private var pips: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { pip in
                    Circle()
                        .fill(pip <= stage.difficulty ? Palette.terracotta : Palette.cream.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }
            Text(levelTitle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(levelTitle))
    }

    private var levelTitle: LocalizedStringKey {
        switch stage.level {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    private var seatingTitle: LocalizedStringKey {
        switch stage.seating {
        case .duel: "Heads-up"
        case .three: "Three at the table"
        case .four: "Four at the table"
        case .teams: "In teams, with \(CampaignStage.partner)"
        }
    }

    private func chip(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Palette.onTable)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.ink.opacity(0.28), in: .capsule)
    }

    // MARK: Stars and pay

    private var goals: some View {
        VStack(alignment: .leading, spacing: 5) {
            goal("Win the game")
            goal("Win by \(stage.marginGoal) points or more")
            goal("Sweep \(stage.scopeGoal) scope or more")
        }
    }

    private func goal(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.goldLight)
            Text(text)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Palette.onTable)
        }
    }

    @ViewBuilder private var reward: some View {
        if stars == 0 {
            HStack(spacing: 8) {
                DenariLabel(amount: stage.denari, size: 14, tint: Palette.goldLight, signed: true)
                if stage.isFinale {
                    Text("plus a \(stage.region.pack.title) pack and \(stage.region.prizeTitle)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("for the first win")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
        } else if stars < 3 {
            HStack(spacing: 8) {
                DenariLabel(amount: CampaignStage.threeStarBonus, size: 14, tint: Palette.goldLight, signed: true)
                Text("for all three stars")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }
}

/// Chips that wrap onto a second line rather than squeeze.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
