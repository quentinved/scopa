import ScopaCore
import ScopaRewards
import SwiftUI

/// What is for sale, and how a shop item maps back to the thing it unlocks.
///
/// `ScopaRewards` knows nothing about how a deck looks, so the catalogue is assembled here
/// from the app's own cosmetics, the same way `CardTheme` stays out of `ScopaCore`.
///
/// A nil price means free and always owned, and keeps the item out of the shop entirely.
/// That is how the house deck and house colours stay off the shelves.
enum Cosmetics {
    static var catalogue: Catalogue {
        Catalogue(CardStyle.options.compactMap(\.shopItem)
                  + CardSkin.options.compactMap(\.shopItem)
                  + TableFelt.allCases.compactMap { item(for: $0) }
                  + Tapis.allCases.compactMap { item(for: $0) }
                  + SeatMark.allCases.compactMap { item(for: $0) }
                  + Cornice.allCases.compactMap { item(for: $0) }
                  + CardBackPattern.allCases.compactMap { item(for: $0) }
                  + Companion.allCases.compactMap { item(for: $0) }
                  + SeatLivery.allCases.compactMap { item(for: $0) }
                  + Flourish.allCases.compactMap { item(for: $0) }
                  + Cheer.allCases.compactMap { item(for: $0) }
                  + Song.allCases.compactMap { item(for: $0) }
                  + reactionPacks.map(\.item))
    }

    // MARK: Decks

    /// Three hundred is about nine evenings of play, at roughly thirty-five denari a game.
    /// The rarer the drawing, the dearer it is.
    private static func price(of style: CardStyle) -> Denari? {
        switch style {
        case .moderna: nil
        case .classica: 300
        case .antica: 400
        case .litografia: 550
        }
    }

    /// Colourways cost about half a drawing, since they retint the same deck. Notturna
    /// costs most because it changes the paper as well as the ink.
    private static func price(of skin: CardSkin) -> Denari? {
        switch skin {
        case .riviera: nil
        case .napoletana: 150
        case .piacentina: 150
        case .bergamasca: 150
        case .pergamena: 200
        case .notturna: 250
        }
    }

    /// How rare a drawing is. A whole hand redrawn is the biggest thing in the shop, so
    /// nothing here is common; the lithograph, which is the one that changes what the
    /// paper itself looks like, is the one graded up.
    private static func grade(of style: CardStyle) -> Grade {
        switch style {
        case .moderna: .comune
        case .classica, .antica: .raro
        case .litografia: .prezioso
        }
    }

    static func item(for style: CardStyle) -> ShopItem? {
        guard let price = price(of: style) else { return nil }
        return ShopItem(id: ShopItem.ID("deck.\(style.rawValue)"), kind: .cardTheme,
                        title: style.title, detail: style.detail, price: price,
                        grade: grade(of: style))
    }

    /// The three regional colourways are the ordinary shelf. The two that change the
    /// paper rather than the ink are not.
    private static func grade(of skin: CardSkin) -> Grade {
        switch skin {
        case .riviera, .napoletana, .piacentina, .bergamasca: .comune
        case .pergamena, .notturna: .raro
        }
    }

    static func item(for skin: CardSkin) -> ShopItem? {
        guard let price = price(of: skin) else { return nil }
        return ShopItem(id: ShopItem.ID("skin.\(skin.rawValue)"), kind: .cardSkin,
                        title: skin.title, detail: skin.detail, price: price,
                        grade: grade(of: skin))
    }

    // MARK: Felts

    private static func price(of felt: TableFelt) -> Denari? {
        switch felt {
        case .riviera: nil
        case .notte: 120
        case .vigna: 150
        case .pietra: 120
        // Earned through a streak, not bought. `Streaks` hands it over, the shop only
        // shows it, and the zero price lets the ledger record it as owned.
        case .festa: nil
        }
    }

    /// A felt is three gradient stops, so the bought ones are the shop's floor. The one
    /// that is played for rather than bought is not on that floor: a fortnight of playing
    /// every day is scarcer than anything with a price on it.
    private static func grade(of felt: TableFelt) -> Grade {
        Streaks.milestone(for: felt) != nil ? .prezioso : .comune
    }

    static func item(for felt: TableFelt) -> ShopItem? {
        if Streaks.milestone(for: felt) != nil {
            return ShopItem(id: id(for: felt), kind: .felt, title: felt.title, detail: felt.detail,
                            price: .zero, grade: grade(of: felt))
        }
        guard let price = price(of: felt) else { return nil }
        return ShopItem(id: id(for: felt), kind: .felt,
                        title: felt.title, detail: felt.detail, price: price,
                        grade: grade(of: felt))
    }

