import ScopaCore
import ScopaRewards
import SwiftUI

/// The packs on one shelf, the till they are bought at, and what is printed about them.
///
/// Two pages sell packs. The album sells the ones made of cards and the shop sells the ones
/// made of what is on its own shelves; the row, the yes-or-no, the denari leaving the purse,
/// the tearing and the paying out afterwards are the same either way. They live here rather
/// than twice, so a change to what happens after "yes" is one edit.

/// One shelf of packs: a caption, the rows, and the button that says what is in them.
///
/// The page owns the till rather than this view, because the album also opens packs that
/// were never bought — the earned ones at the top of that page go through the same
/// ceremony and the same paying out.
struct PackShelf: View {
    let shelf: PackTier.Shelf
    let title: LocalizedStringKey
    let purse: PurseStore
    let till: PackTill
    /// Whether a refused purchase writes its line here. The shop already prints the purse's
    /// troubles under the balance at the top of its page, and the same sentence twice on
    /// one screen reads as two things having gone wrong.
    var showsProblem = true

    @State private var showsOdds = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Caption(text: title)
                Spacer(minLength: 4)
                Button { showsOdds = true } label: {
                    Text("Odds")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 10) {
                ForEach(PackTier.forSale(on: shelf)) { tier in
                    Button { till.buying = tier } label: {
                        PackRow(tier: tier, affordable: affordable(tier))
                    }
                    .buttonStyle(.plain)
                    .disabled(till.isPaying)
                }
            }
            if showsProblem, let problem = purse.problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.terracotta)
            }
        }
        .sheet(isPresented: $showsOdds) { OddsSheet(shelf: shelf) }
    }

    private func affordable(_ tier: PackTier) -> Bool {
        guard let price = tier.price else { return true }
        return purse.balance >= price
    }
}

/// The till: which pack is waiting on a yes, which opening is on screen, and whether
/// denari are already on their way out.
///
/// A small object rather than three pieces of `@State` on each page, because buying a pack
/// is four steps that have to happen in order and a page that kept its own copy of them
/// would be a second place for them to be wrong.
@MainActor
@Observable
final class PackTill {
    /// The pack the till is waiting on a yes for.
    var buying: PackTier?
    /// The opening being shown, bought or earned.
    var opening: AlbumBook.Opening?
    /// True while denari are leaving the purse, so a second tap cannot buy twice.
    private(set) var isPaying = false

    /// Takes the money, draws the pack, and shows it. Quiet when the purse was too light:
    /// the refusal has already written its line under the balance.
    func buy(_ tier: PackTier, book: AlbumBook, purse: PurseStore) {
        guard !isPaying else { return }
        isPaying = true
        Task {
            defer { isPaying = false }
            guard await purse.buyPack(tier) else { return }
            show(book.openBought(tier, owned: purse.purse.owned), purse: purse)
        }
    }

    /// Shows a pack and pays what it owes.
    ///
    /// The denari and the unlocks are granted the moment the pack is drawn rather than when
    /// the sheet is dismissed, so a phone that dies mid-opening still kept what it turned
    /// up. Everything here is keyed, so it is safe to have run already.
    func show(_ opened: AlbumBook.Opening, purse: PurseStore) {
        opening = opened
        Task {
            await purse.awardPack(opened.denari, key: opened.key)
            for (place, won) in opened.won.enumerated() {
                guard let item = won.item else { continue }
                await purse.win(item, key: opened.key(forWon: place))
            }
        }
    }
}

extension View {
    /// Hangs the till on a page: the confirmation, and the opening it leads to.
    func packTill(_ till: PackTill, book: AlbumBook, purse: PurseStore, name: String) -> some View {
        modifier(PackTillModifier(till: till, book: book, purse: purse, name: name))
    }
}

private struct PackTillModifier: ViewModifier {
    @Bindable var till: PackTill
    let book: AlbumBook
    let purse: PurseStore
    let name: String

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $till.opening) { opened in
                PackOpening(opening: opened, name: name)
            }
            .confirmationDialog(Text(verbatim: till.buying?.title ?? ""),
                                isPresented: Binding(get: { till.buying != nil },
                                                     set: { if !$0 { till.buying = nil } }),
                                titleVisibility: .visible) {
                if let buying = till.buying, let price = buying.price {
                    Button("Open it for \(price.coins) denari") {
                        till.buy(buying, book: book, purse: purse)
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                if let buying = till.buying, let price = buying.price {
                    Text("Leaves you \((purse.balance - price).coins) denari.")
                }
            }
    }
}

/// One pack on the shelf: what it is wrapped in, what is in it, and what it costs.
struct PackRow: View {
    let tier: PackTier
    let affordable: Bool

