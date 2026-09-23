public enum ScoreCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case cards, coins, settebello, primiera
}

/// Points earned in one round, with the side that won each category (nil on a tie).
public struct RoundScore: Hashable, Codable, Sendable {
    public var points: [Int]
    public var categoryWinners: [ScoreCategory: Int?]
    public var scope: [Int]
    /// What each side had in each category, indexed by side: cards, coins, 1 or 0 for the
    /// settebello, and the primiera total. For a summary that shows why a point went where it did.
    public var tallies: [ScoreCategory: [Int]] = [:]
    /// Each side's best card per suit, best first. Under most-sevens, its sevens.
    public var primieraCards: [[Card]] = []
    /// What each side took from each category, indexed by side. Under shared ties a
    /// category with no single winner still pays, so a summary reads from here.
    public var categoryPoints: [ScoreCategory: [Int]] = [:]

    public init(points: [Int], categoryWinners: [ScoreCategory: Int?], scope: [Int],
                tallies: [ScoreCategory: [Int]] = [:], primieraCards: [[Card]] = [],
                categoryPoints: [ScoreCategory: [Int]] = [:]) {
        self.points = points
        self.categoryWinners = categoryWinners
        self.scope = scope
        self.tallies = tallies
        self.primieraCards = primieraCards
        self.categoryPoints = categoryPoints
    }

    /// What `side` took for `category`.
    public func points(for category: ScoreCategory, side: Int) -> Int {
        categoryPoints[category]?[safe: side] ?? ((categoryWinners[category] ?? nil) == side ? 1 : 0)
    }

    private enum CodingKeys: String, CodingKey {
        case points, categoryWinners, scope, tallies, primieraCards, categoryPoints
    }

    /// By hand, so a round scored by an older build still reads back.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([Int].self, forKey: .points)
        categoryWinners = try container.decode([ScoreCategory: Int?].self, forKey: .categoryWinners)
        scope = try container.decode([Int].self, forKey: .scope)
        tallies = try container.decodeIfPresent([ScoreCategory: [Int]].self, forKey: .tallies) ?? [:]
        primieraCards = try container.decodeIfPresent([[Card]].self, forKey: .primieraCards) ?? []
        // Before shared ties existed a category paid at most one point, to its winner.
        categoryPoints = try container.decodeIfPresent([ScoreCategory: [Int]].self, forKey: .categoryPoints)
            ?? categoryWinners.reduce(into: [:]) { table, entry in
                table[entry.key] = points.indices.map { $0 == entry.value ? 1 : 0 }
            }
    }
}

public enum Scoring {
    /// Card values used for the primiera: 7 is best, then 6, ace, 5, 4, 3, 2, and face cards last.
    public static func primieraValue(_ rank: Rank) -> Int {
        switch rank {
        case .seven: 21
        case .six: 18
        case .ace: 16
        case .five: 15
        case .four: 14
        case .three: 13
        case .two: 12
        case .knave, .knight, .king: 10
        }
    }

    /// Best card per suit, summed. A missing suit contributes nothing.
    public static func primiera(of cards: [Card]) -> Int {
        primieraCards(of: cards).reduce(0) { $0 + primieraValue($1.rank) }
    }

    /// The best card in each suit, best first.
    public static func primieraCards(of cards: [Card]) -> [Card] {
        Suit.allCases
            .compactMap { suit in cards.filter { $0.suit == suit }.max { primieraValue($0.rank) < primieraValue($1.rank) } }
            .sorted { primieraValue($0.rank) > primieraValue($1.rank) }
    }

    /// Scores a round. Defaults to the rulebook; a table passes its own rules.
    public static func score(captures: [[Card]], scope: [Int], primiera rule: PrimieraRule = .classic,
                             ties: TieRule = .classic) -> RoundScore {
        var sheet = Sheet(points: scope, ties: ties)
        sheet.award(.cards, captures.map(\.count))
        sheet.award(.coins, captures.map { $0.count { $0.suit == .coins } })
        sheet.award(.settebello, captures.map { $0.contains(.settebello) ? 1 : 0 })
        let primieraCards: [[Card]]
        switch rule {
        case .classic:
            sheet.award(.primiera, captures.map(primiera))
            primieraCards = captures.map(Self.primieraCards)
        case .mostSevens:
            let sevens = captures.map { $0.filter { $0.rank == .seven } }
            sheet.award(.primiera, sevens.map(\.count))
            primieraCards = sevens
        }
        return RoundScore(points: sheet.points, categoryWinners: sheet.winners, scope: scope,
                          tallies: sheet.tallies, primieraCards: primieraCards, categoryPoints: sheet.awarded)
    }

    /// The running bookkeeping while a round is scored, one category at a time.
    private struct Sheet {
        var points: [Int]
        let ties: TieRule
        var winners: [ScoreCategory: Int?] = [:]
        var tallies: [ScoreCategory: [Int]] = [:]
        var awarded: [ScoreCategory: [Int]] = [:]

        mutating func award(_ category: ScoreCategory, _ values: [Int]) {
            let top = leaders(values)
            winners[category] = top.count == 1 ? top[0] : nil
            tallies[category] = values
            // One clear winner takes the point. Several level at the top take one each only under shared ties.
            var take = [Int](repeating: 0, count: values.count)
            if top.count == 1 || ties == .shared {
                for side in top {
                    take[side] = 1
                    points[side] += 1
                }
            }
            awarded[category] = take
        }
    }

    /// Index of the strictly largest value, or nil when the top is shared or all zero.
    static func uniqueMax(_ values: [Int]) -> Int? {
        let top = leaders(values)
        return top.count == 1 ? top[0] : nil
    }

    /// Every side holding the largest value. Empty when nobody scored at all.
    static func leaders(_ values: [Int]) -> [Int] {
        guard let best = values.max(), best > 0 else { return [] }
        return values.indices.filter { values[$0] == best }
    }
}
