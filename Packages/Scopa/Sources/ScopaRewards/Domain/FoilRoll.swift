import ScopaCore

/// A pack after its foils were rolled: the cards as they ended up, and which of them shine.
public struct FoilRoll: Hashable, Sendable {
    public let pack: Pack
    /// One per card, in the pack's order.
    public let foils: [Bool]

    public init(pack: Pack, foils: [Bool]) {
        self.pack = pack
        self.foils = foils
    }

    public func isFoil(_ index: Int) -> Bool { foils.indices.contains(index) && foils[index] }

    /// The cards that came out foil, in the pack's order.
    public var foilCards: [Card] { pack.cards.indices.filter(isFoil).map { pack.cards[$0] } }
}
