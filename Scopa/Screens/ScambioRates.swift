import ScopaCore
import ScopaRewards
import SwiftUI

/// What each kind of missing card costs in spares, one column per rarity, the way the
/// album's own count prints them. The words print `Scambio.price(of:)`.
struct ScambioRates: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(Rarity.allCases, id: \.self) { rarity in
                    VStack(spacing: 5) {
                        RarityTag(rarity, locale: locale, size: 8.5)
                        Text(price(rarity))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("A court counts as three numerals, a spare seven as two courts. Sevens and the settebello only come out of a pack, and a spare settebello is never traded.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func price(_ rarity: Rarity) -> LocalizedStringKey {
        switch rarity {
        case .plain: "Twenty numerals"
        case .court: "Fifteen courts"
        case .prime, .settebello: "Packs only"
        }
    }
}

extension Scambio.Offer {
    /// What it takes, by rarity and the best first: "3 × Court, 1 × Seven".
    func cost(locale: Locale) -> String {
        Rarity.allCases.reversed().compactMap { rarity in
            let taken = count(of: rarity)
            return taken > 0 ? "\(taken) × \(Rarities.title(rarity, locale: locale))" : nil
        }
        .joined(separator: ", ")
    }

    /// The cards going, the best first, for drawing them.
    var sparesInOrder: [Card] {
        spares.keys.sorted { a, b in
            a.rarity != b.rarity ? a.rarity > b.rarity : a.description < b.description
        }
    }
}
