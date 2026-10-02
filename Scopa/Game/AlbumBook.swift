import Foundation
import Observation
import ScopaCore
import ScopaRewards

/// What has been collected, how many packs are waiting, and how close the next one is.
///
/// A handful of values in `UserDefaults`, like `ChallengeBook`: one album per volume, the
/// packs owed and the games counted towards the next. Nothing is sent anywhere — an album is what
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
        static let waiting = "album.waiting"
        static let games = "album.games"
        static let paidSuits = "album.paidSuits"
        static let paidDeck = "album.paidDeck"
        static let announced = "album.announced"
        static let gifts = "album.gifts"
    }

    private let defaults: UserDefaults

    /// Every volume collected so far. A volume nobody has started is simply not in here.
    private(set) var albums: [Volume: Album]
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
        self.albums = Self.albums(in: defaults)
        self.waiting = defaults.integer(forKey: Key.waiting)
        self.games = defaults.integer(forKey: Key.games)
        self.unannounced = defaults.integer(forKey: Key.announced)
        self.gifts = Self.gifts(in: defaults)
    }

    // MARK: Volumes

    /// Where a volume's cards are kept. The first keeps the key the album always had, so an
    /// album collected before there were volumes is the first volume, untouched.
    static func storageKey(for volume: Volume) -> String {
        volume == .riviera ? "album.cards" : "album.\(volume.rawValue).cards"
    }

    /// How a bonus is written down among the paid ones: a suit, or the whole deck when
    /// `suit` is nil. The first volume's suits keep their bare names as they always had,
    /// and its deck its own flag; a later volume prefixes both, so they travel between
    /// devices in the one list of paid bonuses an older build already carries along.
    static func bonusKey(_ suit: Suit?, in volume: Volume) -> String {
        if volume == .riviera, let suit { return suit.rawValue }
        return "\(volume.rawValue)/\(suit?.rawValue ?? "deck")"
    }

    private static func albums(in defaults: UserDefaults) -> [Volume: Album] {
        Volume.allCases.reduce(into: [:]) { albums, volume in
            guard let data = defaults.data(forKey: storageKey(for: volume)),
                  let album = try? JSONDecoder().decode(Album.self, from: data) else { return }
            albums[volume] = album
        }
    }

    private func store(_ volume: Volume) {
        guard let data = try? JSONEncoder().encode(album(volume)) else { return }
        defaults.set(data, forKey: Self.storageKey(for: volume))
    }

    /// One volume's album, empty until its first card.
    func album(_ volume: Volume) -> Album { albums[volume] ?? Album() }

    /// The first volume, which is the one the seat marks are worn off.
    var album: Album { album(.riviera) }

    /// Where packs go now: the first volume not yet full.
    var openVolume: Volume { Volume.open(given: album(_:)) }

    /// The album being collected, which is what the lobby's door and the settings count.
    var openAlbum: Album { album(openVolume) }

    /// The volumes filled to the last card, whose prizes are owed.
    var finishedVolumes: [Volume] { Volume.allCases.filter { album($0).isComplete } }

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
        albums = Self.albums(in: defaults)
        waiting = defaults.integer(forKey: Key.waiting)
        games = defaults.integer(forKey: Key.games)
        unannounced = defaults.integer(forKey: Key.announced)
        gifts = Self.gifts(in: defaults)
    }

    // MARK: The two shelves

    /// Every pack waiting, in the order they open: the gifts oldest first, then the earned.
    ///
    /// One queue for both shelves, split only when read. A shop pack is opened in the shop
    /// and a card pack in the album, but they are kept as they always were — so a shop
    /// pack queued by an older build simply turns up in the shop, never lost and never
    /// twice, and the queue still travels between devices as the same two preferences.
    /// Never more gifts than packs: a device that heard about one and not the other must
    /// not conjure a pack.
    private var queue: [PackTier] {
        let given = Array(gifts.prefix(waiting))
        return given + Array(repeating: .mazzetto, count: waiting - given.count)
    }

    /// How many packs wait on one shelf: cards in the album, the shop's own in the shop.
    func waiting(on shelf: PackTier.Shelf) -> Int { queue.count { $0.shelf == shelf } }

    /// The pack the next tap on that shelf opens, if any is waiting there.
    func next(on shelf: PackTier.Shelf) -> PackTier? { queue.first { $0.shelf == shelf } }

    /// The card pack the album's next tap opens: a gift if one is waiting, the earned pack
    /// otherwise.
    var nextTier: PackTier { next(on: .album) ?? .mazzetto }

    /// The album's red dot. A shop pack is never news there, including one an older build
    /// counted, so the dot is never more than the card packs it leads to.
    var albumNews: Int { min(unannounced, waiting(on: .album)) }

    /// A pack handed over rather than played for, left waiting like an earned one — a card
    /// pack in the album, a shop pack in the shop. The caller says once; the book does not
    /// know why it was given.
    func give(_ tier: PackTier) {
        waiting += 1
        if tier.shelf == .album { unannounced += 1 }
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

    /// The next pack waiting on one shelf, drawn and opened. Nil when none is waiting there.
    func openOne(on shelf: PackTier.Shelf = .album, owned: Set<ShopItem.ID> = []) -> Opening? {
        guard let tier = next(on: shelf) else { return nil }
        // Trimmed to the packs first, so the count and the list agree before one goes.
        gifts = Array(gifts.prefix(waiting))
        if let index = gifts.firstIndex(where: { $0.shelf == shelf }) { gifts.remove(at: index) }
        waiting -= 1
        storeGifts()
        defaults.set(waiting, forKey: Key.waiting)
        if shelf == .album { markSeen() }
        return open(tier: tier, owned: owned)
    }

    /// Draws a pack of the given tier and folds it into the open volume.
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
        let volume = openVolume
        var collected = album(volume)
        let opened = collected.open(pack)
        albums[volume] = collected
        store(volume)
        let (suits, deck) = settle(opened, in: volume)

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
        return Opening(volume: volume, tier: tier, found: opened.found, suits: suits, deck: deck, won: won)
    }

    /// Which of the bonuses an opening finished have not been paid before, written down as
    /// paid now. The first volume's names are the ones it always used.
    private func settle(_ opened: (found: [Album.Found], suits: [Suit], deck: Bool),
                        in volume: Volume) -> (suits: [Suit], deck: Bool) {
        var paid = Set(defaults.stringArray(forKey: Key.paidSuits) ?? [])
        let suits = opened.suits.filter { !paid.contains(Self.bonusKey($0, in: volume)) }
        paid.formUnion(suits.map { Self.bonusKey($0, in: volume) })
        let deck: Bool
        if volume == .riviera {
            deck = opened.deck && !defaults.bool(forKey: Key.paidDeck)
            if deck { defaults.set(true, forKey: Key.paidDeck) }
        } else {
            deck = opened.deck && !paid.contains(Self.bonusKey(nil, in: volume))
            if deck { paid.insert(Self.bonusKey(nil, in: volume)) }
        }
        defaults.set(Array(paid), forKey: Key.paidSuits)
        return (suits, deck)
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
        /// The volume its cards went into, which is also the deck they are drawn in.
        let volume: Volume
        let tier: PackTier
        let found: [Album.Found]
        /// Suits finished by this pack and not paid for before.
        let suits: [Suit]
        /// Whether this pack was the one that finished its volume.
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
    /// hundred games behind it. `-packs 3 -collected 18`, and `-volume napoli` to have
    /// every volume before that one full and the cards in that one.
    func pretend(packs: Int, found: Int, in volume: Volume = .riviera) {
        for earlier in Volume.allCases where earlier < volume {
            var full = Album()
            _ = full.open(Pack(cards: Deck.standard))
            albums[earlier] = full
            store(earlier)
        }
        // In deck order rather than shuffled, so `-collected 10` is the coins finished and
        // the mark that goes with them, which is the thing worth looking at.
        var started = Album()
        for card in Deck.standard.prefix(found) {
            _ = started.open(Pack(cards: [card]))
        }
        albums[volume] = started
        store(volume)
        // Earned packs only: gifts left over from the last run are `-giftPacks`'s to plant.
        self.waiting = packs
        self.unannounced = packs
        self.gifts = []
        storeGifts()
        defaults.set(packs, forKey: Key.waiting)
        defaults.set(packs, forKey: Key.announced)
    }

    /// Leaves exactly these packs waiting as gifts, each on its own shelf, beside the earned
    /// ones already there: `-giftPacks forziere,reliquia`.
    func pretend(gifts tiers: [PackTier]) {
        let earned = waiting - min(gifts.count, waiting)
        gifts = tiers.filter { $0 != .mazzetto }
        waiting = earned + gifts.count
        storeGifts()
        defaults.set(waiting, forKey: Key.waiting)
    }
    #endif
}

