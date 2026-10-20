import Foundation
import ScopaCore

/// The gold album: the same forty cards once more, as foils.
///
/// Any card out of any pack may come out foil. It still counts for its volume as usual, and
/// the foil goes into Oro besides, so Oro fills alongside the volumes rather than after them.
/// Every value Oro is worth is on this page, as the volumes' are on `Album`'s. Perla, the
/// album after it, is filled by the same functions worked against its own pages: see `FoilAlbum`.
public enum Oro {
    /// How often one card of this rarity comes out gold, per card in an earned pack.
    ///
    /// The deck's own order, made gentler: each numeral shines more often than each court,
    /// each court than each seven, and the settebello least of all, about a third as often as
    /// a numeral rather than the tenth it is drawn at, so Oro can still be finished. These
    /// are odds per card, not per rarity: a rarity with more cards in it shines more often as
    /// a whole, and that is what fills the numerals first and leaves the settebello for last.
    public static func gold(_ rarity: Rarity) -> Double {
        switch rarity {
        case .plain: 15e-4
        case .court: 11e-4
        case .prime: 7.5e-4
        case .settebello: 5.5e-4
        }
    }

    /// How much more often a card out of this pack shines than one out of the earned pack.
    public static func boost(_ tier: PackTier) -> Double {
        switch tier {
        case .mazzetto, .scrigno, .forziere: 1
        case .bottega: 1.25
        case .velluto: 1.6
        case .reliquia: 2.2
        }
    }

    /// The chance a card of this rarity, drawn into a pack of this tier, comes out foil.
    ///
    /// Worked back from `gold(_:)` through how often a card like it turns up in that pack,
    /// promise and volume included, so the order holds in every pack: a Velluto's promised
    /// seven shines less often than an earned seven, because it turns up far more often. A
    /// card that came alone, like today's, was drawn without the promise. Until 1.4 the
    /// chance was fixed per rarity, at one in two for the settebello, which made a gold seven
    /// easier to find than a gold ace.
    public static func chance(of rarity: Rarity, in tier: PackTier, volume: Volume = .riviera,
                              promised: Bool = true) -> Double {
        odds[Odds(rarity: rarity, tier: tier, volume: volume, promised: promised)] ?? 0
    }

    private struct Odds: Hashable {
        let rarity: Rarity, tier: PackTier, volume: Volume, promised: Bool
    }

    /// Every chance worked out once: walking a Reliquia's every fall for each card of each
    /// pack would be the slowest thing about opening one.
    private static let odds: [Odds: Double] = {
        var odds: [Odds: Double] = [:]
        for rarity in Rarity.allCases {
            for tier in PackTier.allCases where tier.cards > 0 {
                for volume in Volume.allCases {
                    for promised in [true, false] {
                        let share = promised ? Pack.keptChance(of: rarity, in: tier, volume: volume)
                                             : Pack.chance(of: rarity, in: tier, volume: volume)
                        let cards = Double(Deck.standard.count { $0.rarity == rarity })
                        odds[Odds(rarity: rarity, tier: tier, volume: volume, promised: promised)] =
                            share > 0 ? min(1, gold(rarity) * boost(tier) * cards / share) : 0
                    }
                }
            }
        }
        return odds
    }()

    /// The share of a tier's cards that come out foil.
    public static func chance(in tier: PackTier) -> Double {
        guard tier.cards > 0 else { return 0 }
        return boost(tier) * Deck.standard.reduce(0) { $0 + gold($1.rarity) }
    }

    /// The odds one given card turns up gold somewhere in a pack of this tier: what the odds
    /// sheet prints, one line per rarity, so the order can be read straight off it.
    public static func cardChance(of rarity: Rarity, in tier: PackTier) -> Double {
        1 - pow(1 - gold(rarity) * boost(tier), Double(tier.cards))
    }

    /// What a foil Oro already has pays: five spares of the same card.
    public static func spare(of rarity: Rarity) -> Denari { rarity.spare * 5 }