    // MARK: Tapis

    /// A cloth costs more than a felt: a felt swaps three gradient stops, a tapis is
    /// drawn across the whole table. The velvet is priced with the other `leggendario`
    /// things rather than with the cloths, because that is what it is. Prices and ids are
    /// the ones the cloths they replaced had, so nobody's purse changes.
    private static func price(of tapis: Tapis) -> Denari? {
        switch tapis {
        case .liscio: nil
        case .campo: 180
        case .lino: 200
        case .maiolica: 220
        case .ventaglio: 260
        case .velluto: 900
        }
    }

    /// Graded by accretion: a frame; a field with a hem; a field of figures; a field, a
    /// frame and ornaments; and all of that with a solid gold cord on top.
    private static func grade(of tapis: Tapis) -> Grade {
        switch tapis {
        case .liscio, .campo: .comune
        case .lino, .maiolica: .raro
        case .ventaglio: .prezioso
        case .velluto: .leggendario
        }
    }

    static func item(for tapis: Tapis) -> ShopItem? {
        guard let price = price(of: tapis) else { return nil }
        return ShopItem(id: ShopItem.ID("tapis.\(tapis.rawValue)"), kind: .tapis,
                        title: tapis.title, detail: tapis.detail, price: price,
                        grade: grade(of: tapis))
    }

    // MARK: Marks

    /// A seat mark is one of the few cosmetics other players see. Priced between a
    /// colourway and a deck.
    private static func price(of mark: SeatMark) -> Denari? {
        mark.isForSale ? 200 : nil
    }

    static func item(for mark: SeatMark) -> ShopItem? {
        guard let price = price(of: mark) else { return nil }
        // Graded up because the table can see it: a cosmetic other people notice is
        // scarcer than one only you look at, whatever the two cost.
        return ShopItem(id: id(for: mark), kind: .mark,
                        title: mark.rawValue.capitalized, detail: "seat mark \(mark.rawValue)",
                        price: price, grade: .raro)
    }

    static func mark(of id: ShopItem.ID) -> SeatMark? {
        SeatMark.allCases.first { Self.id(for: $0) == id }
    }

    private static func id(for mark: SeatMark) -> ShopItem.ID {
        ShopItem.ID("mark.\(mark.rawValue)")
    }

    // MARK: Cornici

    /// Priced with the seat marks: a cornice is the other half of the same thing.
    private static func price(of cornice: Cornice) -> Denari? {
        cornice == .none ? nil : 200
    }

    static func item(for cornice: Cornice) -> ShopItem? {
        guard let price = price(of: cornice) else { return nil }
        // With the marks: a cornice is the other half of the same thing, and just as seen.
        return ShopItem(id: ShopItem.ID("cornice.\(cornice.rawValue)"), kind: .cornice,
                        title: cornice.title, detail: cornice.detail, price: price, grade: .raro)
    }

    // MARK: Companions

    /// The dearest thing in the shop that is not a deck. A companion is the only cosmetic
    /// that reacts to play, looking up on your turn and cheering a sweep.
    private static func price(of companion: Companion) -> Denari? {
        switch companion {
        case .nessuno: nil
        case .gatto: 350
        case .cardellino: 300
        case .riccio: 300
        case .tartaruga: 320
        case .ferdinando: 350
        // Earned rather than bought: the Notturna album hands her over, and the zero price is
        // what lets the ledger record her as owned.
        case .civetta: .zero
        }
    }

    static func item(for companion: Companion) -> ShopItem? {
        guard let price = price(of: companion) else { return nil }
        // The only cosmetic in the shop that reacts to play, which is what puts all four
        // of them above the shelves that only change a colour.
        return ShopItem(id: ShopItem.ID("companion.\(companion.rawValue)"), kind: .companion,
                        title: companion.title, detail: companion.detail, price: price,
                        grade: .prezioso)
    }

    // MARK: Card backs

    /// Priced like a colourway. One pattern rather than forty drawings, but it is the card
    /// art seen most often.
    private static func price(of back: CardBackPattern) -> Denari? {
        if back == .free { return nil }
        // Earned rather than bought: the Napoli album hands it over, the shop only shows it.
        if back == .golfo { return .zero }
        return 150
    }

    static func item(for back: CardBackPattern) -> ShopItem? {
        guard let price = price(of: back) else { return nil }
        // The album's back is graded like the other things only an album gives.
        return ShopItem(id: ShopItem.ID("back.\(back.rawValue)"), kind: .cardBack,
                        title: back.name, detail: "card back \(back.rawValue)", price: price,
                        grade: back == .golfo ? .prezioso : .comune)
    }

