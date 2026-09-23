/// Something for sale, always cosmetic. Nothing here may touch the rules, the assist or the
/// clock: this game is played against people in the same room, and the shop must never be
/// the reason someone lost.
public struct ShopItem: Identifiable, Hashable, Codable, Sendable {
    /// A stable name, written into the ledger and never changed once shipped: it is the
    /// only record that someone bought the thing.
    public struct ID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }
        public var description: String { rawValue }
    }

    /// Which shelf it sits on.
    public enum Kind: String, Codable, Sendable, CaseIterable, Hashable {
        /// The hand a deck is drawn in.
        case cardTheme
        /// The colours it is printed in. Separate from the drawing, because they vary
        /// independently: any hand can be had in any colourway.
        case cardSkin
        case cardBack
        case felt
        /// The weave of the cloth, which varies independently of the felt's colour for the
        /// same reason a drawing varies independently of a colourway.
        case tapis
        /// The mark over your own seat, which is one of the two things here the people
        /// across the table can see.
        case mark
        /// What is drawn around that mark, and the other thing they can see.
        case cornice
        case reactions
        /// The animal that sits by your hand. Yours alone, like the cloth.
        case companion
        /// The colour your own seat mark is struck in — your icon, and the first thing
        /// anybody at the table sees of you.
        case livery
        /// How a sweep is announced across the cloth.
        case flourish
        /// What a sweep sounds like.
        case cheer
    }

    public let id: ID
    public let kind: Kind
    public let title: String
    public let detail: String
    public let price: Denari
    /// How rare it is, which is a separate question from what it costs.
    ///
    /// Price says what the shop asks for it; grade says how few people have one. They
    /// mostly agree, and where they disagree the grade is the one worth printing: a thing
    /// that only falls out of the dearest pack is rare whether or not there is a till
    /// price beside it.
    public let grade: Grade

    public init(id: ID, kind: Kind, title: String, detail: String, price: Denari,
                grade: Grade = .comune) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.price = price
        self.grade = grade
    }
}

/// Everything on the shelves.
///
/// The package has no colours in it and no idea what a deck looks like. The app builds the
/// catalogue from its own cosmetics and hands it over, the way it keeps `CardTheme` to
/// itself and out of the rules.
public struct Catalogue: Hashable, Sendable {
    public let items: [ShopItem]

    public init(_ items: [ShopItem]) {
        self.items = items
    }

    public subscript(id: ShopItem.ID) -> ShopItem? {
        items.first { $0.id == id }
    }

    public func items(of kind: ShopItem.Kind) -> [ShopItem] {
        items.filter { $0.kind == kind }
    }

    public func items(of grade: Grade) -> [ShopItem] {
        items.filter { $0.grade == grade }
    }

    /// The shelves that actually have something on them, in declared order.
    public var kinds: [ShopItem.Kind] {
        ShopItem.Kind.allCases.filter { kind in items.contains { $0.kind == kind } }
    }
}
