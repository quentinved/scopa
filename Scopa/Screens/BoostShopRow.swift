import ScopaRewards
import SwiftUI

/// A run of doubled games, sold for denari under the no-ads offer. Every finished game pays
/// its own earnings a second time until the run is played out, and runs stack.
struct BoostShopRow: View {
    let purse: PurseStore

    @State private var confirms = false
    @State private var isBuying = false
    @State private var bought = 0

    private var left: Int { purse.purse.boostedGamesLeft }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Double winnings")
            Button { confirms = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.goldLight)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Every game pays twice")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                        Group {
                            if left > 0 {
                                Text("\(left) doubled games left")
                            } else {
                                Text("For your next \(Boost.games) games")
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(left > 0 ? Palette.goldLight : Palette.onTableSoft)
                        .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    if isBuying {
                        ProgressView().tint(Palette.goldLight)
                    } else {
                        DenariLabel(amount: Boost.price, size: 15)
                    }
                }
                .padding(14)
                .glassPanel(radius: GlassRadius.control, interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(isBuying)
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: left)
        .sensoryFeedback(.success, trigger: bought)
        .confirmation(isPresented: $confirms) {
            guard purse.purse.canAffordBoost else {
                return Confirmation(Text("Not enough denari yet"),
                                    message: Text("You are \((Boost.price - purse.balance).coins) denari short."),
                                    actions: [.init(title: Text("OK"), role: .cancel)])
            }
            return Confirmation(Text("Double your next \(Boost.games) games?"),
                         message: Text("Leaves you \((purse.balance - Boost.price).coins) denari."),
                         actions: [
                .init(title: Text("Buy for \(Boost.price.coins) denari")) { buy() },
                .init(title: Text("Not now"), role: .cancel),
            ])
        }
    }

    private func buy() {
        isBuying = true
        Task {
            defer { isBuying = false }
            guard await purse.buyBoost() else { return }
            bought += 1
            Audio.shared.play(.purchase)
        }
    }
}