    // MARK: The colour of your mark

    /// A flat colour is the shop's floor; the three that are not flat are what the dear
    /// end of this shelf is for. Kept on `SeatLivery` rather than here, because the thing
    /// that knows a livery is a gradient is the livery.
    private static func price(of livery: SeatLivery) -> Denari? {
        switch livery {
        case .tavolo: nil
        case .terracotta, .lavanda, .oliva, .mare: 130
        case .rubino: 210
        case .notte: 420
        case .oro: 480
        // The only thing in the shop that is neither a colour nor a picture but a
        // procession of colours, and priced as the one thing nobody else will have.
        case .iride: 950
        }
    }

    static func item(for livery: SeatLivery) -> ShopItem? {
        guard let price = price(of: livery) else { return nil }
        return ShopItem(id: ShopItem.ID("livery.\(livery.rawValue)"), kind: .livery,
                        title: livery.title, detail: livery.detail, price: price,
                        grade: livery.grade)
    }

    // MARK: What a sweep looks like

    static func item(for flourish: Flourish) -> ShopItem? {
        guard let price = flourish.price else { return nil }
        return ShopItem(id: ShopItem.ID("flourish.\(flourish.rawValue)"), kind: .flourish,
                        title: flourish.title, detail: flourish.detail, price: price,
                        grade: flourish.grade)
    }

    // MARK: What a sweep sounds like

    static func item(for cheer: Cheer) -> ShopItem? {
        guard let price = cheer.price else { return nil }
        return ShopItem(id: ShopItem.ID("cheer.\(cheer.rawValue)"), kind: .cheer,
                        title: cheer.title, detail: cheer.detail, price: price,
                        grade: cheer.grade)
    }

    // MARK: Table songs

    static func item(for song: Song) -> ShopItem? {
        guard let price = song.price else { return nil }
        return ShopItem(id: ShopItem.ID("song.\(song.rawValue)"), kind: .song,
                        title: song.title, detail: song.detail, price: price,
                        grade: song.grade)
    }

    static func song(of id: ShopItem.ID) -> Song? {
        Song.allCases.first { item(for: $0)?.id == id }
    }

    // MARK: What a pack owes

    /// Something at this grade that is not owned yet, or nil when there is nothing left to
    /// hand over at it.
    ///
    /// The choice is uniform inside a grade: the grade is where the scarcity lives, and a
    /// second set of weights underneath it would be two dials doing one job. A pack that
    /// finds nothing here falls to the grade below — see `AlbumBook`, which is the only
    /// caller and the one that knows what has already been paid out in the same opening.
    private static func unowned(at grade: Grade, excluding taken: Set<ShopItem.ID>,
                                owns: (ShopItem) -> Bool,
                                using generator: inout some RandomNumberGenerator) -> ShopItem? {
        catalogue.items
            .filter { $0.grade == grade && isInPacks($0) && !taken.contains($0.id) && !owns($0) }
            .randomElement(using: &generator)
    }

    /// Whether a pack may hand this over.
    ///
    /// Only things the shop actually sells. A zero price here means earned rather than
    /// free — the festa felt is on the shelves at nothing so the ledger can record it, and
    /// it is had by playing every day for a fortnight. A pack that could turn it up would
    /// be a pack that sells the one thing in the game money cannot buy.
    static func isInPacks(_ item: ShopItem) -> Bool { item.price != .zero }

    /// What a pack hands over for one cosmetic slot: the grade it promised if the shop has
    /// anything left at it, else the best thing below that it does have.
    static func drop(atLeast promised: Grade, excluding taken: Set<ShopItem.ID>,
                     owns: (ShopItem) -> Bool,
                     using generator: inout some RandomNumberGenerator) -> ShopItem? {
        for grade in promised.orBelow {
            if let item = unowned(at: grade, excluding: taken, owns: owns, using: &generator) {
                return item
            }
        }
        return nil
    }

    /// What a cosmetic maps back to, for the pack that just handed one over and the tile
    /// that has to draw it. Nil for a kind with nothing to preview.
    static func livery(of id: ShopItem.ID) -> SeatLivery? {
        SeatLivery.allCases.first { item(for: $0)?.id == id }
    }

    static func flourish(of id: ShopItem.ID) -> Flourish? {
        Flourish.allCases.first { item(for: $0)?.id == id }
    }

    static func cheer(of id: ShopItem.ID) -> Cheer? {
        Cheer.allCases.first { item(for: $0)?.id == id }
    }

    // MARK: Reactions

