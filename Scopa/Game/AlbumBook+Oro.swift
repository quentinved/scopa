import Foundation
import ScopaCore
import ScopaRewards

/// Oro, the gold album, and Perla, the pearl one after it, kept by the same book as the volumes.
///
/// One more album each in `UserDefaults`, under its own key, and the foils travel between
/// devices as "oro/7d" and "perla/7d" beside the volumes' codes, so the account needs no new
/// field for them. A build that knows no Perla passes its codes along without reading them.
extension AlbumBook {
    static let oroKey = "album.oro.cards"

    /// Where a foil album is kept. Oro keeps the key it always had.
    static func storageKey(for album: FoilAlbum) -> String {
        album == .oro ? oroKey : "album.\(album.rawValue).cards"
    }

    static func oro(in defaults: UserDefaults) -> Album { foils(.oro, in: defaults) }

    static func foils(_ album: FoilAlbum, in defaults: UserDefaults) -> Album {
        guard let data = defaults.data(forKey: storageKey(for: album)),
              let pages = try? JSONDecoder().decode(Album.self, from: data) else { return Album() }
        return pages
    }

    static func store(_ pages: Album, as album: FoilAlbum = .oro, in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(pages) else { return }
        defaults.set(data, forKey: storageKey(for: album))
    }

    /// One foil album's pages.
    func foils(_ album: FoilAlbum) -> Album { album == .oro ? oro : perla }

    /// Both, as the shelf a pack's foils are rolled against.
    var foilShelf: FoilShelf { FoilShelf(oro: oro, perla: perla) }

    /// Where foils go now: Oro until it is full, then Perla.
    var openFoils: FoilAlbum { foilShelf.open }

    /// Every foil by travelling code, for the account.
    var foilCodes: [String: Int] {
        FoilAlbum.allCases.reduce(into: [:]) { codes, album in
            for (card, count) in foils(album).counts { codes[album.code(of: card)] = count }
        }
    }

    /// Writes down the foils among an account's merged codes, album by album. Nothing for an
    /// album it carries none of, so an account written by an older build leaves this
    /// device's foils alone.
    static func storeFoils(from codes: [String: Int], in defaults: UserDefaults) {
        for album in FoilAlbum.allCases {
            let counts = codes.reduce(into: [Card: Int]()) { counts, entry in
                if let card = album.card(fromCode: entry.key) { counts[card] = entry.value }
            }
            guard !counts.isEmpty else { continue }
            store(Album(counts: counts), as: album, in: defaults)
        }
    }

    /// Rolls a pack's foils, turns a foil the open album already has into one it lacks, and
    /// puts the foils in it. The pack comes back as it ends up, for the volume to take.
    func gild(_ pack: inout Pack) -> Gilt {
        var generator = SystemRandomNumberGenerator()
        var shelf = foilShelf
        let gilt: Gilt
        if DebugLaunch.packFoil {
            // A rigged foil shows the very card asked for, so it is never swapped.
            gilt = shelf.fold(FoilRoll(pack: pack, foils: pack.cards.map(DebugLaunch.rigsFoil)))
        } else {
            let gilded = shelf.gild(pack, volume: openVolume, using: &generator)
            pack = gilded.pack
            gilt = gilded.gilt
        }
        if gilt.count > 0 {
            if gilt.album == .oro { oro = shelf.oro } else { perla = shelf.perla }
        }
        return gilt
    }

    #if DEBUG
    /// `-oro 12`: that many foils, in deck order, so twelve is the coins and two cups.
    func pretend(oro found: Int) {
        var gold = Album()
        _ = gold.open(Pack(cards: Array(Deck.standard.prefix(max(found, 0)))))
        oro = gold
    }

    /// `-perla 12`: Oro full, and that many pearl foils in deck order.
    func pretend(perla found: Int) {
        pretend(oro: Album.size)
        var pearl = Album()
        _ = pearl.open(Pack(cards: Array(Deck.standard.prefix(max(found, 0)))))
        perla = pearl
    }
    #endif
}