    var body: some View {
        HStack(spacing: 14) {
            PackArt(tier: tier, width: 46)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(verbatim: tier.title)
                        .font(.display(21))
                        .foregroundStyle(Palette.onTable)
                    RarityTag(PackLook.grade(tier), size: 8.5)
                }
                Text(PackLook.explanation(tier))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let price = tier.price {
                DenariLabel(amount: price, size: 14,
                            tint: affordable ? Palette.goldLight : Palette.onTableSoft)
                    .opacity(affordable ? 1 : 0.7)
            }
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
        .overlay {
            RoundedRectangle(cornerRadius: GlassRadius.control)
                .strokeBorder(Rarities.sheen(PackLook.grade(tier)), lineWidth: 1.2)
                .opacity(0.55)
        }
    }
}

/// What every pack on one shelf actually pays, written down.
///
/// Printed rather than described, and reachable from the page that sells them rather than
/// buried: a game that sells packs and will not say what is in them is a game asking to be
/// trusted about the one thing it should be showing.
struct OddsSheet: View {
    var shelf: PackTier.Shelf = .album

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        switch shelf {
                        case .album:
                            Text("Every card is drawn on its own from the whole deck, so a pack can hand you a card you already have — and pays you denari when it does.")
                        case .shop:
                            Text("Nothing is ever handed to you twice: a pack only turns up things you do not own yet. When there is nothing left at the grade it promised, it pays you what that grade is worth instead.")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    ForEach(PackTier.on(shelf)) { tier in
                        tierOdds(tier)
                    }
                }
                .padding(20)
            }
            .background(TableGround())
            .navigationTitle("What is in a pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Palette.goldLight)
                }
            }
        }
    }

    private func tierOdds(_ tier: PackTier) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PackArt(tier: tier, width: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: tier.title)
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    // Whole keys rather than one built by concatenation: gluing a `String`
                    // onto the front of an inflected key hands `Text` a plain string, which
                    // it prints exactly as written — markup and all.
                    Group {
                        if tier.isCosmeticOnly {
                            Text("^[\(tier.cosmetics) thing](inflect: true) off the shelves")
                        } else if tier.cosmetics > 0 {
                            Text("^[\(tier.cards) card](inflect: true), and something for your table")
                        } else {
                            Text("^[\(tier.cards) card](inflect: true)")
                        }
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.onTableSoft)
                }
                Spacer(minLength: 0)
                if let price = tier.price {
                    DenariLabel(amount: price, size: 13)
                }
            }
            VStack(spacing: 7) {
                if !tier.isCosmeticOnly {
                    ForEach(Rarity.allCases.filter { $0 > .plain }, id: \.self) { rarity in
                        oddsLine(rarity, in: tier)
                    }
                }
                if tier.cosmetics > 0 {
                    if !tier.isCosmeticOnly { Rule() }
                    ForEach(Grade.allCases.filter { $0 >= tier.floorGrade }.reversed(), id: \.self) { grade in
                        gradeLine(grade, in: tier)
                    }
                }
            }
            .padding(13)
            .glassPanel(radius: GlassRadius.control)
        }
    }

    private func oddsLine(_ rarity: Rarity, in tier: PackTier) -> some View {
        let chance = Pack.packChance(ofAtLeast: rarity, in: tier)
        return HStack(spacing: 8) {
            RarityTag(rarity, locale: locale, size: 8.5)
            Text("or better, per pack")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 6)
            Text(verbatim: percent(chance))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(chance >= 1 ? Palette.goldLight : Palette.onTable)
        }
    }

    /// One grade's share of a cosmetic slot. A pack with more than one slot says so, since
    /// "a quarter of the time" reads very differently from "a quarter of the time, twice".
    private func gradeLine(_ grade: Grade, in tier: PackTier) -> some View {
        let chance = Grade.chance(of: grade, atLeast: tier.floorGrade)
        return HStack(spacing: 8) {
            RarityTag(grade, size: 8.5)
            Group {
                if tier.cosmetics > 1 {
                    Text("per thing off the shelves")
                } else {
                    Text("off the shelves")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.onTableSoft)
            Spacer(minLength: 6)
            Text(verbatim: percent(chance))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
    }

    /// "Always" rather than "100%" for a guarantee, and one decimal below ten per cent so
    /// a settebello does not round away to nothing.
    private func percent(_ value: Double) -> String {
        if value >= 0.9995 { return String(localized: "Always", locale: locale) }
        let places = value < 0.1 ? 1 : 0
        return value.formatted(.percent.precision(.fractionLength(places)).locale(locale))
    }
}
