import Foundation

/// One finished game as the record keeps it: who sat where, how it ended, and what you did
/// in it. Written once, when the last summary appears, and never changed after.
public struct LoggedGame: Hashable, Codable, Sendable, Identifiable {
    /// Which door the game came through. Stored by name, so a table added later reads back
    /// on an older build as a game rather than failing the whole log.
    public enum Table: String, Codable, Sendable {
        case quick, campaign, daily, wager
        /// Rated against people, and rated against the house.
        case ranked, rankedHouse
        /// Phones in one room, Game Center, and a table opened by its four letters.
        case nearby, online, room
        case passThePhone

        public init(from decoder: any Decoder) throws {
            self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .quick
        }
    }

    /// The four ways the page groups tables, where the split says something. A key the
    /// totals are filed under, so it is written as its name rather than as a pair.
    public enum Group: String, Codable, Sendable, CaseIterable, CodingKeyRepresentable {
        case ranked, campaign, people, bots
    }

    public struct Seat: Hashable, Codable, Sendable {
        public let name: String
        public let isBot: Bool
        /// The same from one game to the next where the table has one: the Game Center id
        /// online, the device's own id over Wi-Fi. Nil on a phone passed round, whose chairs
        /// are numbered rather than anybody's, and for a bot.
        public let playerID: String?
        public let side: Int
        public let isYou: Bool

        public init(name: String, isBot: Bool, playerID: String? = nil, side: Int, isYou: Bool = false) {
            self.name = name
            self.isBot = isBot
            self.playerID = playerID
            self.side = side
            self.isYou = isYou
        }
    }

    /// The tally's game id, which is what keeps a summary drawn twice one game.
    public let id: UUID
    public let date: Date
    public let table: Table
    public let seats: [Seat]
    public let teams: Bool
    /// The final points, by side.
    public let scores: [Int]
    public let yourSide: Int
    /// The side that won. Your own when `won` is true.
    public let winner: Int?
    public let won: Bool
    public let scope: Int
    public let settebelli: Int
    public let cappotti: Int
    /// Rounds whose primiera you took outright. Nil for a game whose earlier rounds were
    /// tallied before it was counted.
    public let primiere: Int?

    public init(id: UUID, date: Date, table: Table, seats: [Seat], teams: Bool, scores: [Int],
                yourSide: Int, winner: Int?, won: Bool, scope: Int = 0, settebelli: Int = 0,
                cappotti: Int = 0, primiere: Int? = nil) {
        self.id = id
        self.date = date
        self.table = table
        self.seats = seats
        self.teams = teams
        self.scores = scores
        self.yourSide = yourSide
        self.winner = winner
        self.won = won
        self.scope = scope
        self.settebelli = settebelli
        self.cappotti = cappotti
        self.primiere = primiere
    }
}

public extension LoggedGame {
    /// Whether anybody but you was a person.
    var hadPeople: Bool { seats.contains { !$0.isYou && !$0.isBot } }

    var group: Group {
        switch table {
        case .ranked, .rankedHouse: .ranked
        case .campaign: .campaign
        default: hadPeople ? .people : .bots
        }
    }

    /// Everyone across the table.
    var opponents: [Seat] { seats.filter { $0.side != yourSide } }

    /// Your points, and the best of everybody else's.
    var mine: Int { scores[safe: yourSide] ?? 0 }
    var theirs: Int { scores.indices.filter { $0 != yourSide }.map { scores[$0] }.max() ?? 0 }
    var margin: Int { mine - theirs }

    /// How the game went between you and one seat across the table: true for you, false
    /// for them, nil where neither of you won and the points came out level.
    ///
    /// Two sides is simply the game. At three or four, the winner beat everybody, and
    /// between two who did not win the points decide.
    func result(against seat: Seat) -> Bool? {
        guard seat.side != yourSide else { return nil }
        if won { return true }
        if scores.count <= 2 || winner == seat.side { return false }
        let theirs = scores[safe: seat.side] ?? 0
        return mine == theirs ? nil : mine > theirs
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
