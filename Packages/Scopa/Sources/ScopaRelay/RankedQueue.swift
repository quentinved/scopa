import Foundation
import ScopaCore

/// The ranked queue on the Worker: one line for every ranked search, paired as soon as two
/// players are in it, and seated at a room both phones join. See `Server/src/queue.ts`.
///
/// A duo searches as one: the inviting phone seeks with its teammate named, and the teammate's
/// phone follows that search. Pairs only meet pairs, at a room for four.
public struct RankedQueue: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Where two paired players sit.
    public struct Pairing: Sendable, Hashable, Decodable {
        public let code: String
        /// The player id that deals.
        public let host: String
        /// "1v1", "2v2" or "duo": the host's choice, which both phones play.
        public let format: String
        public let opponent: String
        /// A duo's whole other side, their leader first. Nil for a solo pairing.
        public let opponents: [String]?
    }

    public struct Answer: Sendable, Hashable, Decodable {
        /// Others waiting who could be paired with this search: pairs for a duo.
        public let searching: Int
        public let pairing: Pairing?
        /// For a follow: whether the leader is in the line with this phone. Nil for a seek.
        public let inLine: Bool?
    }

    /// One poll. The app asks again about every 1.5 s while it searches. `search` is the same
    /// for every poll of one search, so a new search never inherits the last one's pairing.
    /// A duo's leader names its `teammate`, whose phone then follows this search.
    public func seek(as player: Player, format: String, search: String, teammate: Player? = nil) async throws -> Answer {
        struct Body: Encodable {
            let player: String
            let name: String
            let format: String
            let search: String
            let teammate: String?
            let teammateName: String?
        }
        return try await post("v1/ranked/queue", Body(player: player.id.rawValue, name: player.name, format: format,
                                                      search: search, teammate: teammate?.id.rawValue,
                                                      teammateName: teammate?.name))
    }

    /// One poll from a duo's second phone: its leader's search, and the pairing once the leader
    /// has heard of it. This phone is never in the line itself.
    public func follow(as player: Player, leader: PlayerID) async throws -> Answer {
        struct Body: Encodable {
            let player: String
            let leader: String
        }
        return try await post("v1/ranked/queue/follow", Body(player: player.id.rawValue, leader: leader.rawValue))
    }

    /// Takes the player out of the line. Best effort: a phone that stops asking drops out anyway.
    public func leave(as player: Player) async {
        struct Body: Encodable { let player: String }
        struct Ok: Decodable {}
        let _: Ok? = try? await post("v1/ranked/queue/leave", Body(player: player.id.rawValue))
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, _ body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RelayError.unreachable("The ranked queue is not answering")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
