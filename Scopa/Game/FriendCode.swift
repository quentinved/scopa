import Foundation
import ScopaGameCenter
import ScopaRewards

/// A code a friend handed out, worth a gift once per player. See `Server/src/friendcodes.ts`.
///
/// Signed with Game Center, so the Worker can hold a player to one code whichever device
/// they type it on. That is also what makes the count behind each code worth reading.
enum FriendCode {
    /// What a friend's code is worth. Either or both may be set.
    struct Gift: Decodable, Equatable {
        let owner: String
        private let pack: String?
        let denari: Denari
        /// False when this player had already used this same code, so nothing is owed.
        let fresh: Bool

        /// A tier this build does not know is dropped rather than failing the gift.
        var tier: PackTier? { pack.flatMap(PackTier.init(rawValue:)) }
    }

    enum Outcome: Equatable {
        case gift(Gift)
        /// This player's one code was somebody else's.
        case usedAnother(owner: String)
        case unknown
        case notSignedIn
        case unreachable
    }

    static func redeem(_ code: String) async -> Outcome {
        guard let baseURL = Ladder.baseURL else { return .unreachable }
        guard GameCenter.isSignedIn else { return .notSignedIn }
        do {
            let request = try await request(code, to: baseURL.appending(path: "v1/codes/redeem"))
            let (data, response) = try await URLSession.shared.data(for: request)
            return outcome(of: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            return .unreachable
        }
    }

    private static func request(_ code: String, to url: URL) async throws -> URLRequest {
        struct Post: Encodable {
            let code: String
            let identity: GameCenterIdentity
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(Post(code: code, identity: try await GameCenter.identity()))
        return request
    }

    private static func outcome(of data: Data, status: Int) -> Outcome {
        struct Refusal: Decodable { let owner: String? }
        switch status {
        case 200: return (try? JSONDecoder().decode(Gift.self, from: data)).map(Outcome.gift) ?? .unreachable
        case 400, 404: return .unknown
        case 409: return .usedAnother(owner: (try? JSONDecoder().decode(Refusal.self, from: data))?.owner ?? "")
        default: return .unreachable
        }
    }

    // MARK: Remembered on this device

    private static let key = "friendCode.owner"

    /// Whose code this device paid out, so the panel can say so rather than ask again.
    static var usedOwner: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