    /// What a finished suit of foils leaves waiting in the album.
    public static let suitPack: PackTier = FoilAlbum.oro.suitPack

    /// Median days to fill Oro for a player on five games a day, today's card and nothing
    /// bought. Printed on the odds sheet; `OroTests` simulates it so the print stays true.
    public static let typicalDays = FoilAlbum.oro.typicalDays

    // MARK: Ledger and sync

    /// The ledger's name for a finished suit's pack, paid once wherever it was finished.
    public static func suitKey(_ suit: Suit) -> String { FoilAlbum.oro.suitKey(suit) }

    /// The ledger's name for the prize the whole of Oro pays.
    public static let prizeKey = FoilAlbum.oro.prizeKey

    /// How one foil travels between devices, beside the volumes' "napoli/7d".
    public static func code(of card: Card) -> String { FoilAlbum.oro.code(of: card) }

    /// The card a travelling code names, or nil when it is not one of Oro's.
    public static func card(fromCode code: String) -> Card? { FoilAlbum.oro.card(fromCode: code) }

    // MARK: Drawing and folding

    /// Rolls each card of a pack for foil. See `gild(_:foils:against:using:)` for what a
    /// foil of a card Oro already has turns into.
    /// `volume` is the one the pack was drawn for, whose scarcity it was drawn at.
    ///
    /// The last card Oro is missing always shines when it turns up. Without that, the gold
    /// settebello, the rarest foil by design, left one player in ten waiting well over a
    /// year for it after every other card was in.
    public static func gild(_ pack: Pack, against oro: Album, volume: Volume = .riviera,
                            using generator: inout some RandomNumberGenerator) -> FoilRoll {
        let promised = pack.cards.count == pack.tier.cards
        let lastGap = oro.found == Album.size - 1 ? Deck.standard.first { !oro.has($0) } : nil
        let foils = pack.cards.map { card in
            Double.random(in: 0..<1, using: &generator)
                < chance(of: card.rarity, in: pack.tier, volume: volume, promised: promised)
                || card == lastGap
        }
        return gild(pack, foils: foils, against: oro, using: &generator)
    }

    /// The pack with the places that shine already decided.
    ///
    /// A foil of a card Oro already has becomes one of the same rarity Oro is still missing.
    /// Within a rarity every card is equally likely, so the odds of each rarity stay as
    /// printed; what changes is that the last gaps fill as fast as the first, where pure
    /// chance leaves the last few foils years away. Once a rarity is full, its foils are
    /// spares and pay `spare(of:)`.
    public static func gild(_ pack: Pack, foils: [Bool], against oro: Album,
                            using generator: inout some RandomNumberGenerator) -> FoilRoll {
        var cards = pack.cards
        var taken = oro
        for index in cards.indices where foils.indices.contains(index) && foils[index] {
            let card = cards[index]
            if taken.has(card) {
                let missing = Deck.standard.filter { $0.rarity == card.rarity && !taken.has($0) }
                cards[index] = missing.randomElement(using: &generator) ?? card
            }
            _ = taken.open(Pack(cards: [cards[index]]))
        }
        return FoilRoll(pack: Pack(cards: cards, tier: pack.tier, cosmetics: pack.cosmetics), foils: foils)
    }

    /// Puts a pack's foils in Oro, or in whichever foil album `oro` is the pages of, and
    /// says what each did, in the pack's own order.
    public static func fold(_ roll: FoilRoll, into oro: inout Album, as album: FoilAlbum = .oro) -> Gilt {
        let opened = oro.open(Pack(cards: roll.foilCards))
        var found = opened.found.makeIterator()
        let foils = roll.pack.cards.indices.map { index -> Album.Found? in
            guard roll.isFoil(index), let one = found.next() else { return nil }
            return one.isNew ? one : .spare(one.card, spare(of: one.card.rarity))
        }
        return Gilt(foils: foils, suits: opened.suits, isComplete: opened.deck, album: album)
    }
}
