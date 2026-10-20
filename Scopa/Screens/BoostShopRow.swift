import ScopaRewards
import SwiftUI

/// A run of doubled games, sold for denari. Every finished game pays its own earnings a
/// second time until the run is played out, and runs stack.
///
/// A paper ticket rather than another glass row: next to the bags and the no-ads pass it
/// read as one more thing to pay for, and players who saw it did not know what it did. The
/// coins say ×2, the line under the title works one game out, and a run being played shows
/// as the coins it has left.
struct BoostShopRow: View {
    let purse: PurseStore

    @State private var confirms = false
    @State private var isBuying = false
    @State private var bought = 0

    private static let stub: CGFloat = 74

    private var left: Int { purse.purse.boostedGamesLeft }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Saving up?")
            Button { confirms = true } label: { ticket }
                .buttonStyle(.plain)
                .disabled(isBuying)
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: left)
        .sensoryFeedback(.success, trigger: bought)
        .confirmation(isPresented: $confirms) { question }
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            DoubleMark(size: 48)
                .frame(width: Self.stub)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) { words }
                    .frame(maxWidth: .infinity, alignment: .leading)
                price
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 15)
        .ticket(stub: Self.stub, paper: Palette.stock, lifted: true)
    }

    @ViewBuilder private var words: some View {
        if left > 0 {
            Text("\(left) doubled games left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            BoostPips(left: left, size: 11)
            Text("Buy again for \(Boost.games) more")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
        } else {
            Text("Your next \(Boost.games) games pay double")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Win 30, take home 60")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
        }
    }

    @ViewBuilder private var price: some View {
        if isBuying {
            ProgressView().tint(Palette.goldDeep)
        } else {
            DenariLabel(amount: Boost.price, size: 15, weight: .bold,
                        tint: purse.purse.canAffordBoost ? Palette.ink : Palette.inkSoft)
        }
    }

    private var question: Confirmation {
        guard purse.purse.canAffordBoost else {
            return Confirmation(Text("Not enough denari yet"),
                                message: Text("You are \((Boost.price - purse.balance).coins) denari short."),
                                actions: [.init(title: Text("OK"), role: .cancel)])
        }
        let title = left > 0 ? Text("Add \(Boost.games) more doubled games?")
                             : Text("Double your next \(Boost.games) games?")
        return Confirmation(title, message: Text("Leaves you \((purse.balance - Boost.price).coins) denari."),
                            actions: [
            .init(title: Text("Buy for \(Boost.price.coins) denari")) { buy() },
            .init(title: Text("Not now"), role: .cancel),
        ])
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
