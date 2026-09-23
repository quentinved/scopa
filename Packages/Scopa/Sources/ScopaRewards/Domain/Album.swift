import Foundation
import ScopaCore

/// The deck as something to collect, and what a pack of it is worth.
///
/// Every value in the album is on this one page, the way every value in the economy is on
/// `Earning`'s — re-balancing it is a single edit and never a hunt.
///
/// What is collected is the deck itself: the same forty cards the game is played with, in
/// the art they are already played in. Nothing here is a new thing to learn, and the one
/// card everybody who plays scopa already wants is the one that is hardest to find.

/// How hard a card is to come by, which is also how much a spare one is worth.
///
/// The order is the game's own. A numeral is a numeral; the court is worth ten in primiera
/// and looks it; a seven is the card primiera is won and lost on; and the seven of coins is
/// a point all by itself. So the cards a scopa player already cares about are the cards
/// the album is short of, and nobody has to be told which those are.
public enum Rarity: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case plain, court, prime, settebello

    public static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    /// How often one turns up, relative to a numeral. Weighed over the whole deck rather
    /// than per card, so the twenty-four plain cards crowd out the thirteen good ones on
    /// their own without any thumb on the scale.
    ///
    /// The figures used to come at half a numeral and the sevens at a third, which made a
    /// court an ordinary afternoon's find and the settebello about thirty packs away. It
    /// reads as a collection now: a numeral is what a pack is mostly made of, a court is
    /// the good news, and the seven of coins is the one card somebody is still short of a
    /// season in. The dear packs are the thumb on the scale, and they say so.
    ///
    /// The seven of coins sits a little under an ordinary seven rather than well under it,
    /// because the twenty-four numerals are what makes it scarce and a second thumb on the
    /// same scale would only make it unreachable.
    public var weight: Double {
        switch self {
        case .plain: 1
        case .court: 0.34
        case .prime: 0.18
        case .settebello: 0.10
        }
    }

    /// The best a pack's guarantee will ever pay in.
    ///
    /// A promise is a floor, not a lottery. `velluto` says "a seven or better", and the
    /// card it fills in when the draw came up short is drawn from the cards that clear
    /// that bar — of which there are four, and one of them is the settebello. Left
    /// uncapped, the promise handed the seven of coins over about one pack in five, which
    /// was neither what the shop printed nor a card anybody would still be chasing.
    ///
    /// So a guarantee tops out at an ordinary seven. The settebello is only ever drawn,
    /// never owed, and `Pack.packChance` is then the truth rather than an underestimate.
    public static let guaranteed: Rarity = .prime

    /// What a spare one pays. A pack is never a dud: a card already in the album is
    /// denari instead, and the better the card the better the consolation.
    public var spare: Denari {
        switch self {
        case .plain: 3
        case .court: 12
        case .prime: 20
        case .settebello: 75
        }
    }

    public var title: String {
        switch self {
        case .plain: "Numeral"
        case .court: "Court"
        case .prime: "Seven"
        case .settebello: "Settebello"
        }
    }
}

public extension Card {
    var rarity: Rarity {
        if self == .settebello { return .settebello }
        if rank == .seven { return .prime }
        return rank.isFace ? .court : .plain
    }
}

/// A pack, as drawn: the cards in it, and the grades of anything from the shop that came
/// with them. Every card is drawn on its own from the whole deck — so a pack can hand over
/// a card that is already in the album, and often will.
///
/// The cosmetics are carried as grades rather than as items, because this package has no
/// idea what a felt or a deck looks like and is not going to learn. The phone owns the
/// catalogue, so the phone turns `.leggendario` into a thing on a shelf; the same division
/// of labour that keeps `CardTheme` out of the rules.
public struct Pack: Hashable, Sendable, Codable {
    /// How many cards the earned pack holds. Kept as the old name so the places that only
    /// ever meant the free pack still read straight.
    public static let size = PackTier.mazzetto.cards
    /// How many finished games earn one. Whatever the game was and whoever won it: the
    /// album fills up by playing, which is the only thing it asks for.
    public static let gamesPerPack = 3

