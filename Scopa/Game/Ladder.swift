import Foundation
import ScopaGameCenter
import ScopaProfile
import ScopaRewards

/// The shared boards on the Worker in `Server/`: daily deal, weekly challenge and ranked.
/// With no `baseURL` nothing is sent and the lobby shows the phone's own numbers.
///
/// Every post carries a Game Center signature, so the Worker records a result only for the
/// player who made it. Not being signed in is not an error, the result just stays local.
enum Ladder {
    /// The deployed Worker. Nil turns the ladder off.
    static let baseURL: URL? = URL(string: "https://scopa-ladder.quentin-vedrenne.workers.dev")

    static var isOn: Bool { baseURL != nil }

    /// Where a player stands on a day, as the Worker tells it.
    struct Standing: Codable, Hashable {
        let day: String
        /// How many played that day.
        let played: Int
        let rank: Int?
        let percentile: Int?
    }

    private struct DailyPost: Encodable {
        let day: String
        let mine: Int
        let theirs: Int
        let scope: Int
        let accuracy: Int?
        let identity: GameCenterIdentity
    }

    /// Posts a day's result and returns where it placed. Nil when the ladder is off or the
    /// player is not signed in. Throws only on a network or server failure.
    static func post(_ result: DailyDealResult) async throws -> Standing? {
        try await signedPost("v1/daily") {
            DailyPost(day: result.day, mine: result.mine, theirs: result.theirs,
                      scope: result.scope, accuracy: result.accuracy, identity: $0)
        }
    }

    // MARK: The weekly challenge

    /// Where one player stands on a week, as the Worker tells it.
    struct WeeklyStanding: Codable, Hashable {
        let week: String
        /// How many have posted anything at all this week.
        let played: Int
        let rank: Int?
        let count: Int
        let goal: Int
        let finished: Bool
    }

    /// A week's board, ranked by how far past the goal people got rather than by who finished.
    struct WeeklyBoard: Codable, Hashable {
        struct Row: Codable, Hashable, Identifiable {
            let id: String
            let name: String
            let count: Int
            let goal: Int
            let finished: Bool

            /// Read leniently, and only here. The ladder keeps `finished` in SQLite, which
            /// has no booleans, so a row that reaches the wire unconverted carries 1 rather
            /// than true — and a decoder that refuses it does not lose the row, it loses the
            /// whole board. The Worker sends a flag; this is what makes sure of it.
            init(from decoder: any Decoder) throws {
                let row = try decoder.container(keyedBy: CodingKeys.self)
                id = try row.decode(String.self, forKey: .id)
                name = try row.decode(String.self, forKey: .name)
                count = try row.decode(Int.self, forKey: .count)
                goal = try row.decode(Int.self, forKey: .goal)
                if let flag = try? row.decode(Bool.self, forKey: .finished) {
                    finished = flag
                } else {
                    finished = (try? row.decode(Int.self, forKey: .finished)).map { $0 != 0 } ?? false
                }
            }
        }

        let week: String
        let top: [Row]
        let you: WeeklyStanding?

        var isEmpty: Bool { top.isEmpty }
    }

    private struct WeeklyPost: Encodable {
        let week: String
        let count: Int
        let goal: Int
        let identity: GameCenterIdentity
    }

    /// Tells the ladder how the week is going, sent as it goes rather than at the end. The
    /// Worker clamps upwards, so a phone that was offline can post a stale count safely.
    @discardableResult
    static func postWeekly(week: String, count: Int, goal: Int) async throws -> WeeklyStanding? {
        try await signedPost("v1/weekly") { WeeklyPost(week: week, count: count, goal: goal, identity: $0) }
    }

    /// The week's board in full.
    static func weeklyBoard(week: String, gamePlayerID: String?) async throws -> WeeklyBoard? {
        guard let baseURL else { return nil }
        var url = baseURL.appending(path: "v1/weekly/\(week)")
        if let gamePlayerID {
            url.append(queryItems: [URLQueryItem(name: "player", value: gamePlayerID)])
        }
        return try await get(url)
    }

    // MARK: Ranked

    /// A player's league, as the Worker tells it.
    struct RankAnswer: Codable, Hashable {
        struct Standing: Codable, Hashable {
            let league: Int
            let division: Int
            let progress: Int
            let step: Int
            let title: String
        }
        /// The day's allowance of ranked games against the house, and what one is worth.
        struct House: Codable, Hashable {
            let playedToday: Int
            let perDay: Int
            let win: Int
            let loss: Int