    /// Things to say without typing, sold four at a time. The one shelf the other players
    /// get something out of.
    ///
    /// A pack is four sentences in one voice, so the shop prints the lines rather than a
    /// row of faces.
    struct ReactionPack: Identifiable {
        let id: ShopItem.ID
        let title: String
        let detail: LocalizedStringKey
        let reactions: [Reaction]
        let price: Denari

        var item: ShopItem {
            ShopItem(id: id, kind: .reactions, title: title,
                     detail: "reaction pack \(id.rawValue)", price: price, grade: .comune)
        }
    }

    /// The lines are shown in full by the shop, so `detail` says who talks like that
    /// rather than repeating them.
    static let reactionPacks: [ReactionPack] = [
        ReactionPack(id: "reactions.osteria", title: "Osteria",
                     detail: "The table with a bottle on it",
                     reactions: [.mamma, .perfetto, .sleepy, .fortuna], price: 150),
        ReactionPack(id: "reactions.sfida", title: "Sfida",
                     detail: "For when it stops being friendly",
                     reactions: [.fire, .respect, .no, .clever], price: 150),
        ReactionPack(id: "reactions.nonna", title: "Nonna",
                     detail: "Whoever it was that taught you",
                     reactions: [.careful, .taught, .patience, .told], price: 150),
    ]

    static func felt(of id: ShopItem.ID) -> TableFelt? {
        TableFelt.allCases.first { Self.id(for: $0) == id }
    }

    private static func id(for felt: TableFelt) -> ShopItem.ID {
        ShopItem.ID("felt.\(felt.rawValue)")
    }

    // MARK: Shelves

    /// Plain names, so a newcomer can tell the shelves apart at a glance.
    static func title(of kind: ShopItem.Kind) -> LocalizedStringKey {
        switch kind {
        case .cardTheme: "Card art"
        case .cardSkin: "Card colours"
        case .cardBack: "Card backs"
        case .felt: "Table colour"
        case .tapis: "Table cloth"
        case .mark: "Seat badge"
        case .cornice: "Badge frame"
        case .reactions: "Phrases"
        case .companion: "Companion"
        case .livery: "Badge colour"
        case .flourish: "Sweep effect"
        case .cheer: "Sweep sound"
        case .song: "Table music"
        }
    }

    /// The line under a shelf's name: what buying from it changes, and who notices.
    static func subtitle(of kind: ShopItem.Kind) -> LocalizedStringKey {
        switch kind {
        case .cardTheme: "How the figures and pips on every card are drawn."
        case .cardSkin: "The inks the deck is printed in. Works with any card art."
        case .cardBack: "The pattern on the back of every card."
        case .felt: "The colour of the felt under the cards."
        case .tapis: "The pattern and border woven across the felt."
        case .mark: "The emblem on your seat. Everyone at the table sees it."
        case .cornice: "A ring around your badge. Everyone sees it."
        case .reactions: "Extra things to say at the table, four to a set."
        case .companion: "A little animal by your hand that cheers your sweeps. Everyone sees it."
        case .livery: "The colour your badge is struck in. Everyone sees it."
        case .flourish: "What fills the table when you sweep it clean (a scopa)."
        case .cheer: "What you hear when you make a scopa. Only you hear it."
        case .song: "The song that plays during your games. Tap play to listen first."
        }
    }
}

/// One axis of the deck's look: a drawing form or a colourway. Both are picked the same way
/// and shown with the same swatch, so shop and lobby lay them out with one piece of code.
protocol DeckOption: Identifiable, Hashable {
    static var options: [Self] { get }
    /// A name, usually a place, which is the same word in every language.
    var title: String { get }
    /// The ledger's own words for it, in English. Never shown in the interface.
    var detail: String { get }
    /// The line under the swatch.
    var explanation: LocalizedStringKey { get }
    /// What unlocks it, or nil when it is free for everybody.
    var shopItem: ShopItem? { get }
    /// The given deck with this option swapped in, used for previews as well as picking.
    func applied(to theme: CardTheme) -> CardTheme
}

extension CardStyle: DeckOption {
    static var options: [CardStyle] { allCases }
    var shopItem: ShopItem? { Cosmetics.item(for: self) }
    func applied(to theme: CardTheme) -> CardTheme { CardTheme(style: self, skin: theme.skin) }
}

extension CardSkin: DeckOption {
    static var options: [CardSkin] { allCases }
    var shopItem: ShopItem? { Cosmetics.item(for: self) }
    func applied(to theme: CardTheme) -> CardTheme { CardTheme(style: theme.style, skin: self) }
}
