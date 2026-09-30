import Foundation

/// One printing of the album: the same forty cards, collected again in another drawing.
///
/// Nothing about the collecting changes from one volume to the next — the deck, the packs,
/// the rarities and the odds are all `Album`'s and `Pack`'s — only the art the cards are
/// printed in and what finishing it pays, and the phone decides both. This package knows a
/// volume only by its place in the order.
///
/// Volumes open in order. The next one opens the moment the one before it is full, and from
/// then on that is where every pack goes: a finished album only ever turned a pack into
/// spares, and spares alone are not a reason to open one.
public enum Volume: String, CaseIterable, Codable, Sendable, Hashable, Comparable, Identifiable {
    case riviera, napoli, pergamena, notturna

    public var id: String { rawValue }

    /// Counted from one, as the covers print it.
    public var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    public static func < (a: Volume, b: Volume) -> Bool { a.number < b.number }

    /// The volume that has to be full before this one opens. Nil for the first.
    public var previous: Volume? {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return index > 0 ? Self.allCases[index - 1] : nil
    }

    /// Where packs go: the first volume not yet full, or the last once every one of them is,
    /// where a pack is spares and pays in denari like any finished album always has.
    public static func open(given albums: (Volume) -> Album) -> Volume {
        allCases.first { !albums($0).isComplete } ?? allCases[allCases.count - 1]
    }

    /// Whether this volume can be opened yet: it is the open one, or one already behind it.
    public func isOpen(given albums: (Volume) -> Album) -> Bool {
        self <= Self.open(given: albums)
    }
}
