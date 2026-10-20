import ScopaCore

/// A trade: spares from the volume being collected for a numeral or a court it is still
/// missing.
///
/// Every spare is worth something in numerals, the card wanted costs something in numerals,
/// and a spare only counts towards a card when it is at least as good as the card's floor.
/// So numerals only ever buy numerals, and courts and spare sevens buy courts. The sevens
/// and the settebello are never traded for: they only ever come out of a pack.
///
/// The rate is fifteen to twenty spares for one card of the same scarcity: a trade is a
/// small help on a long run of bad luck, not a second road through the album. Measured on
/// earned packs, a volume takes a median of about 120 packs with every trade made, against
/// 129 with none. The owner found the earlier rates too easy three times: three or four
/// spares (77 packs), eight to ten with the settebello on offer (97), then fifteen to twenty
/// with the sevens on offer (110).
///
/// Holding trades back until a hundred packs made it easier, not harder (median 100): the
/// spares pile up meanwhile, and on the day it opens thirty courts buy the missing seven.
///
/// A spare settebello is never traded away. It paid 75 denari when it came in, and handing
/// it over for a numeral is a mistake nobody should be one tap from making.
public enum Scambio {
    /// What a missing card of some rarity costs, and the least a spare must be to count.
    public struct Price: Hashable, Sendable {
        /// In numerals: a court counts as three, a seven as six.
        public let worth: Int
        public let floor: Rarity
    }

    /// Trading opens in a volume only once it has taken in this many packs, so a trade is a
    /// late help on a long album and never the way one starts.
    public static let packsBeforeTrading = 100

    /// Packs' worth of cards a volume has taken in, the earned pack's three to a pack: every
    /// card that came, spares and the ones traded or given away included.
    public static func packsOpened(into album: Album) -> Int {
        album.counts.values.reduce(0, +) / Pack.size
    }

    /// What a spare counts for, in numerals. Nil for the settebello, which is never given.
    public static func worth(of rarity: Rarity) -> Int? {
        switch rarity {
        case .plain: 1
        case .court: 3
        case .prime: 6
        case .settebello: nil
        }
    }

    /// Twenty numerals for a numeral; fifteen courts for a court. Nil for a seven or the
    /// settebello, which no pile of spares can buy.
    public static func price(of rarity: Rarity) -> Price? {
        switch rarity {
        case .plain: Price(worth: 20, floor: .plain)
        case .court: Price(worth: 45, floor: .court)
        case .prime, .settebello: nil
        }
    }

    /// The ledger keys that take a trade's spares out of a volume, one per copy. Named by
    /// the card they brought in, which can only ever come in once, so the same trade made on
    /// two devices leaves once. See `Departures`.
    public static func departureKeys(for offer: Offer, from volume: Volume) -> [String] {
        offer.spares.sorted { $0.key.description < $1.key.description }.flatMap { spare, count in
            (1...max(count, 1)).map { copy in
                "\(Departures.prefix)\(volume.rawValue)/\(spare)/scambio/\(offer.card)/\(copy)"
            }
        }
    }

    /// One trade, worked out: the card wanted and the spares it takes.
    public struct Offer: Hashable, Sendable, Identifiable {
        public let card: Card
        public let spares: [Card: Int]

        public var id: Card { card }
        public var count: Int { spares.values.reduce(0, +) }

        /// How many of the spares going are of one rarity.
        public func count(of rarity: Rarity) -> Int {
            spares.filter { $0.key.rarity == rarity }.values.reduce(0, +)
        }
    }

    /// The trade for a missing card, or nil when it is already in or the spares fall short.
    ///
    /// Cheapest spares first, and of those the card with the most to spare, so a trade eats
    /// the pile rather than the variety. Then anything the price is still met without is put
    /// back, so a court that tipped it over does not leave three numerals overpaid.
    public static func offer(for card: Card, in album: Album) -> Offer? {
        guard !album.has(card), let price = price(of: card.rarity) else { return nil }
        var taken: [Card] = []
        var paid = 0
        for spare in pile(in: album, atLeast: price.floor) where paid < price.worth {
            taken.append(spare)
            paid += worth(of: spare.rarity) ?? 0
        }
        guard paid >= price.worth else { return nil }
        let kept = trimmed(taken, paid: paid, to: price.worth)
        return Offer(card: card, spares: kept.reduce(into: [:]) { $0[$1, default: 0] += 1 })
    }

    /// Puts back the cheapest spares the price is met without, the last taken first.
    private static func trimmed(_ taken: [Card], paid: Int, to price: Int) -> [Card] {
        var paid = paid
        var dropped: Set<Int> = []
        for index in taken.indices.reversed().sorted(by: { taken[$0].rarity < taken[$1].rarity }) {
            let without = paid - (worth(of: taken[index].rarity) ?? 0)
            guard without >= price else { continue }
            paid = without
            dropped.insert(index)
        }
        return taken.indices.filter { !dropped.contains($0) }.map { taken[$0] }
    }

    /// Every missing card the spares could bring in now, the rarest first.
    public static func offers(in album: Album) -> [Offer] {
        Deck.standard.filter { !album.has($0) }
            .sorted { $0.rarity > $1.rarity }
            .compactMap { offer(for: $0, in: album) }
    }

    /// Every spare that may pay for a card with this floor, one entry per copy, in the
    /// order they are spent.
    static func pile(in album: Album, atLeast floor: Rarity) -> [Card] {
        let cards = Deck.standard.filter { $0.rarity >= floor && worth(of: $0.rarity) != nil }
        let ordered = cards.sorted { a, b in
            if a.rarity != b.rarity { return a.rarity < b.rarity }
            return album.spares(of: a) > album.spares(of: b)
        }
        return ordered.flatMap { Array(repeating: $0, count: album.spares(of: $0)) }
    }
}

public extension Album {
    /// Spares of every card of one rarity.
    func spares(ofRarity rarity: Rarity) -> Int {
        Deck.standard.filter { $0.rarity == rarity }.reduce(0) { $0 + spares(of: $1) }
    }
}
