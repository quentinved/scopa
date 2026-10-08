/// The score of a game played with a real deck, kept on the phone instead of on paper.
///
/// Nobody counts cards into it. After each hand the table says who took each of the four
/// points and how many scope each side swept, and the pad adds them up.
public struct ScorePad: Codable, Sendable, Hashable {
    public static let sideRange = 2...4

    /// One name per side. A team is one side with both names on it.
    public var sides: [String]
    public var target: Int
    public private(set) var hands: [Hand] = []

    public init(sides: [String], target: Int = 11) {
        self.sides = sides
        self.target = target
    }

    /// What one hand was worth. A point left nil is one the sides ended level on.
    public struct Hand: Codable, Sendable, Hashable {
        public var cards: Int?
        public var coins: Int?
        public var settebello: Int?
        public var primiera: Int?
        public var scope: [Int]

        public init(sides: Int) {
            scope = Array(repeating: 0, count: sides)
        }

        public func points(sides: Int) -> [Int] {
            var points = Array(repeating: 0, count: sides)
            for side in [cards, coins, settebello, primiera].compactMap({ $0 }) where points.indices.contains(side) {
                points[side] += 1
            }
            for side in scope.indices where points.indices.contains(side) {
                points[side] += scope[side]
            }
            return points
        }
    }

    public var totals: [Int] {
        hands.reduce(into: Array(repeating: 0, count: sides.count)) { totals, hand in
            for (side, points) in hand.points(sides: sides.count).enumerated() { totals[side] += points }
        }
    }

    /// The side that reached the target with a strict lead, as on the app's own tables.
    public var winner: Int? {
        let totals = totals
        guard totals.contains(where: { $0 >= target }) else { return nil }
        return Scoring.uniqueMax(totals)
    }

    public mutating func add(_ hand: Hand) {
        guard winner == nil else { return }
        hands.append(hand)
    }

    public mutating func undo() {
        _ = hands.popLast()
    }

    /// The same sides and target, from nothing.
    public mutating func restart() {
        hands = []
    }
}
