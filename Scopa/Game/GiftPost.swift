import Foundation
import ScopaCore
import ScopaGameCenter
import ScopaRewards

/// A spare card on its way to a friend, and the ones on their way here. See
/// `Server/src/gifts.ts`.
///
/// Signed with Game Center both ways: the Worker takes a card only from the player whose
/// album it left, and hands one over only to the friend it is for.
enum GiftPost {
    /// One card for a friend, named before it is sent so a retry is the same gift.
    struct Outgoing: Codable, Equatable {
        var id = UUID().uuidString.lowercased()
        let to: String
        /// The friend's Game Center name, for the thank-you.
        let name: String
        let card: Card
        let volume: Volume
        /// The sender's own day, which is what one a day counts by.
        let day: String
    }

    /// One card waiting for this player.
    struct Waiting: Decodable, Equatable {
        let id: String
        /// The sender's Game Center name, as the Worker heard it.
        let from: String
        let card: String

        var playingCard: Card? { Deck.standard.first { $0.description == card } }
    }

    enum Sent: Equatable {
        case sent
        case oneADay
        /// The friend has never been signed in to Scopa, so there is nowhere to put it.
        case unknownFriend
        /// The Worker answering does not know about gifts yet.
        case notOpen
        case notSignedIn
        case offline
        case unreachable
        /// Something the Worker would never take, such as a day too far off.
        case refused
    }

    /// Whether the Worker takes gifts at all. Nil when it could not be asked.
    static func isOpen() async -> Bool? {
        guard let baseURL = Ladder.baseURL else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: baseURL.appending(path: "v1/gifts"))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return nil
        }
    }

    static func send(_ gift: Outgoing) async -> Sent {
        guard let baseURL = Ladder.baseURL else { return .notOpen }
        guard GameCenter.isSignedIn else { return .notSignedIn }
        struct Post: Encodable {
            let id, to, card, day: String
            let identity: GameCenterIdentity
        }
        do {
            let post = Post(id: gift.id, to: gift.to, card: gift.card.description, day: gift.day,
                            identity: try await GameCenter.identity())
            let (data, status) = try await call(baseURL.appending(path: "v1/gifts/send"), post)
            return sent(status: status, data: data)
        } catch is URLError {
            return .offline
        } catch {
            return .unreachable
        }
    }

    /// Hands back the ids this phone now has, and answers with what is still waiting.
    static func collect(taken: [String]) async throws -> [Waiting] {
        guard let baseURL = Ladder.baseURL, GameCenter.isSignedIn else { return [] }
        struct Post: Encodable {
            let taken: [String]
            let identity: GameCenterIdentity
        }
        struct Answer: Decodable { let gifts: [Waiting] }
        let post = Post(taken: taken, identity: try await GameCenter.identity())
        let (data, status) = try await call(baseURL.appending(path: "v1/gifts/collect"), post)
        guard status == 200 else { return [] }
        return try JSONDecoder().decode(Answer.self, from: data).gifts
    }

    private static func call(_ url: URL, _ body: some Encodable) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func sent(status: Int, data: Data) -> Sent {
        struct Refusal: Decodable { let error: String? }
        let error = (try? JSONDecoder().decode(Refusal.self, from: data))?.error
        switch status {
        case 200: return .sent
        case 429: return .oneADay
        case 404: return error == "unknown player" ? .unknownFriend : .notOpen
        case 400, 409: return .refused
        default: return .unreachable
        }
    }
}
