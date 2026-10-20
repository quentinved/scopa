import ScopaCore
import ScopaRewards
import SwiftUI

/// What can come out of a card pack, in two looks: what the pack holds, then the chance of
/// each kind of card, as a bar that grows with the dearer packs.
///
/// Tapping a pack on the album's shelf opens this in place of a bare yes-or-no. The packs
/// sit along the top to be compared, by a tap or a swipe; every figure below moves with
/// the pick, so "what does the dearer pack buy me" is the bars getting longer.
struct PackPreview: View {
    @State var tier: PackTier
    /// Where packs are going: its scarcity sets the odds.
    let volume: Volume
    let album: Album
    let purse: PurseStore
    /// Said yes to. Bought by whoever opened the sheet, once it is down.
    let choose: (PackTier) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Namespace private var picker

    /// No navigation stack: inside one, the sheet's banner inset never reaches the footer.
    var body: some View {
        VStack(spacing: 0) {
            topBar
            tiers
                .padding(.horizontal, 16)
            ScrollView {
                VStack(spacing: 12) {
                    contents
                    odds
                    Text("Tap a card in your album to see its own odds.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .simultaneousGesture(swipe)
            footer
        }
        .background { TableGround() }
        .sensoryFeedback(.selection, trigger: tier)
    }

    private var topBar: some View {
        ZStack {
            Text("What's inside")
                .font(.display(20))
                .foregroundStyle(Palette.onTable)
            HStack {
                Button("Done") { dismiss() }
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.goldLight)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    // MARK: Which pack

    private var tiers: some View {
        HStack(spacing: 4) {
            ForEach(PackTier.on(.album)) { each in
                Button { pick(each) } label: { tierLabel(each) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(each == tier ? .isSelected : [])
            }
        }
        .padding(4)
        .glassPanel(radius: GlassRadius.control)
    }

    private func tierLabel(_ each: PackTier) -> some View {
        let picked = each == tier
        return VStack(spacing: 4) {
            // A fixed slot, so the packs whose rays reach past them sit level with the rest.
            PackArt(tier: each, width: 24)
                .frame(width: 40, height: 24 * 1.42)
            Text(verbatim: each.title)
                .font(.system(size: 12, weight: picked ? .bold : .medium))
                .foregroundStyle(picked ? Palette.onTable : Palette.onTableSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            price(of: each, picked: picked)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if picked {
                RoundedRectangle(cornerRadius: GlassRadius.control - 4)
                    .fill(PackLook.accent(each).opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: GlassRadius.control - 4)
                            .strokeBorder(PackLook.accent(each).opacity(0.55), lineWidth: 1)
                    }
                    .matchedGeometryEffect(id: "picked", in: picker)
            }
        }
        .opacity(picked ? 1 : 0.7)
        .contentShape(.rect)
    }

    @ViewBuilder private func price(of each: PackTier, picked: Bool) -> some View {
        if let price = each.price {
            DenariLabel(amount: price, size: 11, tint: picked ? Palette.goldLight : Palette.onTableSoft)
        } else {
            Text("Free")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(picked ? Palette.goldLight : Palette.onTableSoft)
        }
    }

    private func pick(_ each: PackTier) {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { tier = each }
    }

    /// Sideways across the page moves to the next pack along, the way the row reads.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let across = value.translation.width
                guard abs(across) > 60, abs(across) > abs(value.translation.height) * 1.6 else { return }
                let all = PackTier.on(.album)
                guard let index = all.firstIndex(of: tier) else { return }
                let next = index + (across < 0 ? 1 : -1)
                if all.indices.contains(next) { pick(all[next]) }
            }
    }

    // MARK: What it holds

    /// The pack, and what it holds in plain words: how many cards, what is promised, what
    /// comes with them.
    private var contents: some View {
        HStack(spacing: 16) {
            ZStack {
                PackArt(tier: tier, width: 50)
                    .id(tier)
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity),
                                            removal: .opacity))
            }
            .frame(width: 72, height: 50 * 1.42)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: tier.title)
                    .font(.display(22))
                    .foregroundStyle(Palette.onTable)
                    .contentTransition(.opacity)
                line("rectangle.portrait.on.rectangle.portrait.fill", Text("^[\(tier.cards) card](inflect: true)"))
                line(tier.floorCard == nil ? "circle.dashed" : "checkmark.seal.fill", promise)
                if tier.cosmetics > 0 {
                    line("sparkles", Text("A shop item, \(Rarities.title(tier.floorGrade, locale: locale)) or better"))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .glassPanel(radius: GlassRadius.control)
    }

    private var promise: Text {
        switch tier.floorCard {
        case nil: Text("No card promised")
        case .court?: Text("At least one court or seven")
        default: Text("At least one seven")
        }
    }

    private func line(_ symbol: String, _ text: Text) -> some View {
        Label { text } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PackLook.accent(tier))
                .frame(width: 18)
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundStyle(Palette.onTable)
        .contentTransition(.opacity)
    }

    // MARK: The odds

    /// One row a kind of card, the commonest first, so the bars shrink down the page the
    /// way a pack fills.
    private var odds: some View {
        VStack(alignment: .leading, spacing: 0) {
            Caption(text: "Chance in one pack")
                .padding(.bottom, 4)
            ForEach(Rarity.allCases, id: \.self) { rarity in
                RarityOddsRow(rarity: rarity, chance: Pack.packChance(of: rarity, in: tier, volume: volume),
                              album: album)
                if rarity != .settebello {
                    Rectangle().fill(Palette.onTableSoft.opacity(0.12)).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .glassPanel(radius: GlassRadius.control)
    }

    // MARK: Buying it

    private var affordable: Bool { tier.price.map { purse.balance >= $0 } ?? true }

    private var footer: some View {
        VStack(spacing: 8) {
            if let price = tier.price {
                Button {
                    choose(tier)
                    dismiss()
                } label: {
                    Text("Open it for \(price.coins) denari")
                }
                .buttonStyle(FilledButtonStyle())
                .disabled(!affordable)
                .opacity(affordable ? 1 : 0.55)
                Group {
                    if affordable {
                        Text("Leaves you \((purse.balance - price).coins) denari.")
                    } else {
                        Text("You are \((price - purse.balance).coins) denari short.")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
            } else {
                Label("A pack every \(Pack.gamesPerPack) games, won or lost", systemImage: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                    .frame(minHeight: 56)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

/// One kind of card in a pack: a few of them in hand, what they are, how many are in the
/// album, and the chance of at least one, as a figure and as a bar.
private struct RarityOddsRow: View {
    let rarity: Rarity
    let chance: Double
    let album: Album

    @Environment(\.locale) private var locale

    private var cards: [Card] { Deck.standard.filter { $0.rarity == rarity } }

    var body: some View {
        HStack(spacing: 12) {
            RarityHand(rarity: rarity)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: Rarities.title(rarity, locale: locale))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(rarity == .plain ? Palette.onTable : Rarities.tint(rarity))
                    Spacer(minLength: 8)
                    Text(verbatim: Odds.percent(chance, locale: locale))
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.onTable)
                        .contentTransition(.numericText())
                }
                OddsBar(chance: chance, tint: rarity == .plain ? Palette.onTable.opacity(0.7) : Rarities.tint(rarity))
                HStack(alignment: .firstTextBaseline) {
                    Text(Rarities.short(rarity))
                    Spacer(minLength: 8)
                    found
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: chance)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var found: some View {
        let have = cards.count { album.has($0) }
        if have == cards.count {
            Label {
                cards.count == 1 ? Text("Found") : Text("\(have)/\(cards.count) found")
            } icon: {
                Image(systemName: "checkmark.seal.fill")
            }
            .foregroundStyle(Palette.goldLight)
        } else if cards.count == 1 {
            Text("Not found yet")
        } else {
            Text("\(have)/\(cards.count) found")
        }
    }
}

/// How likely, drawn to scale: a rare card is a sliver, never nothing.
private struct OddsBar: View {
    let chance: Double
    let tint: Color

    var body: some View {
        Capsule()
            .fill(Palette.onTableSoft.opacity(0.15))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: max(5, proxy.size.width * min(chance, 1)))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
    }
}

/// A few cards of one kind fanned in the hand, so the row shows which cards it means.
private struct RarityHand: View {
    let rarity: Rarity

    private static let width: CGFloat = 26

    var body: some View {
        let cards = Rarities.hand(rarity)
        ZStack {
            if rarity == .settebello {
                RarityBurst(count: Rarities.rays(rarity), tint: Rarities.tint(rarity),
                            size: Self.width * 2.2, turns: false)
                    .opacity(0.5)
            }
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                let turn = Double(index) - Double(cards.count - 1) / 2
                CardView(card: card, width: Self.width)
                    .rotationEffect(.degrees(turn * 11), anchor: .bottom)
                    .offset(x: turn * 9)
            }
        }
        .frame(width: 60, height: Self.width * 1.5 + 6)
        .accessibilityHidden(true)
    }
}

/// A rarity's rank as a row of stones, one for a numeral up to four for the settebello:
/// the order at a glance, before a word is read.
struct RarityPips: View {
    let rarity: Rarity
    var size: CGFloat = 7

    var body: some View {
        HStack(spacing: size * 0.3) {
            ForEach(0..<Rarity.allCases.count, id: \.self) { index in
                Image(systemName: "suit.diamond.fill")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rarity.rawValue
                                     ? Rarities.tint(rarity)
                                     : Palette.onTableSoft.opacity(0.25))
            }
        }
        .accessibilityHidden(true)
    }
}