    public let tier: PackTier
    public let cards: [Card]
    /// What the shop owes for this pack, one grade per thing. Empty for the cheap tiers.
    public let cosmetics: [Grade]

    public init(cards: [Card], tier: PackTier = .mazzetto, cosmetics: [Grade] = []) {
        self.tier = tier
        self.cards = cards
        self.cosmetics = cosmetics
    }

    /// Draws a pack of the given tier.
    ///
    /// Two passes. The cards come first, each on its own by weight with the tier's luck
    /// bending everything above a numeral; then, if the tier promises a card no worse than
    /// something and the draw did not keep that promise, the weakest card in the pack is
    /// swapped for one that does. Promising and then checking is longer than drawing the
    /// guaranteed card first and the rest around it, but it leaves the odds on the page
    /// honest: a `reliquia` really can come up with three sevens.
    ///
    /// The card that keeps a promise is capped at `Rarity.guaranteed`, so making good on
    /// "a seven or better" cannot quietly be the way the settebello is handed out. See
    /// that constant for why the uncapped version was so much more generous than it read.
    public static func draw(_ tier: PackTier = .mazzetto,
                            using generator: inout some RandomNumberGenerator) -> Pack {
        var cards = (0..<tier.cards).map { _ in drawOne(luck: tier.luck, using: &generator) }
        if let floor = tier.floorCard, !cards.contains(where: { $0.rarity >= floor }) {
            let weakest = cards.indices.min { cards[$0].rarity < cards[$1].rarity } ?? 0
            cards[weakest] = drawOne(atLeast: floor, atMost: Rarity.guaranteed,
                                     luck: tier.luck, using: &generator)
        }
        let cosmetics = (0..<tier.cosmetics).map { _ in
            Grade.draw(atLeast: tier.floorGrade, using: &generator)
        }
        return Pack(cards: cards, tier: tier, cosmetics: cosmetics)
    }

    /// One card, by weight. The deck is small enough to add up every time, and adding it
    /// up every time is what keeps this honest when the weights are edited.
    ///
    /// `luck` multiplies everything that is not a numeral, so a tier bends the odds without
    /// owning a second copy of them. `floor` narrows the deck it draws from, which is how a
    /// guarantee is kept, and `ceiling` narrows it from the other end, which is how the
    /// guarantee is kept from being the best thing that can happen to you.
    ///
    /// A ceiling below the floor would leave nothing to draw from, so the floor wins: a
    /// promise is always kept, and the cap only ever trims what is above it.
    static func drawOne(atLeast floor: Rarity = .plain, atMost ceiling: Rarity = .settebello,
                        luck: Double = 1,
                        using generator: inout some RandomNumberGenerator) -> Card {
        let top = max(ceiling, floor)
        let deck = Deck.standard.filter { $0.rarity >= floor && $0.rarity <= top }
        func weight(_ card: Card) -> Double {
            card.rarity == .plain ? card.rarity.weight : card.rarity.weight * luck
        }
        let total = deck.reduce(0.0) { $0 + weight($1) }
        var roll = Double.random(in: 0..<total, using: &generator)
        for card in deck {
            roll -= weight(card)
            if roll < 0 { return card }
        }
        // Only reachable if a rounding error eats the last sliver of the last card.
        return deck[deck.count - 1]
    }

    /// What share of the cards in a pack of this tier come up at the given rarity, before
    /// the guarantee is applied. The shop and the album print these rather than describing
    /// the odds in words, because a number is the only description of odds worth trusting.
    public static func chance(of rarity: Rarity, in tier: PackTier) -> Double {
        let deck = Deck.standard
        func weight(_ card: Card) -> Double {
            card.rarity == .plain ? card.rarity.weight : card.rarity.weight * tier.luck
        }
        let total = deck.reduce(0.0) { $0 + weight($1) }
        guard total > 0 else { return 0 }
        return deck.filter { $0.rarity == rarity }.reduce(0.0) { $0 + weight($1) } / total
    }