            /// Whether the next house game will still move the ladder.
            var isCounting: Bool { playedToday < perDay }
        }

        /// A season this player finished and has not been paid for yet.
        struct Finish: Codable, Hashable {
            let season: String
            let rating: Int
            let games: Int
            let wins: Int
            let standing: Standing
        }

        let rating: Int
        let games: Int
        let wins: Int
        let standing: Standing
        /// What the most recent settled game did to the rating, if any.
        let lastChange: Int?
        /// Ranked wins standing in a row. Read before a game it is the run the next win is
        /// paid on, read after one it is the run that win just made. Optional because a
        /// Worker deployed before runs answers without it.
        var streak: Int? = nil
        /// Which game that change came from, so a phone waiting on its last game can tell this
        /// answer from the answer to the game before it.
        var lastGameID: String? = nil
        /// Who the Worker answered for. An answer about the wrong player and an answer about a
        /// player who has never played both read as zero without this.
        var playerID: String? = nil
        /// How the day's allowance of house games stands, and what one is worth.
        var house: House? = nil
        /// The season the rating belongs to, "2026-09". Optional because a Worker deployed
        /// before seasons answers without it.
        var season: String? = nil
        /// Kept as the Worker wrote it: an ISO instant with fractional seconds, which
        /// `JSONDecoder`'s own `.iso8601` strategy refuses. `seasonEnds` parses it.
        var seasonEndsAt: String? = nil
        /// Last season, waiting to be handed over. Nil once it has been.
        var finish: Finish? = nil

        /// When this season gives way to the next one.
        var seasonEnds: Date? {
            guard let seasonEndsAt else { return nil }
            let reader = ISO8601DateFormatter()
            reader.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return reader.date(from: seasonEndsAt) ?? ISO8601DateFormatter().date(from: seasonEndsAt)
        }

