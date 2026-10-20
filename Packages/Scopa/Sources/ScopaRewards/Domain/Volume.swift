import Foundation

/// One printing of the album: the same forty cards, collected again in another drawing.
///
/// Little about the collecting changes from one volume to the next — the deck, the packs,
/// the rarities and the odds are all `Album`'s and `Pack`'s — beyond the art the cards are
/// printed in and what finishing it pays, and the phone decides both. The one thing that
/// does is how hard the later volumes hold their good cards back, their `scarcity`. This
/// package knows a volume only by its place in the order.
///
/// Volumes open in order. The next one opens the moment the one before it is full, and from
/// then on that is where every pack goes: a finished album only ever turned a pack into
/// spares, and spares alone are not a reason to open one.
public enum Volume: String, CaseIterable, Codable, Sendable, Hashable, Comparable, Identifiable {
    case riviera, napoli, pergamena, notturna
    /// The first printed in a drawing of its own rather than one the shop already sold.
    case maiolica
    /// Set in tesserae, the second drawn for the album.
    case mosaico
    /// Venice in carnival, the first of the volumes that keep their good cards back.
    case carnevale
    /// Sorrento's inlaid woods.
    case intarsio
    /// Burano lace, worked in needlepoint.
    case merletto
    /// A gilded Visconti tarot, the last and the hardest to fill.
    case tarocchi

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

    /// How much harder than the deck's own odds everything above a numeral is to find in
    /// this volume: one for the first six, more for each one after. Divides a pack's luck,
    /// so a later volume asks for more packs without changing what any pack promises.
    ///
    /// Set by simulation rather than by feel: an earned pack at a time, trading whenever a
    /// trade is on, the median player needs 120 packs for Mosaico, and Carnevale takes about
    /// 1.3 times that, Intarsio 1.6, Merletto 1.9 and Tarocchi 2.2.
    /// `Volumes.laterVolumesTakeLonger` pins the order.
    public var scarcity: Double {
        switch self {
        case .riviera, .napoli, .pergamena, .notturna, .maiolica, .mosaico: 1
        case .carnevale: 1.4
        case .intarsio: 1.75
        case .merletto: 2.1
        case .tarocchi: 2.45
        }
    }

    /// Whether this volume can be opened yet: it is the open one, or one already behind it.
    public func isOpen(given albums: (Volume) -> Album) -> Bool {
        self <= Self.open(given: albums)
    }
}
