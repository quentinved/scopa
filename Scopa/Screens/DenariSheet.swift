import StoreKit
import ScopaRewards
import SwiftUI

/// The three bags of denari on a page of their own: what each holds, the App Store's price,
/// and where the denari go. Opened from the shop, under the balance it tops up.
struct DenariSheet: View {
    let purse: PurseStore

    @Environment(DenariSale.self) private var sale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heading
                    VStack(spacing: 10) {
                        ForEach(DenariBag.allCases) { bag in bagButton(bag) }
                    }
                    footnotes
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(TableGround())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Palette.goldLight)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sale.state)
        .animation(.snappy, value: purse.balance)
        .sensoryFeedback(.success, trigger: sale.landed)
        .sound(.purchase, trigger: sale.landed)
        .task { await sale.loadProducts() }
    }

    private var heading: some View {
        VStack(spacing: 8) {
            CoinPile(count: 3, size: 52)
            Text("Denari")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
            Text("Straight into your purse, to spend in the shop and the album.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            DenariLabel(amount: purse.balance, size: 15, tint: Palette.goldLight)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPanel(radius: GlassRadius.control)
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
    }

    private func bagButton(_ bag: DenariBag) -> some View {
        Button {
            Task { await sale.buy(bag, into: purse) }
        } label: {
            HStack(spacing: 14) {
                CoinPile(count: DenariBag.allCases.firstIndex(of: bag)! + 1, size: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: bag.title)
                            .font(.display(21))
                            .foregroundStyle(Palette.onTable)
                        DenariLabel(amount: bag.denari, size: 13, tint: Palette.goldLight)
                    }
                    Text(Self.line(bag))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if sale.buying == bag {
                    ProgressView().tint(Palette.goldLight)
                } else {
                    DenariPriceTag(bag: bag)
                }
            }
            .padding(14)
            .glassPanel(radius: GlassRadius.control)
        }
        .buttonStyle(.plain)
        .disabled(sale.state == .buying)
    }

    private static func line(_ bag: DenariBag) -> LocalizedStringKey {
        switch bag {
        case .mancia: "A tip for the house. The house says grazie"
        case .borsellino: "A coin purse. Jingles when you walk"
        case .tesoretto: "The nest egg. Nonna need never know"
        }
    }

    private var footnotes: some View {
        VStack(spacing: 10) {
            if let state = Self.footnote(for: sale.state) {
                Text(state)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(sale.state == .pending ? Palette.onTable : Palette.terracotta)
                    .transition(.opacity)
            }
            Text("Bought denari follow your Game Center account to your other devices. Signed out, they stay on this phone.")
            Text("Nothing here changes how the cards fall.")
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.onTableSoft)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static func footnote(for state: DenariSale.State) -> LocalizedStringKey? {
        switch state {
        case .pending: "Waiting for approval. The denari arrive as soon as it comes."
        case .failed: "The App Store could not finish that. Try again in a moment."
        case .notSaved: "Your denari are paid for but not saved yet. They arrive the next time Scopa opens."
        case .idle, .buying: nil
        }
    }
}

// MARK: - The way in

/// The bags in the shop, beside the balance they top up. Real money, so it shows the App
/// Store's price in the player's currency. Gone where denari are not sold.
struct DenariShopRow: View {
    let purse: PurseStore

    @Environment(DenariSale.self) private var sale
    @State private var showsSheet = DebugLaunch.showsDenariSheet

    var body: some View {
        if sale.isOnSale {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "In a hurry?")
                Button { showsSheet = true } label: {
                    HStack(spacing: 12) {
                        CoinPile(count: 2, size: 20)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Buy a bag of denari")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.onTable)
                            Text("For when the deck you want won't wait")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.onTableSoft)
                        }
                        Spacer(minLength: 0)
                        DenariPriceTag(bag: .mancia, from: true)
                    }
                    .padding(14)
                    .glassPanel(radius: GlassRadius.control)
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showsSheet) { DenariSheet(purse: purse).coversBanner(carries: false) }
        }
    }
}

/// One bag's App Store price in a terracotta capsule, or "Buy" until it has answered.
struct DenariPriceTag: View {
    let bag: DenariBag
    /// "From" the price, for the row that opens all three.
    var from = false

    @Environment(DenariSale.self) private var sale

    var body: some View {
        Group {
            if let price = displayPrice {
                if from { Text("From \(price)") } else { Text(verbatim: price) }
            } else {
                Text("Buy")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.cream)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.terracotta))
    }

    private var displayPrice: String? {
        if let product = sale.products[bag] { return product.displayPrice }
        #if DEBUG
        // A simulator launched outside Xcode never hears from the App Store.
        if DebugLaunch.showsDenariSheet { return Self.samplePrices[bag] }
        #endif
        return nil
    }

    #if DEBUG
    /// The euro prices Tools/DenariSeed asks for.
    private static let samplePrices: [DenariBag: String] = [
        .mancia: "0,99 €", .borsellino: "3,99 €", .tesoretto: "7,99 €",
    ]
    #endif
}

/// One coin, two, or a little heap of three: how big a bag is, at a glance.
struct CoinPile: View {
    let count: Int
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            ForEach(Array(places.enumerated()), id: \.offset) { _, place in
                DenariMark(size: size)
                    .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.04)
                    .offset(x: place.x * size, y: place.y * size)
            }
        }
        .frame(width: size * 1.6, height: size * 1.4)
    }

    /// Back to front, in fractions of a coin.
    private var places: [CGPoint] {
        switch count {
        case ...1: [.zero]
        case 2: [CGPoint(x: 0.2, y: -0.12), CGPoint(x: -0.2, y: 0.12)]
        default: [CGPoint(x: 0, y: -0.2), CGPoint(x: 0.3, y: 0.18), CGPoint(x: -0.3, y: 0.18)]
        }
    }
}

#Preview {
    DenariSheet(purse: PurseStore())
        .environment(DenariSale())
}
