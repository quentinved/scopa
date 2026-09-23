import ScopaCore

/// The kinds of pack there are, and what each one is made of.
///
/// There are two shelves. The album sells packs made of cards, and the shop sells packs
/// made of what is on its own shelves — same wrapper, same tearing, different thing
/// inside. One pack on the card shelf is earned by playing; everything else is bought.
///
/// A tier differs from its neighbours along five axes and no others: how many cards, how
/// many things off the shelves, whether a card is guaranteed to be better than a numeral,
/// how far the thumb is on the scale for the good cards, and how poor the worst thing off
/// the shelves may be. Everything a tier is worth is on this page, the way everything the
/// album is worth is on `Album`'s.
public enum PackTier: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    /// Three cards, earned every few games. The pack the album was built around, and the
    /// only one that cannot be bought.
    case mazzetto
    /// Three cards with a court or better among them.
    case bottega
    /// Four cards, a seven or better among them, and something off the shelves.
    case velluto
    /// Five cards, better odds again, and something off the shelves that is never common.
    case reliquia
    /// Two things off the shelves and no cards at all, nothing common among them.
    case scrigno
    /// Three things off the shelves, and nothing among them below `prezioso`.
    case forziere

    public var id: String { rawValue }

    /// Which page sells a pack, which is also what it is made of.
    ///
    /// The two shelves are ladders in their own right and are never compared with each
    /// other: a `forziere` is not "better than" a `reliquia`, it is a different thing to
    /// want. Every place that ranks tiers ranks them within one shelf.
    public enum Shelf: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
        /// Bought on the album page, and made of cards.
        case album
        /// Bought in the shop, and made of what is on its shelves.
        case shop

        public var id: String { rawValue }
    }

    public var shelf: Shelf {
        switch self {
        case .mazzetto, .bottega, .velluto, .reliquia: .album
        case .scrigno, .forziere: .shop
        }
    }

    /// Every tier on one shelf, weakest first — the earned pack included.
    public static func on(_ shelf: Shelf) -> [PackTier] {
        allCases.filter { $0.shelf == shelf }
    }

    /// The ones on a shelf with a price on them, dearest last.
    public static func forSale(on shelf: Shelf) -> [PackTier] {
        on(shelf).filter { $0.price != nil }
    }

    /// A name, and Italian in every language, like the decks and the cloths.
    public var title: String {
        switch self {
        case .mazzetto: "Mazzetto"
        case .bottega: "Bottega"
        case .velluto: "Velluto"
        case .reliquia: "Reliquia"
        case .scrigno: "Scrigno"
        case .forziere: "Forziere"
        }
    }

    /// What it costs, or nil for the one that is played for rather than bought.
    ///
    /// The card packs are priced by what they are worth to a collection rather than by
    /// what their spares pay, because the album is the reason to open one.
    ///
    /// The shop packs cannot be priced that way: what is inside them is on sale a scroll
    /// away with a number on it. So they are priced off `Grade.denari(for:)`, which is
    /// already this game's statement of what one grade is worth — a `scrigno` costs what
    /// its two promised `raro` would pay, and a `forziere` a little under its three
    /// `prezioso`. Open one and get exactly what it promised and you have broken even;
    /// everything above the floor is the reason to open it rather than to shop. What is
    /// given up for that is the choosing, which is the whole trade a pack ever offers.
    public var price: Denari? {
        switch self {
        case .mazzetto: nil
        case .bottega: 260
        case .velluto: 620
        case .reliquia: 1400
        case .scrigno: 560
        case .forziere: 1500
        }
    }

    /// How many cards are in it. None, for a pack the shop sells.
    public var cards: Int {
        switch self {
        case .mazzetto, .bottega: 3
        case .velluto: 4
        case .reliquia: 5
        case .scrigno, .forziere: 0
        }
    }

    /// How many things off the shelves come with it.
    public var cosmetics: Int {
        switch self {
        case .mazzetto, .bottega: 0
        case .velluto, .reliquia: 1
        case .scrigno: 2
        case .forziere: 3
        }
    }

    /// Whether the pack is made of what is on the shop's shelves rather than of cards.
    /// The rider on a dear card pack is not the same thing: a `velluto` is four cards
    /// that happen to come with a felt.
    public var isCosmeticOnly: Bool { cards == 0 }

    /// The worst that cosmetic may be. A `velluto` can still turn up a `leggendario`; it
    /// just cannot turn up a `comune`.
    public var floorGrade: Grade {
        switch self {
        case .mazzetto, .bottega: .comune
        case .velluto, .scrigno: .raro
        case .reliquia, .forziere: .prezioso
        }
    }

    /// One card in the pack is at least this good, whatever the draw said. Nil for the
    /// earned pack, which is honest about being three cards off the top of the deck, and
    /// for the shop's packs, which hold no cards to promise anything about.
    public var floorCard: Rarity? {
        switch self {
        case .mazzetto, .scrigno, .forziere: nil
        case .bottega: .court
        case .velluto: .prime
        case .reliquia: .prime
        }
    }

    /// How much heavier than usual the cards above a numeral are drawn. One is the deck's
    /// own odds; the dear packs bend them and say by how much. One, too, for a pack with
    /// no cards to bend the odds of.
    public var luck: Double {
        switch self {
        case .mazzetto, .scrigno, .forziere: 1
        case .bottega: 1.8
        case .velluto: 3.2
        case .reliquia: 6
        }
    }

    /// What it is, in English and for the ledger. The line the shop actually prints is
    /// the app's, for the same reason a felt's is: a `String` built at runtime is a key no
    /// translator will ever see.
    public var detail: String {
        switch self {
        case .mazzetto: "Three cards, whatever the deck gives you"
        case .bottega: "Three cards, a court or better among them"
        case .velluto: "Four cards, a seven or better, and something off the shelves"
        case .reliquia: "Five cards, the best odds there are, nothing common with them"
        case .scrigno: "Two things off the shelves, nothing common among them"
        case .forziere: "Three things off the shelves, and nothing short of prezioso"
        }
    }
}
