import ScopaCore

/// What one pack's foils did in the foil album open, Oro or Perla.
public struct Gilt: Hashable, Sendable {
    /// One per card in the pack, in drawn order: what its foil did, nil when it came out plain.
    public var foils: [Album.Found?]
    /// Suits of foils this pack finished.
    public var suits: [Suit]
    /// Whether this pack put the last foil in.
    public var isComplete: Bool
    /// The album the foils went into, which is what they are finished in.
    public var album: FoilAlbum

    public init(foils: [Album.Found?] = [], suits: [Suit] = [], isComplete: Bool = false,
                album: FoilAlbum = .oro) {
        self.foils = foils
        self.suits = suits
        self.isComplete = isComplete
        self.album = album
    }

    public func foil(at index: Int) -> Album.Found? {
        foils.indices.contains(index) ? foils[index] : nil
    }

    public var count: Int { foils.count { $0 != nil } }
    public var hasNew: Bool { foils.contains { $0?.isNew == true } }

    /// What the foils Oro already had paid.
    public var denari: Denari { foils.reduce(.zero) { $0 + ($1?.denari ?? .zero) } }
}
