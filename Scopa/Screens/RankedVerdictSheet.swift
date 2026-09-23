import SwiftUI
import ScopaCore

/// Every ending a ranked game has, on one screen, for checking the animation. Reached
/// with the `-verdict` launch argument. "Again" replays the bars.
struct RankedVerdictSheet: View {
    @State private var take = 0

    private struct Case: Identifiable {
        let id: String
        let caption: String
        let move: RankedVerdict.Move
    }

    /// 600 is the floor of Gold, so the last case is a loss the floor swallows.
    private let cases: [Case] = [
        Case(id: "win", caption: "A win, inside the division",
             move: .init(before: 430, after: 455, won: true)),
        Case(id: "promotion", caption: "A win that crosses it",
             move: .init(before: 588, after: 613, won: true)),
        Case(id: "loss", caption: "A loss",
             move: .init(before: 455, after: 443, won: false)),
        Case(id: "demotion", caption: "A loss that costs the division",
             move: .init(before: 705, after: 685, won: false)),
        Case(id: "held", caption: "A loss at the floor of the league",
             move: .init(before: 600, after: 600, won: false)),
        Case(id: "run", caption: "A win on a run, paid the run on top",
             move: .init(before: 430, after: 456, won: true, streak: 4)),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(verbatim: "THE LADDER")
                    .font(.display(40))
                    .foregroundStyle(Palette.onTable)
                stakes
                summaryPanel
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        heading(Text(verbatim: item.caption))
                        RankedVerdict(move: item.move)
                            .id("\(item.id)/\(take)")
                    }
                }
                Button { take += 1 } label: { Text(verbatim: "Again") }
                    .font(.system(size: 15, weight: .semibold))
                    .tint(Palette.goldLight)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
    }

    /// The pre-game odds: a real opponent, the house, and the house once the day's allowance is spent.
    private var stakes: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Text(verbatim: "Before the game"))
            RankedStakes(odds: RankedStakes.odds(mine: 745, theirs: [1_120]))
            RankedStakes(odds: RankedStakes.odds(mine: 745, theirs: [760], streak: 4))
            RankedStakes(odds: RankedStakes.houseOdds(mine: 745, theirs: 700, counting: true))
            RankedStakes(odds: RankedStakes.houseOdds(mine: 745, theirs: 700, counting: false))
        }
    }

    /// The verdict at the width and on the ground it has inside the end-of-game panel.
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Text(verbatim: "In the summary, at its real width"))
            VStack(spacing: 14) {
                Text(verbatim: "VICTORY")
                    .font(.display(38))
                    .foregroundStyle(Palette.goldSheen)
                RankedVerdict(move: .init(before: 1_188, after: 1_213, won: true))
                    .id("panel/\(take)")
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: GlassRadius.panel).fill(Palette.stock.opacity(0.95))
            }
            .padding(.horizontal, 4)
        }
    }

    private func heading(_ text: Text) -> some View {
        text
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Palette.onTableSoft)
    }
}
