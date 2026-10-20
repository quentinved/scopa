import ScopaRewards
import SwiftUI

/// What an owner of the no-ads purchase is shown wherever everyone else is sold it: no price,
/// just a gold page saying it is already theirs, what it gives, and the crest that comes
/// with it.
///
/// The moment is told once as the page opens: the crest is tossed onto the plaque, coins and
/// leaf fall off it, a light crosses the gold. Then nothing moves. A tap anywhere closes it.
struct PatronSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.screenSize) private var screenSize

    @State private var landed = false
    @State private var burst = 0
    @State private var iconInUse = PatronIcon.isInUse

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                plaque
                words
                perks
                if LadderIcon.isSupported { iconRow }
                Button("Done") { dismiss() }
                    .buttonStyle(FilledButtonStyle(tint: PatronTone.gold, foreground: Palette.ink))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .patronDress(true)
        .task { await land() }
        .sensoryFeedback(.success, trigger: burst)
        .accessibilityAddTraits(.isModal)
    }

    /// Tossed on after a breath, so the eye has found the plaque before the crest arrives.
    private func land() async {
        guard !reduceMotion else {
            landed = true
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(duration: 0.9, bounce: 0.28)) { landed = true }
        try? await Task.sleep(for: .milliseconds(620))
        burst += 1
        Audio.shared.play(.shine)
    }

    // MARK: The plaque

    private var plaque: some View {
        GildedPlaque {
            ZStack {
                VaultRoundel(size: 196)
                PatronCrest(size: 152)
                    .rotation3DEffect(.degrees(landed ? 0 : -540), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .scaleEffect(landed ? 1 : 0.35)
                    .opacity(landed ? 1 : 0)
                if burst > 0 {
                    Shockwave(tint: PatronTone.goldPale, size: 160)
                    SparkBurst(sparks: 24, coins: 14,
                               palette: [PatronTone.goldPale, PatronTone.goldLight, PatronTone.gold],
                               force: 470, seed: 11)
                }
            }
            .frame(height: 248)
        }
        .overlay {
            // A single pass of light across the leaf as the crest settles, and then none.
            if burst > 0 {
                FoilGlare(fanfare: .bright, tint: PatronTone.goldPale, glance: 0, radius: 28)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: The words

    private var words: some View {
        VStack(spacing: 8) {
            Caption(text: "Patron of the house")
            Text("You already have it")
                .font(.display(screenSize.width < 360 ? 32 : 38))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Put your wallet away. The ads are gone for good, and the house never forgets who keeps the table going.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 14) {
            perk("rectangle.slash.fill", "No banner, and no ad between games")
            perk("arrow.up.right", "Half as much again on every game you finish")
            perk("sparkles", "\(Boost.passGift.coins) denari and a \(Boost.passPack.title) pack, already yours")
            perk("gift.fill", "\(Boost.passThanks.coins) more, a thank-you from the house")
            perk("star.fill", "The crest by your purse, and a shop under the stars")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: GlassRadius.control)
    }

    private func perk(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            SymbolCoin(symbol: symbol, tint: PatronTone.gold, size: 30)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The icon only owners can pick, with the way to pick it right here.
    private var iconRow: some View {
        HStack(spacing: 14) {
            PatronIconArt(size: 56)
                .shadow(color: PatronTone.night.opacity(0.5), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("An icon of your own")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text("Only owners can pick it, in Settings or right here")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                Task {
                    await PatronIcon.use()
                    iconInUse = PatronIcon.isInUse
                }
            } label: {
                Group { if iconInUse { Text("In use") } else { Text("Use it") } }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconInUse ? PatronLeaf.caption : Palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background { if !iconInUse { Capsule().fill(Palette.goldSheen) } }
            }
            .buttonStyle(.plain)
            .disabled(iconInUse)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
    }
}

// MARK: - In the shop

/// Where the shop sells the no-ads purchase, an owner finds this instead: the crest on a
/// night-blue card ruled in gold, "Yours" where the price would be, and the celebration
/// behind a tap.
struct PatronShopCard: View {
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "No ads, for good")
            Button(action: open) {
                HStack(spacing: 14) {
                    PatronCrest(size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Patron of the house")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                        Text("Already yours. Tap to admire it")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.onTableSoft)
                    }
                    Spacer(minLength: 0)
                    YoursTag()
                }
                .padding(14)
                .background { PatronCardGround(radius: GlassRadius.control) }
                .contentShape(.rect(cornerRadius: GlassRadius.control))
            }
            .buttonStyle(.plain)
        }
    }
}

/// "Yours", on a strip of gold leaf: what an owner sees where everyone else sees the price.
struct YoursTag: View {
    var body: some View {
        Text("Yours")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(Palette.goldSheen) }
            .overlay { Capsule().strokeBorder(PatronTone.goldShadow.opacity(0.45), lineWidth: 0.75) }
    }
}

/// The patron card's ground: lapis with a few struck stars, ruled twice in gold.
struct PatronCardGround: View {
    var radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [PatronTone.lapis, PatronTone.lapisDeep],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            Canvas { context, size in
                for spot in Self.stars {
                    PatronStar.strike(in: &context, at: CGPoint(x: size.width * spot.x, y: size.height * spot.y),
                                      radius: spot.r, faceted: spot.r > 3.4, opacity: 0.75)
                }
            }
            .clipShape(shape)
            shape.strokeBorder(PatronLeaf.edge, lineWidth: 1.2)
            RoundedRectangle(cornerRadius: radius - 4, style: .continuous)
                .strokeBorder(PatronTone.gold.opacity(0.35), lineWidth: 0.6)
                .padding(4)
        }
        .shadow(color: PatronTone.night.opacity(0.45), radius: 10, y: 5)
        .accessibilityHidden(true)
    }

    /// Where the stars sit, as fractions of the card, clear of the words in the middle.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.30, 0.16, 2.2), (0.52, 0.86, 2.6), (0.62, 0.14, 1.8), (0.70, 0.80, 3.8),
        (0.76, 0.22, 2.4), (0.44, 0.10, 1.6), (0.86, 0.88, 1.8),
    ]
}