    /// The odds of at least one card *this good or better* somewhere in a pack of the
    /// given tier — which is the figure a player actually cares about, since they open
    /// packs rather than cards, and since "a court or better" is the promise the shop
    /// makes rather than "exactly a court".
    ///
    /// A tier that guarantees this rarity answers 1, because it does.
    public static func packChance(ofAtLeast rarity: Rarity, in tier: PackTier) -> Double {
        if let floor = tier.floorCard, floor >= rarity { return 1 }
        let hit = Rarity.allCases.filter { $0 >= rarity }
            .reduce(0.0) { $0 + chance(of: $1, in: tier) }
        return 1 - pow(1 - hit, Double(tier.cards))
    }
}

/// What has been collected: how many of each card, and what that comes to.
public struct Album: Hashable, Sendable, Codable {
    /// How many of each card have been found. A card that is not in here has never turned
    /// up; a card with 1 is in the album and spare of it have been paid for.
    public private(set) var counts: [Card: Int]

    public init(counts: [Card: Int] = [:]) { self.counts = counts }

    /// The whole deck, which is what "complete" means.
    public static let size = Deck.standard.count

    public func has(_ card: Card) -> Bool { (counts[card] ?? 0) > 0 }
    public func count(of card: Card) -> Int { counts[card] ?? 0 }
    /// Spares of one card: what is in the album beyond the one that is on the page.
    public func spares(of card: Card) -> Int { max(count(of: card) - 1, 0) }

    public var found: Int { counts.values.count { $0 > 0 } }
    public var isComplete: Bool { found >= Self.size }
    public var fraction: Double { Double(found) / Double(Self.size) }

    /// Which cards of a suit are still missing, in deck order.
    public func missing(in suit: Suit) -> [Card] {
        Deck.standard.filter { $0.suit == suit && !has($0) }
    }

    public func isComplete(_ suit: Suit) -> Bool { missing(in: suit).isEmpty }

    /// The suits collected in full. What a completed suit is worth beyond its denari is
    /// decided on the phone — it is a seat mark — so this is what that reads.
    public var completedSuits: Set<Suit> { Set(Suit.allCases.filter(isComplete)) }

    /// What one card did on its way in: new to the album, or denari for a spare.
    public enum Found: Hashable, Sendable {
        case new(Card)
        case spare(Card, Denari)

        public var card: Card {
            switch self {
            case .new(let card), .spare(let card, _): card
            }
        }

        public var isNew: Bool { if case .new = self { true } else { false } }
        public var denari: Denari { if case .spare(_, let paid) = self { paid } else { .zero } }
    }

    /// What a suit pays the first time it is finished, and what the whole deck pays.
    /// Paid once each — the phone keys them, the way it keys a streak or a season.
    public static let suitBonus: Denari = 150
    public static let deckBonus: Denari = 750

    /// Opens a pack into the album and says what it did, card by card, in the order the
    /// pack drew them. The suits finished by this pack come back too, so whoever is
    /// showing the pack can pay for them and make something of it.
    public mutating func open(_ pack: Pack) -> (found: [Found], suits: [Suit], deck: Bool) {
        let before = Set(Suit.allCases.filter(isComplete))
        let wasComplete = isComplete
        var found: [Found] = []
        for card in pack.cards {
            let already = has(card)
            counts[card, default: 0] += 1
            found.append(already ? .spare(card, card.rarity.spare) : .new(card))
        }
        let suits = Suit.allCases.filter { isComplete($0) && !before.contains($0) }
        return (found, suits, isComplete && !wasComplete)
    }

    /// What a pack's worth of spares came to.
    public static func denari(in found: [Found]) -> Denari {
        found.reduce(.zero) { $0 + $1.denari }
    }
}
