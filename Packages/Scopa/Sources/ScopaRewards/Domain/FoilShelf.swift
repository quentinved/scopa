import ScopaCore

/// Both foil albums side by side, which is what a pack's foils are rolled against.
///
/// The open one takes them: Oro until its last foil is in, Perla from the next pack on. A
/// pack that finishes Oro keeps its other foils in Oro, as spares, so one pack's foils are
/// always finished in one material.
public struct FoilShelf: Hashable, Sendable {
    public var oro: Album
    public var perla: Album

    public init(oro: Album = Album(), perla: Album = Album()) {
        self.oro = oro
        self.perla = perla
    }

    /// The album foils go into now.
    public var open: FoilAlbum { .open(oro: oro) }

    public subscript(album: FoilAlbum) -> Album {
        get { album == .oro ? oro : perla }
        set { if album == .oro { oro = newValue } else { perla = newValue } }
    }

    /// Rolls a pack's foils against the open album and puts them in it. The odds, the swap
    /// of a foil it already has and the last gap shining are all `Oro.gild`'s.
    public mutating func gild(_ pack: Pack, volume: Volume = .riviera,
                              using generator: inout some RandomNumberGenerator) -> (pack: Pack, gilt: Gilt) {
        let roll = Oro.gild(pack, against: self[open], volume: volume, using: &generator)
        return (roll.pack, fold(roll))
    }

    /// Puts foils already decided into the open album, as a rigged pack has them.
    public mutating func fold(_ roll: FoilRoll) -> Gilt {
        let album = open
        var pages = self[album]
        let gilt = Oro.fold(roll, into: &pages, as: album)
        self[album] = pages
        return gilt
    }
}
