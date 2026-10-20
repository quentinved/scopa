import StoreKit
import ScopaRewards
import SwiftUI

/// The no-ads purchase on a page of its own: the picture, what it takes away and what it
/// leaves, the price and the restore line. Opened from the lobby's corner, the shop and the
/// settings.
struct AdFreeSheet: View {
    let pass: AdFreePass

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    picture
                    heading
                    perks
                    if pass.isOwned { thanks } else { buying }
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
        .animation(.spring(duration: 0.45, bounce: 0.2), value: pass.isOwned)
        .animation(.easeInOut(duration: 0.2), value: pass.state)
        .sensoryFeedback(trigger: pass.isOwned) { _, owned in owned ? .success : nil }
        .sound(trigger: pass.isOwned) { _, owned in owned ? .purchase : nil }
        .task { await pass.loadProduct() }
    }

    private var picture: some View {
        NoAdsArtwork(size: 220)
            .clipShape(.rect(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }

    private var heading: some View {
        VStack(spacing: 6) {
            Text("Scopa without ads")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
            Text("Sweep them off the table, once and for all.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTableSoft)
        }
        .multilineTextAlignment(.center)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perk("rectangle.slash.fill", Palette.terracotta, "No banner under the lobby")
            perk("play.slash.fill", Palette.terracotta, "No ad between games")
            perk("sparkles", Palette.gold, "\(Boost.passGift.coins) denari, straight into your purse")
            perk("rectangle.stack.fill", Palette.gold, "A \(Boost.passPack.title) pack, waiting in your album")
            perk("arrow.up.right", Palette.gold, "Half as much again on every game you finish")
            perk("gift.fill", Palette.gold, "The videos that pay denari stay, for when you want them")
            perk("infinity", Palette.steel, "Pay once. Yours for good, on all your devices")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: GlassRadius.control)
    }

    private func perk(_ symbol: String, _ tint: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            SymbolCoin(symbol: symbol, tint: tint, size: 30)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Buying

    private var buying: some View {
        VStack(spacing: 12) {
            Button {
                Task { await pass.buy() }
            } label: {
                Group {
                    if pass.state == .buying {
                        ProgressView().tint(Palette.cream)
                    } else if let price = pass.product?.displayPrice {
                        Text("Remove the ads · \(price)")
                    } else {
                        Text("Remove the ads")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Palette.terracotta))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(pass.state == .buying || pass.state == .pending)

            Button("Restore purchases") { Task { await pass.restore() } }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .disabled(pass.state == .restoring)

            if let footnote = AdFreeGroup.footnote(for: pass.state) {
                Text(footnote)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }

    private var thanks: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                PatronCrest(size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tutto pulito!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.cream)
                    Text("The ads are gone and every game pays half again. Thank you for keeping the table going.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.cream.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .glassPanel(radius: GlassRadius.control, tint: Palette.terracotta.opacity(0.35))
            Button("Back to the table") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
}

// MARK: - The way in

/// "AD", struck through: the lobby's corner button and the shop row's coin.
struct NoAdsGlyph: View {
    var size: CGFloat = 13

    var body: some View {
        Text(verbatim: "AD")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .overlay {
                Capsule()
                    .fill(Palette.terracotta)
                    .frame(width: size * 0.2, height: size * 2.1)
                    .rotationEffect(.degrees(-45))
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
    }
}

/// The lobby's way to the purchase, beside the wordmark with the rules across from it.
/// Gone once the pass is owned.
struct NoAdsButton: View {
    @Environment(\.lift) private var lift
    var action: () -> Void

    var body: some View {
        NamedCoin(title: "No ads") {
            NoAdsGlyph(size: 12.5 * lift)
        } action: {
            action()
        }
        .accessibilityLabel("Remove the ads")
    }
}

/// Where the lobby's No ads coin stands for everyone else, an owner's crest under its name.
struct PatronCoin: View {
    @Environment(\.lift) private var lift
    var action: () -> Void

    var body: some View {
        NamedCoin(title: "Patron") {
            PatronCrest(size: 35 * lift, casts: false)
        } action: {
            action()
        }
        .accessibilityLabel("Patron of the house")
    }
}

/// The offer in the shop, under the video row. Real money, so it says its price in the
/// player's currency and never in denari, though it hands some over.
///
/// An owner is never offered it again: the patron's card stands in its place, and opens the
/// gold page that says it is already theirs.
///
/// Both pages are held by the shop rather than here: the offer goes the moment the purchase
/// lands, and a sheet hung on it went with it before it could say thank you.
struct AdFreeShopRow: View {
    let ads: AdsStore
    let showOffer: () -> Void
    let showPatron: () -> Void

    var body: some View {
        if ads.pass.isOwned {
            PatronShopCard(open: showPatron)
        } else if ads.adsAreOn {
            offer
        }
    }

    private var offer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Tired of ads?")
            Button(action: showOffer) {
                HStack(spacing: 12) {
                    NoAdsGlyph(size: 12)
                        .foregroundStyle(Palette.goldLight)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scopa without ads")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                        Text("No ads, \(Boost.passGift.coins) denari, a pack, and half again every game")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.onTableSoft)
                    }
                    Spacer(minLength: 0)
                    AdFreePriceTag(pass: ads.pass)
                }
                .padding(14)
                .glassPanel(radius: GlassRadius.control)
            }
            .buttonStyle(.plain)
        }
    }
}

/// The App Store's price in a terracotta capsule, or "Buy" until it has answered.
struct AdFreePriceTag: View {
    let pass: AdFreePass

    var body: some View {
        Group {
            if let product = pass.product {
                Text(product.displayPrice)
            } else {
                Text("Buy")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.cream)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.terracotta))
        // Priced afresh on every look: a first answer from before the account settled
        // can be in the wrong currency.
        .task { await pass.loadProduct() }
    }
}
