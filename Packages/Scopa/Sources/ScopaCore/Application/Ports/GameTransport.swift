/// Everything that crosses the wire between host and guests. Adapters (Multipeer, later a server) only carry these.
public enum GameMessage: Hashable, Codable, Sendable {
    // Guest -> host
    case join(Player)
    case leave(PlayerID)
    case play(Move)
    case react(Reaction)

    // Host -> guests
    case lobby(Lobby)
    case joinRefused
    case view(PlayerView)
    case events([GameEvent])
    case rejected(MoveError)
    case playerLeft(PlayerID)
    case reacted(player: PlayerID, reaction: Reaction)
    /// The whole game, once it has ended, so every device can read it back.
    case record(GameRecord)
}

/// A small fixed set of things to say without typing. Sent to everyone at the table.
public enum Reaction: String, CaseIterable, Codable, Sendable, Hashable {
    /// The five everybody has.
    case bravo, ouch, thinking, laugh, cheers
    /// Osteria: the things said across a table with a bottle on it.
    case mamma, perfetto, sleepy, fortuna
    /// Sfida: the things said when it stops being friendly.
    case fire, respect, no, clever
    /// Nonna: the things said by whoever taught you to play.
    case careful, taught, patience, told

    /// The five that need no buying. The rest arrive with a pack, and only the shop knows
    /// which: the rules have no idea what anything costs.
    public static let free: [Reaction] = [.bravo, .ouch, .thinking, .laugh, .cheers]

    public var emoji: String {
        switch self {
        case .bravo: "👏"
        case .ouch: "😩"
        case .thinking: "🤔"
        case .laugh: "😂"
        case .cheers: "🍷"
        case .mamma: "🤌"
        case .perfetto: "👌"
        case .sleepy: "😴"
        case .fortuna: "🍀"
        case .fire: "🔥"
        case .respect: "🫡"
        case .no: "😱"
        case .clever: "🧠"
        case .careful: "👀"
        case .taught: "📖"
        case .patience: "🫖"
        case .told: "☝️"
        }
    }

    public var label: String {
        switch self {
        case .bravo: "Bravo"
        case .ouch: "Ouch"
        case .thinking: "Thinking"
        case .laugh: "Ha!"
        case .cheers: "Cin cin"
        case .mamma: "Mamma mia"
        case .perfetto: "Perfetto"
        case .sleepy: "Any day now"
        case .fortuna: "Fortuna"
        case .fire: "On fire"
        case .respect: "Respect"
        case .no: "No!"
        case .clever: "Clever"
        case .careful: "Careful now"
        case .taught: "Nonna taught me"
        case .patience: "Patience"
        case .told: "I told you so"
        }
    }

    /// A reaction this build has never heard of is read as a shrug rather than thrown.
    ///
    /// The two phones at a table are not always the same build, and a reaction is the one
    /// message where being slightly wrong costs nothing. Refusing to decode it would take
    /// the whole envelope down, and the game with it.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Reaction(rawValue: raw) ?? .thinking
    }
}

/// One message plus its sender. What every transport delivers.
public struct Envelope: Hashable, Codable, Sendable {
    public let from: PlayerID
    public let message: GameMessage

    public init(from: PlayerID, message: GameMessage) {
        self.from = from
        self.message = message
    }
}

public struct Lobby: Hashable, Codable, Sendable {
    public var host: Player
    /// Seat order. The host is always first.
    public var players: [Player]
    public var teams: Bool
    public var turnClock: TurnClock
    public var targetScore: Int
    public var primiera: PrimieraRule
    public var ties: TieRule
    /// The name this game goes by on the ladder. Set by the host, read by every guest, so
    /// every phone at a ranked table reports the same game rather than four of its own.
    public var gameID: String?

    public init(host: Player, players: [Player]? = nil, teams: Bool = false, turnClock: TurnClock = .default,
                targetScore: Int = 11, primiera: PrimieraRule = .default, ties: TieRule = .default,
                gameID: String? = nil) {
        self.host = host
        self.players = players ?? [host]
        self.teams = teams
        self.turnClock = turnClock
        self.targetScore = targetScore
        self.primiera = primiera
        self.ties = ties
        self.gameID = gameID
    }

    private enum CodingKeys: String, CodingKey {
        case host, players, teams, turnClock, targetScore, primiera, ties, gameID
    }

    /// By hand, so a lobby from a build that had no primiera or tie rule still decodes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(Player.self, forKey: .host)
        players = try container.decode([Player].self, forKey: .players)
        teams = try container.decode(Bool.self, forKey: .teams)
        turnClock = try container.decodeIfPresent(TurnClock.self, forKey: .turnClock) ?? .default
        targetScore = try container.decodeIfPresent(Int.self, forKey: .targetScore) ?? 11
        primiera = try container.decodeIfPresent(PrimieraRule.self, forKey: .primiera) ?? .default
        ties = try container.decodeIfPresent(TieRule.self, forKey: .ties) ?? .default
        gameID = try container.decodeIfPresent(String.self, forKey: .gameID)
    }

    public var isFull: Bool { players.count >= GameConfiguration.playerRange.upperBound }
    public var canStart: Bool { GameConfiguration.playerRange.contains(players.count) && (!teams || players.count == 4) }
}

public enum Recipient: Hashable, Sendable {
    case player(PlayerID)
    case host
    case all
}

public enum TransportError: Error, Sendable {
    case notConnected
    case peerNotFound
    case joinFailed
}

/// Port: how messages reach other devices. Implemented by an adapter, never by the core.
public protocol GameTransport: Sendable {
    var localPlayer: Player { get }
    /// Consumed once, by the coordinator or client that owns this transport.
    var incoming: AsyncStream<Envelope> { get }
    func send(_ message: GameMessage, to recipient: Recipient) async throws
}

/// A table another device is hosting nearby.
public struct NearbyTable: Hashable, Sendable, Identifiable {
    public let id: String
    public let hostName: String
    public let seated: Int
    public let capacity: Int

    public init(id: String, hostName: String, seated: Int, capacity: Int) {
        self.id = id
        self.hostName = hostName
        self.seated = seated
        self.capacity = capacity
    }
}

/// Port, host side: make the table visible to nearby devices.
public protocol TableAdvertising: Sendable {
    func advertise(_ lobby: Lobby)
    func stopAdvertising()
}

/// Port, guest side: find tables and connect to one.
public protocol TableBrowsing: Sendable {
    var nearbyTables: AsyncStream<[NearbyTable]> { get }
    func startBrowsing()
    func stopBrowsing()
    /// Returns once connected to the host, or throws.
    func join(_ table: NearbyTable) async throws
}
