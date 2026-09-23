import SwiftUI
import ScopaCore

/// The pile, opened from the tag on the table: the cards taken so far and where the four
/// points stand right now.
struct PileSheet: View {
    let view: PlayerView
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var mine: [Card] { view.captures }
    private var coins: Int { mine.count { $0.suit == .coins } }
    private var sevens: Int { mine.count { $0.rank == .seven } }
    private var others: [(name: String, count: Int)] {
        view.configuration.players.enumerated().compactMap { seat, player in
            let side = view.configuration.side(ofSeat: seat)
            guard side != view.mySide, let count = view.captureCounts[safe: side] else { return nil }
            return (view.configuration.teams ? String(localized: "Them", locale: locale) : player.name, count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tally.glassPanel(radius: GlassRadius.control)
                    if mine.isEmpty {
                        Text("Nothing taken yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.onTableSoft)
                    } else {
                        cards
                    }
                }
                .padding(20)
            }
            .softScrollEdge(.top)
            .background(TableGround())
            .navigationTitle(view.configuration.teams ? "Our pile" : "Your pile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Palette.goldLight)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var tally: some View {
        VStack(spacing: 0) {
            line("Cards", value: "\(mine.count)", note: othersNote)
            Rule()
            line("Coins", value: "\(coins)")
            Rule()
            // Under the sevens rule the count of sevens is the primiera, so it is said once.
            line("Sevens", value: "\(sevens)",
                 note: view.configuration.primiera == .mostSevens
                     ? String(localized: "the primiera point") : nil)
            Rule()
            line("Seven of coins", value: mine.contains(.settebello) ? "✓" : "–")
            Rule()
            if view.configuration.primiera != .mostSevens {
                line("Primiera so far", value: "\(Scoring.primiera(of: mine))")
                Rule()
            }
            line("Scope", value: "\(view.scope[safe: view.mySide] ?? 0)")
        }
    }

    private var cards: some View {
        let sorted = mine.sorted { ($0.suit.rawValue, $0.rank.rawValue) < ($1.suit.rawValue, $1.rank.rawValue) }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 8)], spacing: 8) {
            ForEach(sorted, id: \.self) { card in
                CardView(card: card, width: 46)
            }
        }
    }

    private var othersNote: String? {
        guard !others.isEmpty else { return nil }
        return others.map { "\($0.name) \($0.count)" }.joined(separator: " · ")
    }

    private func line(_ title: LocalizedStringKey, value: String, note: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 8)
            if let note {
                Text(verbatim: note)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Text(verbatim: value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
