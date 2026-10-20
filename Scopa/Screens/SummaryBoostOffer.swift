import ScopaRewards
import SwiftUI

/// The run of doubled games, offered on the payout of a game that just paid. Bought there,
/// its first game is this one, so the double lands in the lines above as the player watches.
struct BoostOffer {
    enum Phase: Equatable {
        /// For sale. `renews` when this game spent the last of a run and is doubled already.
        case offered(renews: Bool)
        case buying
        /// Bought on this summary, with the run's games still to come.
        case running(left: Int)
    }

    let phase: Phase
    /// What the purse holds once the run is paid for.
    let leaves: Denari
    let buy: () -> Void

    var isForSale: Bool {
        if case .offered = phase { true } else { false }
    }
}

/// The offer as one row on the summary's paper, in the shop ticket's look so it is known
/// for the same thing, and only as tall as the ad's row above it.
struct SummaryBoostRow: View {
    let offer: BoostOffer

    @State private var asks = false

    private static let stub: CGFloat = 46

    var body: some View {
        // A button only while it is for sale: bought, it is news rather than a control, and
        // a disabled button would grey out the very line that says it worked.
        ZStack {
            if offer.isForSale {
                Button { asks = true } label: { ticket }
                    .buttonStyle(.plain)
            } else {
                ticket
            }
        }
        .padding(.top, 2)
        .confirmation(isPresented: $asks) { question }
        .task { if offer.isForSale { await DebugLaunch.takeBoostOffer(ask: { asks = true }, buy: offer.buy) } }
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            DoubleMark(size: 28)
                .frame(width: Self.stub)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) { words }
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .ticket(stub: Self.stub, paper: Palette.gold.opacity(0.1), notch: 5)
    }

    @ViewBuilder private var words: some View {
        switch offer.phase {
        case .running(let left):
            Text("On for your next \(left) games")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
            BoostPips(left: left, size: 9)
        case .offered(renews: true):
            Text("Double winnings").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("For your next \(Boost.games) games").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
        case .offered, .buying:
            Text("Double winnings").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text("This game and your next \(Boost.games - 1)").font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
        }
    }

    /// The price as a tag, so it is not read as one more line of winnings.
    @ViewBuilder private var trailing: some View {
        switch offer.phase {
        case .buying:
            ProgressView().tint(Palette.goldDeep)
        case .running:
            EmptyView()
        case .offered:
            DenariLabel(amount: Boost.price, size: 13, weight: .bold, tint: Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(Palette.gold, lineWidth: 1.2))
        }
    }

    private var question: Confirmation {
        let title = offer.phase == .offered(renews: true)
            ? Text("Double your next \(Boost.games) games?")
            : Text("Double this game and your next \(Boost.games - 1)?")
        return Confirmation(title, message: Text("Leaves you \(offer.leaves.coins) denari."), actions: [
            .init(title: Text("Buy for \(Boost.price.coins) denari")) { offer.buy() },
            .init(title: Text("Not now"), role: .cancel),
        ])
    }
}
