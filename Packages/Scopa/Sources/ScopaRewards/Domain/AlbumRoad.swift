import Foundation

/// A stop every ten cards found across the volumes together, each paid once.
///
/// Volumes fill in order, so the cards found across them is forty for each one finished
/// plus the open one's count, and every volume walks the same four stops. The first three
/// pay a little in denari, rising because each comes slower than the last: ten cards is
/// four packs in, thirty is the stretch where only courts and sevens are missing. The
/// fourth is the volume finished, which already pays its own bonus and prize, so the road
/// adds a Bottega to open the next volume with. Past the last volume a pack would only be
/// spares, so the end of the road pays the Bottega's price instead.
///
/// A whole volume's road comes to about 475 denari, against the several thousand a volume
/// takes in play: a marker on the way, not a second income.
public enum AlbumRoad {
    /// Cards between one stop and the next.
    public static let every = 10

    /// Cards across every volume, which is where the road ends.
    public static var length: Int { Volume.allCases.count * Album.size }

    public static var stops: [Int] { Array(stride(from: every, through: length, by: every)) }

    public enum Prize: Hashable, Sendable {
        case denari(Denari)
        case pack(PackTier)
    }

    public static func prize(at stop: Int) -> Prize {
        switch stop % Album.size {
        case 10: .denari(25)
        case 20: .denari(50)
        case 30: .denari(100)
        default: stop >= length ? .denari(PackTier.bottega.price ?? .zero) : .pack(.bottega)
        }
    }

    /// What names a stop in the ledger, so it pays once on every device.
    public static func key(for stop: Int) -> String { "album/milestone/\(stop)" }

    /// The stop a ledger key names, or nil for any other key.
    public static func stop(forKey key: String) -> Int? {
        let prefix = "album/milestone/"
        guard key.hasPrefix(prefix) else { return nil }
        return Int(key.dropFirst(prefix.count))
    }

    /// The first stop not yet reached, or nil past the end of the road.
    public static func next(after found: Int) -> Int? { stops.first { $0 > found } }

    /// What the road owes once `found` cards are in and `paid` stops are in the ledger.
    public struct Owed: Hashable, Sendable {
        /// The stop to pay in full.
        public let stop: Int?
        /// Stops behind it, written down as paid with nothing.
        public let waived: [Int]

        /// More than one stop came due at once: an album older than the road, or one
        /// caught up from another device. Only the furthest is paid, and the page says so.
        public var isCatchUp: Bool { !waived.isEmpty }
    }

    /// One stop at a time is paid in full. Packs bring five cards at most, so a page that
    /// settles after every opening only ever crosses one; more than one at once is history,
    /// and paying it all would be a flood of packs for cards found long ago.
    public static func owed(found: Int, paid: Set<Int>) -> Owed {
        let due = stops.filter { $0 <= found && !paid.contains($0) }
        return Owed(stop: due.last, waived: Array(due.dropLast()))
    }
}
