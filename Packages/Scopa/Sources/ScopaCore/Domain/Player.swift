public struct PlayerID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct Player: Hashable, Sendable, Identifiable {
    public let id: PlayerID
    public var name: String
    /// Played by the machine rather than a person.
    public var isBot: Bool
    /// The mark on their seat, seen by everyone. The app names it, the core only carries it. Nil is the first letter of the name.
    public var mark: String?
    /// The id of the friend who invited them to a duo. The host seats partners opposite each other.
    public var partner: String?
    /// The week whose challenge they finished, while they are still entitled to wear it. Carried like `mark`.
    public var honour: String?
    /// What is drawn around their seat mark. Carried like `mark`.
    public var cornice: String?
    /// The animal sitting by their hand. Carried like `mark`.
    public var companion: String?
    /// The colour their seat mark is struck in. Carried like `mark`; nil is the colour of
    /// whichever chair the table sat them in.
    public var livery: String?

    public init(id: PlayerID, name: String, isBot: Bool = false, mark: String? = nil,
                partner: String? = nil, honour: String? = nil, cornice: String? = nil,
                companion: String? = nil, livery: String? = nil) {
        self.id = id
        self.name = name
        self.isBot = isBot
        self.mark = mark
        self.partner = partner
        self.honour = honour
        self.cornice = cornice
        self.companion = companion
        self.livery = livery
    }
}

/// Written by hand so a player sent by an older build, with no `isBot`, still decodes.
extension Player: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, isBot, mark, partner, honour, cornice, companion, livery }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PlayerID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
        mark = try container.decodeIfPresent(String.self, forKey: .mark)
        partner = try container.decodeIfPresent(String.self, forKey: .partner)
        honour = try container.decodeIfPresent(String.self, forKey: .honour)
        cornice = try container.decodeIfPresent(String.self, forKey: .cornice)
        companion = try container.decodeIfPresent(String.self, forKey: .companion)
        livery = try container.decodeIfPresent(String.self, forKey: .livery)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if isBot { try container.encode(isBot, forKey: .isBot) }
        try container.encodeIfPresent(mark, forKey: .mark)
        try container.encodeIfPresent(partner, forKey: .partner)
        try container.encodeIfPresent(honour, forKey: .honour)
        try container.encodeIfPresent(cornice, forKey: .cornice)
        try container.encodeIfPresent(companion, forKey: .companion)
        try container.encodeIfPresent(livery, forKey: .livery)
    }
}

/// Fixed setup for one game. Seats are the order of `players`; play proceeds seat by seat.
public struct GameConfiguration: Hashable, Codable, Sendable {
    public static let handSize = 3
    public static let tableSize = 4
    public static let playerRange = 2...4
    /// What the host may set the winning score to. Eleven is the classic game.
    public static let targetRange = 5...51

    public let players: [Player]
    /// With four players, partners sit opposite each other and score as one side.
    public let teams: Bool
    public let targetScore: Int
    public let turnClock: TurnClock
    public let primiera: PrimieraRule
    public let ties: TieRule

    public init(players: [Player], teams: Bool = false, targetScore: Int = 11, turnClock: TurnClock = .default,
                primiera: PrimieraRule = .default, ties: TieRule = .default) throws(ConfigurationError) {
        guard Self.playerRange.contains(players.count) else { throw .playerCount(players.count) }
        guard !teams || players.count == 4 else { throw .teamsRequireFourPlayers }
        guard targetScore > 0 else { throw .invalidTargetScore }
        self.players = players
        self.teams = teams
        self.targetScore = targetScore
        self.turnClock = turnClock
        self.primiera = primiera
        self.ties = ties
    }

    private enum CodingKeys: String, CodingKey { case players, teams, targetScore, turnClock, primiera, ties }

    /// By hand, so a table set up by a build that had no primiera or tie rule still decodes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        teams = try container.decode(Bool.self, forKey: .teams)
        targetScore = try container.decode(Int.self, forKey: .targetScore)
        turnClock = try container.decodeIfPresent(TurnClock.self, forKey: .turnClock) ?? .default
        primiera = try container.decodeIfPresent(PrimieraRule.self, forKey: .primiera) ?? .default
        ties = try container.decodeIfPresent(TieRule.self, forKey: .ties) ?? .default
    }

    public var seatCount: Int { players.count }
    public var sideCount: Int { teams ? 2 : players.count }

    /// The scoring side a seat belongs to.
    public func side(ofSeat seat: Int) -> Int { teams ? seat % 2 : seat }

    public func seat(of player: PlayerID) -> Int? { players.firstIndex { $0.id == player } }

    public func nextSeat(after seat: Int) -> Int { (seat + 1) % seatCount }
}

public enum ConfigurationError: Error, Equatable, Sendable {
    case playerCount(Int)
    case teamsRequireFourPlayers
    case invalidTargetScore
}
