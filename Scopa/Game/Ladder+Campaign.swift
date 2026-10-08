import Foundation
import ScopaGameCenter

/// The campaign's board on the Worker: how far each player's road has reached, and who is
/// sitting at each table of the map. See `Server/src/campaign.ts`.
extension Ladder {
    /// The board, most stars first and the furthest road breaking a tie.
    struct CampaignBoard: Codable, Hashable {
        struct Row: Codable, Hashable, Identifiable, CampaignLook {
            let id: String
            let name: String
            /// The table the road has reached, counted from one.
            let stage: Int
            let stars: Int
            let mark: String?
            let livery: String?
            let cornice: String?
        }

        let top: [Row]
        /// Where the reader stands. No rank until they have posted any progress.
        let you: SeasonBoard.Place?

        var isEmpty: Bool { top.isEmpty }
    }

    /// One player sitting at a table of the map.
    struct CampaignFace: Codable, Hashable, Identifiable, CampaignLook {
        let id: String
        let name: String
        let mark: String?
        let livery: String?
        let cornice: String?
        /// A Game Center friend of the reader, sent first.
        let friend: Bool
    }

    /// Who sits at one table: a few faces, and how many are there in all.
    struct CampaignTable: Codable, Hashable {
        let stage: Int
        let count: Int
        let faces: [CampaignFace]

        /// The ones not drawn, for the "+N" beside the faces.
        var more: Int { max(count - faces.count, 0) }
    }

    /// Tells the Worker this app counts the road in thirty-six, Piemonte included.
    private static let road = 36

    private struct CampaignPost: Encodable {
        let road = Ladder.road
        let stage: Int
        let stars: Int
        let mark: String?
        let livery: String?
        let cornice: String?
        let identity: GameCenterIdentity
    }

    /// Posts where the road has reached. Nil when the ladder is off or nobody is signed in.
    @discardableResult
    static func postCampaign(stage: Int, stars: Int, mark: String?, livery: String?,
                             cornice: String?) async throws -> SeasonBoard.Place? {
        try await signedPost("v1/campaign") {
            CampaignPost(stage: stage, stars: stars, mark: mark, livery: livery, cornice: cornice, identity: $0)
        }
    }

    static func campaignBoard(gamePlayerID: String?) async throws -> CampaignBoard? {
        guard let baseURL else { return nil }
        var url = baseURL.appending(path: "v1/campaign/board")
        url.append(queryItems: [URLQueryItem(name: "road", value: "\(road)")])
        if let gamePlayerID {
            url.append(queryItems: [URLQueryItem(name: "player", value: gamePlayerID)])
        }
        return try await get(url)
    }

    /// The board among the reader's Game Center friends, with the reader on it.
    static func friendsCampaignBoard(friends: [String], gamePlayerID: String?) async throws -> CampaignBoard? {
        try await unsignedPost("v1/campaign/board/friends", body: Lookup(player: gamePlayerID, friends: friends))
    }

    /// Every table somebody sits at, the reader left out, friends first.
    static func campaignTables(friends: [String], gamePlayerID: String?) async throws -> [CampaignTable]? {
        struct Answer: Decodable { let stages: [CampaignTable] }
        let answer: Answer? = try await unsignedPost("v1/campaign/stages",
                                                     body: Lookup(player: gamePlayerID, friends: friends))
        return answer?.stages
    }

    private struct Lookup: Encodable {
        let road = Ladder.road
        let player: String?
        let friends: [String]
    }
}

/// What a player on the campaign's board wears on their seat, as the raw values that travel.
/// Nil is the default of each.
protocol CampaignLook {
    var id: String { get }
    var name: String { get }
    var mark: String? { get }
    var livery: String? { get }
    var cornice: String? { get }
}