        /// Whole days left in the season. Nil on a Worker deployed without seasons.
        var daysLeftInSeason: Int? {
            guard let seasonEnds else { return nil }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: seasonEnds).day ?? 0
            return max(days, 0)
        }
    }

    private struct HousePost: Encodable {
        let gameID: String
        let won: Bool
        let identity: GameCenterIdentity
    }

    /// Reports a ranked game against the house, which no second phone can confirm. The Worker
    /// takes it on trust and pays a win in full, for the first few of the day only.
    static func postHouseGame(gameID: UUID, won: Bool) async throws -> RankAnswer? {
        try await signedPost("v1/ranked/house") { HousePost(gameID: gameID.uuidString, won: won, identity: $0) }
    }

    private struct ClaimPost: Encodable {
        let season: String
        let identity: GameCenterIdentity
    }

    /// Tells the ladder a finished season has been paid for, so no other phone pays it twice.
    /// The denari are granted on this phone, the Worker only records the claim.
    static func claimSeason(_ season: String) async throws -> RankAnswer? {
        try await signedPost("v1/ranked/claim") { ClaimPost(season: season, identity: $0) }
    }

    private struct RankedPost: Encodable {
        let gameID: String
        let players: [String]
        /// The first winner, for a Worker that predates sides.
        let winnerID: String
        /// Everyone on the winning side: one player solo, two in a duo.
        let winnerIDs: [String]
        let identity: GameCenterIdentity
    }

    /// Reports a finished ranked game. Every phone at the table reports, and the Worker applies
    /// the result once they agree. Returns the reporter's league afterwards.
    static func postRanked(gameID: UUID, players: [String], winnerIDs: [String]) async throws -> RankAnswer? {
        guard let first = winnerIDs.first else { return nil }
        return try await signedPost("v1/ranked") {
            RankedPost(gameID: gameID.uuidString, players: players, winnerID: first,
                       winnerIDs: winnerIDs, identity: $0)
        }
    }

    /// Where the ladder keeps one player's league.
    ///
    /// The path is built by hand because a Game Center id contains a colon that must be escaped
    /// exactly once. `appending(path:)` escapes whatever it is handed, so an already-escaped id
    /// went on the wire as "%253A" and the Worker looked up a player who has never existed.
    private static func rankURL(for gamePlayerID: String) -> URL? {
        guard let baseURL, var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encoded = gamePlayerID.addingPercentEncoding(withAllowedCharacters: unreserved) ?? gamePlayerID
        var path = components.percentEncodedPath
        if path.hasSuffix("/") { path.removeLast() }
        components.percentEncodedPath = path + "/v1/players/\(encoded)/rank"
        return components.url
    }

    static func rank(gamePlayerID: String) async throws -> RankAnswer? {
        guard let url = rankURL(for: gamePlayerID) else { return nil }
        let answer: RankAnswer = try await get(url)
        // An answer about another player is true but useless here, and would show a ranked
        // lobby as unranked. Drop it.
        guard answer.playerID == nil || answer.playerID == gamePlayerID else { return nil }
        return answer
    }

    struct Best: Codable, Hashable {
        let day: String
        let name: String
        let margin: Int
    }

    /// A whole day's ladder.
    struct Board: Codable, Hashable {
        /// One player's day. `id` is the bare Game Center id, so the reader's own row can be
        /// picked out and marked.
        struct Row: Codable, Hashable, Identifiable {
            let id: String
            let name: String
            let margin: Int
            let mine: Int
            let theirs: Int
            let scope: Int
            let accuracy: Int?
        }

        let day: String
        let top: [Row]
        /// Where the reader placed. The rank can be past the end of `top`, which stops at fifty.
        let you: Standing?

        var isEmpty: Bool { top.isEmpty }
    }

    /// The day's ladder in full. Without a `gamePlayerID` the board still comes back, it just
    /// cannot mark the reader's own row.
    static func board(day: String, gamePlayerID: String?) async throws -> Board? {
        guard let baseURL else { return nil }
        var url = baseURL.appending(path: "v1/daily/\(day)")
        if let gamePlayerID {
            url.append(queryItems: [URLQueryItem(name: "player", value: gamePlayerID)])
        }
        return try await get(url)
    }

    /// Who won a day and by how much. Nil when nobody played it.
    static func best(day: String) async throws -> Best? {
        guard let baseURL else { return nil }
        let (data, _) = try await URLSession.shared.data(from: baseURL.appending(path: "v1/daily/\(day)"))
        struct Row: Decodable { let name: String; let margin: Int }
        struct Answer: Decodable { let top: [Row] }
        guard let first = try JSONDecoder().decode(Answer.self, from: data).top.first else { return nil }
        return Best(day: day, name: first.name, margin: first.margin)
    }

    /// Where a player stands on a day, without posting anything.
    static func standing(day: String, gamePlayerID: String) async throws -> Standing? {
        guard let baseURL else { return nil }
        var url = baseURL.appending(path: "v1/daily/\(day)")
        url.append(queryItems: [URLQueryItem(name: "player", value: gamePlayerID)])
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Answer: Decodable { let you: Standing? }
        return try JSONDecoder().decode(Answer.self, from: data).you
    }

    // MARK: Talking to the Worker

    /// POSTs a signed body and decodes the answer. Nil when the ladder is switched off or
    /// nobody is signed in, which is how every signed call opts out.
    private static func signedPost<Body: Encodable, Answer: Decodable>(
        _ path: String, body: (GameCenterIdentity) -> Body
    ) async throws -> Answer? {
        guard let baseURL, GameCenter.isSignedIn else { return nil }
        let identity = try await GameCenter.identity()
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body(identity))
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return try JSONDecoder().decode(Answer.self, from: data)
    }

    /// GETs and decodes, throwing on anything but a 2xx.
    private static func get<Answer: Decodable>(_ url: URL) async throws -> Answer {
        let (data, response) = try await URLSession.shared.data(from: url)
        try check(response)
        return try JSONDecoder().decode(Answer.self, from: data)
    }

    private static func check(_ response: URLResponse) throws {
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - The account

/// The player's account on the Worker: what makes a phone and an iPad the same player.
///
/// Its own coders, because both the profile and the ledger carry dates and the Worker keeps
/// them as ISO strings — the ledger file on disk is written the same way, and for the same
/// reason. `JSONDecoder`'s default would read Apple's reference-date doubles and get 2001.
extension Ladder {
    /// How many ledger entries go in one call. The Worker's own ceiling; a device back from
    /// a long spell offline sends several calls rather than one enormous one.
    static let ledgerBatch = 500

    /// One player's account as the Worker holds it.
    struct Account: Decodable {
        /// The revision the profile is at. A write names the one it was built from.
        let rev: Int
        /// Nil when this player has never synced from any device.
        let profile: Profile?
        /// What the ledger has gained since `since` was last read.
        let ledger: [LedgerEntry]
        /// Where to read on from next time.
        let since: Int
        /// Whether there is more waiting than one answer carries.
        let more: Bool
    }

    enum AccountWrite {
        case written(Account)
        /// Another device wrote between the read and the write. What comes back is what to
        /// merge with before trying again.
        case stale(Account)
    }

    /// The account as it stands, and the ledger from `since` on. Nil when the ladder is off
    /// or nobody is signed in, which is how a device opts out of having an account at all.
    static func readAccount(since: Int) async throws -> Account? {
        struct Read: Encodable {
            let since: Int
            let identity: GameCenterIdentity
        }
        guard let request = try await accountRequest("v1/profile/read", body: { Read(since: since, identity: $0) })
        else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return try accountDecoder.decode(Account.self, from: data)
    }

    /// Hands this device's copy over. A nil `profile` writes only the ledger, which cannot
    /// conflict and so is never refused.
    static func writeAccount(rev: Int, profile: Profile?, ledger: [LedgerEntry], since: Int) async throws -> AccountWrite? {
        struct Post: Encodable {
            /// The entry and the key it dedupes by, side by side, so the Worker can union a
            /// ledger without knowing what one is.
            struct Entry: Encodable {
                let key: String
                let entry: LedgerEntry
            }

            let rev: Int
            let profile: Profile?
            let ledger: [Entry]
            let since: Int
            let identity: GameCenterIdentity
        }
        let entries = ledger.map { Post.Entry(key: $0.key, entry: $0) }
        guard let request = try await accountRequest("v1/profile/write", body: {
            Post(rev: rev, profile: profile, ledger: entries, since: since, identity: $0)
        }) else { return nil }
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        // 409 is not a failure. It is the Worker saying the other device got there first,
        // and handing over everything needed to merge again.
        guard code == 409 else {
            try check(response)
            return .written(try accountDecoder.decode(Account.self, from: data))
        }
        return .stale(try accountDecoder.decode(Account.self, from: data))
    }

    /// A signed POST, built but not sent. Nil when there is nobody to sign for it.
    private static func accountRequest<Body: Encodable>(
        _ path: String, body: (GameCenterIdentity) -> Body
    ) async throws -> URLRequest? {
        guard let baseURL, GameCenter.isSignedIn else { return nil }
        let identity = try await GameCenter.identity()
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try accountEncoder.encode(body(identity))
        return request
    }

    private static var accountEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var accountDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Friends online

/// The heartbeat behind "Marco is on Scopa". See `FriendsOnline`, and `Server/src/presence.ts`
/// for why being seen is mutual.
extension Ladder {
    struct OnlineFriend: Decodable, Hashable {
        /// Their `gamePlayerID`.
        let id: String
        /// Their Game Center name, as the Worker last heard it.
        let name: String
    }

    struct Presence: Decodable {
        let online: [OnlineFriend]
        /// How long to wait before the next beat, in seconds.
        let every: Int
    }

    /// Says this player is here, naming their friends, and hears which of them are too.
    /// Signed with an identity the caller keeps: a beat a minute should not ask Game
    /// Center for a fresh signature every time, and one lasts the Worker an hour.
    static func beat(friends: [String], identity: GameCenterIdentity) async throws -> Presence? {
        struct Post: Encodable {
            let friends: [String]
            let identity: GameCenterIdentity
        }
        return try await presencePost("v1/presence", body: Post(friends: friends, identity: identity))
    }

    /// Off every friend's list now, rather than when the last beat runs out.
    static func leavePresence(identity: GameCenterIdentity) async throws {
        struct Post: Encodable { let identity: GameCenterIdentity }
        struct Done: Decodable {}
        let _: Done? = try await presencePost("v1/presence/leave", body: Post(identity: identity))
    }

    private static func presencePost<Body: Encodable, Answer: Decodable>(_ path: String, body: Body) async throws -> Answer? {
        guard let baseURL else { return nil }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return try JSONDecoder().decode(Answer.self, from: data)
    }
}
