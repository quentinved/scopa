import Foundation
import Observation
import ScopaCore
import ScopaRewards

/// What has been collected, how many packs are waiting, and how close the next one is.
///
/// A handful of values in `UserDefaults`, like `ChallengeBook`: the album itself, the packs
/// owed and the games counted towards the next. Nothing is sent anywhere — an album is what
/// somebody has played for on this phone, and there is nothing in it for a server to check.
///
/// It draws and opens; it never pays. The denari a spare card is worth, and anything off
/// the shelves a dear pack turned up, are granted by whoever is showing the pack, through
/// the purse's own keyed grants — the same division of labour the weekly challenge is built
/// on, and what keeps the ledger the only thing that can say a reward has been paid.
@MainActor
@Observable
final class AlbumBook {
    private enum Key {
        static let album = "album.cards"
        static let waiting = "album.waiting"
        static let games = "album.games"
        static let paidSuits = "album.paidSuits"
        static let paidDeck = "album.paidDeck"
        static let announced = "album.announced"
        static let gifts = "album.gifts"
    }

    private let defaults: UserDefaults

    private(set) var album: Album
    /// Packs earned and not opened yet.
    private(set) var waiting: Int
    /// Finished games counted towards the next pack.
    private(set) var games: Int
    /// How many of the waiting packs the player has not been told about yet.
    ///
    /// Kept apart from `waiting` because they answer different questions. `waiting` is how
    /// many there are to open, and it goes down when one is opened. This is how many
    /// arrived since anyone last looked, and it is what the red dot on the lobby counts —
    /// it goes to nothing the moment the album is opened, whether or not a pack was.
    private(set) var unannounced: Int
    /// Which of the waiting packs are better than a `mazzetto`, oldest first: the pack a
    /// milestone level brings. They count in `waiting` like any other, and are opened first.
    ///
    /// Written down as "velluto,velluto" rather than as an array so it travels between
    /// devices as one plain preference, the latest word like `waiting` beside it.
    private(set) var gifts: [PackTier]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.album = defaults.data(forKey: Key.album)
            .flatMap { try? JSONDecoder().decode(Album.self, from: $0) } ?? Album()
        self.waiting = defaults.integer(forKey: Key.waiting)
        self.games = defaults.integer(forKey: Key.games)
        self.unannounced = defaults.integer(forKey: Key.announced)
        self.gifts = Self.gifts(in: defaults)
    }

    private static func gifts(in defaults: UserDefaults) -> [PackTier] {
        (defaults.string(forKey: Key.gifts) ?? "").split(separator: ",").compactMap { PackTier(rawValue: String($0)) }
    }

    private func storeGifts() {
        defaults.set(gifts.map(\.rawValue).joined(separator: ","), forKey: Key.gifts)
    }

    /// Reads the album again, for a book already on screen. `AccountSync` calls it after
    /// folding in whatever the player's other device has collected. Reads exactly what
    /// `init` reads, and sits beside it so the two cannot drift apart.
    func readStoredAgain() {
        album = defaults.data(forKey: Key.album)
            .flatMap { try? JSONDecoder().decode(Album.self, from: $0) } ?? Album()
        waiting = defaults.integer(forKey: Key.waiting)
        games = defaults.integer(forKey: Key.games)
        unannounced = defaults.integer(forKey: Key.announced)
        gifts = Self.gifts(in: defaults)
    }

    /// The pack the next tap opens: a gift if one is waiting, the earned pack otherwise.
    var nextTier: PackTier { gifts.first ?? .mazzetto }

    /// A pack handed over rather than played for, left waiting in the album like an
    /// earned one. The caller says once; the book does not know why it was given.
    func give(_ tier: PackTier) {
        waiting += 1
        unannounced += 1
        if tier != .mazzetto {
            gifts.append(tier)
            storeGifts()
        }
        defaults.set(waiting, forKey: Key.waiting)
        defaults.set(unannounced, forKey: Key.announced)
    }

    /// How many more games until the next pack.
    var gamesToGo: Int { max(Pack.gamesPerPack - games, 0) }

    /// A finished game, whatever it was and whoever won it. True when it earned a pack.
    ///
    /// Not keyed on the game: the caller counts a game once, and a book that kept its own
    /// copy of that rule would be a second place for it to be wrong.
    @discardableResult
    func countFinishedGame() -> Bool {
        games += 1
        guard games >= Pack.gamesPerPack else {
            defaults.set(games, forKey: Key.games)
            return false
        }
        games = 0
        waiting += 1
        unannounced += 1
        defaults.set(games, forKey: Key.games)
        defaults.set(waiting, forKey: Key.waiting)
        defaults.set(unannounced, forKey: Key.announced)
        return true
    }

    /// The album has been looked at, so the packs in it are no longer news. The badge goes;
    /// the packs stay until they are opened.
    func markSeen() {
        guard unannounced > 0 else { return }
        unannounced = 0
        defaults.set(0, forKey: Key.announced)
    }

    /// A pack that was paid for at the till rather than played for. It is opened straight
    /// away, so it never joins `waiting` and never counts as news.
    func openBought(_ tier: PackTier, owned: Set<ShopItem.ID>) -> Opening {
        open(tier: tier, owned: owned)
    }

    /// One earned pack, drawn and put into the album. Nil when none is waiting.
    func openOne(owned: Set<ShopItem.ID> = []) -> Opening? {
        guard waiting > 0 else { return nil }
        let tier = nextTier
        waiting -= 1
        // Never more gifts than packs: the two travel as separate preferences, and a
        // device that heard about one and not the other must not conjure a pack.
        if !gifts.isEmpty { gifts.removeFirst() }
        if gifts.count > waiting { gifts = Array(gifts.prefix(waiting)) }
        storeGifts()
        defaults.set(waiting, forKey: Key.waiting)
        markSeen()
        return open(tier: tier, owned: owned)
    }

    /// Draws a pack of the given tier and folds it into the album.
    ///
    /// The bonuses come back only the first time they are earned: the phone remembers
    /// which suits it has already paid for, so an album finished twice — a spare turning
    /// up after the last card — pays once.
    ///
    /// The cosmetics a dear pack promised are resolved here rather than in the package,
    /// because `ScopaRewards` carries them as grades and has no idea what a felt is. The
    /// set of what this one opening has already handed over is threaded through the draw,
    /// so a pack owing two things never owes the same thing twice.
    ///
    /// `owned` comes in from the purse rather than being read here: the book cannot reach
    /// the ledger, and the ledger is the only thing that can say what is owned. A pack
    /// drawn without it would hand over a felt somebody already has.
    private func open(tier: PackTier, owned: Set<ShopItem.ID>) -> Opening {
        var generator = SystemRandomNumberGenerator()
        let pack = Pack.draw(tier, using: &generator)
        let opened = album.open(pack)
        var paidSuits = Set(defaults.stringArray(forKey: Key.paidSuits) ?? [])
        let suits = opened.suits.filter { !paidSuits.contains($0.rawValue) }
        paidSuits.formUnion(suits.map(\.rawValue))
        let deck = opened.deck && !defaults.bool(forKey: Key.paidDeck)
        if deck { defaults.set(true, forKey: Key.paidDeck) }
        defaults.set(Array(paidSuits), forKey: Key.paidSuits)
        if let data = try? JSONEncoder().encode(album) { defaults.set(data, forKey: Key.album) }

        var taken: Set<ShopItem.ID> = []
        var won: [Won] = []
        for promised in pack.cosmetics {
            guard let item = Cosmetics.drop(atLeast: promised, excluding: taken,
                                            owns: { owned.contains($0.id) },
                                            using: &generator) else {
                // Nothing left on the shelves at or below what it promised. The pack pays
                // in denari instead, at what the shop would have charged: a pack that
                // turned up nothing because you already own everything is a bug you can
                // feel, and this is the only place it can be answered.
                won.append(.instead(Grade.denari(for: promised)))
                continue
            }
            taken.insert(item.id)
            won.append(.item(item))
        }
        return Opening(tier: tier, found: opened.found, suits: suits, deck: deck, won: won)
    }

    /// Something off the shelves that a pack turned up — or the denari it paid instead,
    /// when there was nothing left at that grade to hand over.
    enum Won: Identifiable, Equatable {
        case item(ShopItem)
        case instead(Denari)

        var id: String {
            switch self {
            case .item(let item): item.id.rawValue
            case .instead(let amount): "instead/\(amount.coins)"
            }
        }

        var item: ShopItem? { if case .item(let item) = self { item } else { nil } }
        var denari: Denari { if case .instead(let amount) = self { amount } else { .zero } }
    }

    /// What one pack turned out to be worth.
    struct Opening: Identifiable, Equatable {
        /// Names this opening, in the ledger and to the sheet that shows it.
        let id = UUID()
        let tier: PackTier
        let found: [Album.Found]
        /// Suits finished by this pack and not paid for before.
        let suits: [Suit]
        /// Whether this pack was the one that finished the deck.
        let deck: Bool
        /// What came off the shelves with it. Empty for the cheap tiers.
        let won: [Won]

        var cards: [Card] { found.map(\.card) }
        /// The best card in it, which is the one the pack is remembered by.
        var best: Album.Found? { found.max { $0.card.rarity < $1.card.rarity } }
        var isAllSpares: Bool { found.allSatisfy { !$0.isNew } }
        /// The best thing off the shelves in it, which outranks any card for the headline.
        var bestWon: ShopItem? { won.compactMap(\.item).max { $0.grade < $1.grade } }

        /// Everything it pays: the spares, the bonuses it finished, and anything it owed
        /// off the shelves but could not find.
        var denari: Denari {
            Album.denari(in: found)
                + Album.suitBonus * suits.count
                + (deck ? Album.deckBonus : .zero)
                + won.reduce(.zero) { $0 + $1.denari }
        }

        /// What names it in the ledger, so a grant retried pays once — and so two packs
        /// holding the same three cards are still two packs.
        var key: String { "pack/\(id.uuidString)" }

        /// The key for one thing off the shelves. Keyed on the slot as well as the pack,
        /// so a pack owing two of them records two unlocks.
        func key(forWon place: Int) -> String { "pack/\(id.uuidString)/won/\(place)" }
    }

    #if DEBUG
    /// Plants packs and a part-filled album, so the page can be looked at without a
    /// hundred games behind it. `-packs 3 -album 18`.
    func pretend(packs: Int, found: Int) {
        // In deck order rather than shuffled, so `-collected 10` is the coins finished and
        // the mark that goes with them, which is the thing worth looking at.
        var album = Album()
        for card in Deck.standard.prefix(found) {
            _ = album.open(Pack(cards: [card]))
        }
        self.album = album
        self.waiting = packs
        self.unannounced = packs
        if let data = try? JSONEncoder().encode(album) { defaults.set(data, forKey: Key.album) }
        defaults.set(packs, forKey: Key.waiting)
        defaults.set(packs, forKey: Key.announced)
    }
    #endif
}

