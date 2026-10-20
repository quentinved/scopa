import ScopaCore

/// Cards that have left the album, read off the ledger.
///
/// An album's counts merge between devices by the larger, so a card taken out by lowering its
/// count would come back on the next sync. A card that leaves is written as a keyed line in
/// the ledger instead, and the ledger merges by union: once on one device, gone on all of
/// them, and written twice still gone once. The page shows what was found less what left.
///
/// The key says everything: `album/out/<volume>/<card>/<why>/…`. A gift writes
/// `album/out/napoli/7c/gift/2026-10-12/<id>`; anything else that spends a spare can write
/// its own reason after the card and be counted here the same way.
public struct Departures: Hashable, Sendable {
    public static let prefix = "album/out/"

    private var counts: [Volume: [Card: Int]] = [:]
    /// Gifts by the sender's day, which is what one a day counts.
    private var giftsByDay: [String: Int] = [:]

    public init() {}

    /// Every departure among these ledger keys. Keys of any other kind are passed over.
    public init(keys: some Sequence<String>) {
        for key in keys where key.hasPrefix(Self.prefix) { note(key) }
    }

    /// How many of one card have left one volume.
    public func count(of card: Card, in volume: Volume) -> Int { counts[volume]?[card] ?? 0 }

    /// How many of each card have left one volume.
    public func cards(in volume: Volume) -> [Card: Int] { counts[volume] ?? [:] }

    /// How many cards were given on the sender's day.
    public func gifts(on day: String) -> Int { giftsByDay[day] ?? 0 }

    /// The ledger key for one card given to a friend. The id is the gift's own, so the key is
    /// the same however many times it is written.
    public static func giftKey(_ card: Card, from volume: Volume, day: String, id: String) -> String {
        "\(prefix)\(volume.rawValue)/\(card.description)/gift/\(day)/\(id.lowercased())"
    }

    private mutating func note(_ key: String) {
        let parts = key.dropFirst(Self.prefix.count).split(separator: "/").map(String.init)
        guard parts.count >= 3, let volume = Volume(rawValue: parts[0]),
              let card = Deck.standard.first(where: { $0.description == parts[1] }) else { return }
        counts[volume, default: [:]][card, default: 0] += 1
        if parts[2] == "gift", parts.count >= 4 { giftsByDay[parts[3], default: 0] += 1 }
    }
}

public extension Album {
    /// This album less what has left it. A card found stays on the page whatever the ledger
    /// says: only spares ever leave, so the one copy the page shows is never taken.
    func less(_ departures: Departures, in volume: Volume) -> Album {
        let gone = departures.cards(in: volume)
        guard !gone.isEmpty else { return self }
        var kept = counts
        for (card, count) in gone {
            guard let found = kept[card], found > 0 else { continue }
            kept[card] = max(found - count, 1)
        }
        return Album(counts: kept)
    }
}
