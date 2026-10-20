import ScopaCore

/// The foil albums, in the order they fill: Oro in gold, then Perla in mother-of-pearl.
///
/// One is open at a time. Every foil goes into Oro until it is full, and into Perla from
/// then on. Perla is the same forty cards at the same odds, under the same rules: the maths
/// is all `Oro`'s, and this only says which album it is worked against and what that one pays.
public enum FoilAlbum: String, CaseIterable, Comparable, Sendable {
    case oro, perla

    /// Where foils go: Oro until it is full, then Perla, and Perla for good once that is
    /// full too, where a foil pays its spares as a full Oro's did before there was a Perla.
    public static func open(oro: Album) -> FoilAlbum { oro.isComplete ? .perla : .oro }

    public static func < (lhs: FoilAlbum, rhs: FoilAlbum) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// What a finished suit leaves waiting in the album: Oro a Bottega, Perla a step up.
    public var suitPack: PackTier {
        switch self {
        case .oro: .bottega
        case .perla: .velluto
        }
    }

    /// Median days to fill it for a player on five games a day, today's card and nothing
    /// bought, counted from the day it opens. `OroTests` and `PerlaTests` simulate them.
    public var typicalDays: Int {
        switch self {
        case .oro: 210
        case .perla: 195
        }
    }

    // MARK: Ledger and sync

    /// The ledger's name for a finished suit's pack, paid once wherever it was finished.
    public func suitKey(_ suit: Suit) -> String { "\(rawValue)/\(suit.rawValue)" }

    /// The ledger's name for the prize the whole album pays.
    public var prizeKey: String {
        switch self {
        case .oro: "oro/bordo"
        case .perla: "perla/madreperla"
        }
    }

    /// How one foil travels between devices, beside the volumes' "napoli/7d". A build that
    /// knows no Perla reads "perla/7d" as no card of its own and passes it on untouched.
    public func code(of card: Card) -> String { "\(rawValue)/\(card)" }

    /// The card a travelling code names in this album, or nil when it is not one of its own.
    public func card(fromCode code: String) -> Card? {
        let prefix = "\(rawValue)/"
        guard code.hasPrefix(prefix) else { return nil }
        let name = code.dropFirst(prefix.count)
        return Deck.standard.first { $0.description == name }
    }
}
