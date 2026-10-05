import Foundation
import GameKit
import os
import ScopaGameCenter

/// The campaign's side of the ladder: the road posted after a win and on opening the map,
/// and the board and the map's faces read back. Quiet offline and signed out.
@MainActor
enum CampaignStandings {
    /// The last post that landed, so opening the map does not sign and send it again.
    private static let sentKey = "campaign.board.sent"

    /// The bare Game Center id, which is what the ladder keys on. Nil when signed out.
    static var playerID: String? {
        GameCenter.isSignedIn ? GKLocalPlayer.local.gamePlayerID : nil
    }

    // MARK: Posting

    /// Posts where the road has reached, unless that exact post already landed.
    static func report(_ book: CampaignBook, store: TableStore) {
        #if DEBUG
        if DebugLaunch.showsCampaignFaces { return }
        #endif
        guard Ladder.isOn, let playerID else { return }
        let (stage, stars) = reach(book)
        let look = (store.seatMark.wireValue, store.livery.wireValue, store.cornice.wireValue)
        let stamp = [playerID, "\(stage)", "\(stars)", look.0 ?? "", look.1 ?? "", look.2 ?? ""].joined(separator: "|")
        guard UserDefaults.standard.string(forKey: sentKey) != stamp else { return }
        Task {
            do {
                guard try await Ladder.postCampaign(stage: stage, stars: stars, mark: look.0, livery: look.1,
                                                    cornice: look.2) != nil else { return }
                UserDefaults.standard.set(stamp, forKey: sentKey)
            } catch {
                Log.table.error("The campaign's progress was not posted: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// The table reached and the stars won, from what is written down for good rather than
    /// anything a debug flag planted. Clamped to what the Worker accepts.
    static func reach(_ book: CampaignBook) -> (stage: Int, stars: Int) {
        let stage = Campaign.stages.first { book.keptStars(of: $0) == 0 } ?? Campaign.stages[Campaign.stages.count - 1]
        let stars = Campaign.stages.reduce(0) { $0 + book.keptStars(of: $1) }
        return (stage.number, min(stars, stage.number * 3))
    }

    // MARK: Reading

    /// The whole board. Nil when the ladder is off or will not answer.
    static func board() async -> Ladder.CampaignBoard? {
        #if DEBUG
        if DebugLaunch.showsCampaignFaces { return .sample }
        #endif
        guard Ladder.isOn else { return nil }
        do {
            return try await Ladder.campaignBoard(gamePlayerID: playerID)
        } catch {
            Log.table.error("The campaign's board could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The board among Game Center friends. Throws `GameCenterError` when the friends cannot
    /// be had, which the sheet puts in its own words.
    static func friendsBoard() async throws -> Ladder.CampaignBoard? {
        #if DEBUG
        if DebugLaunch.showsCampaignFaces { return .friendsSample }
        #endif
        guard Ladder.isOn else { return nil }
        let friends = try await GameCenter.loadFriends().map(\.gamePlayerID)
        do {
            return try await Ladder.friendsCampaignBoard(friends: friends, gamePlayerID: playerID)
        } catch {
            Log.table.error("The friends' campaign board could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Who sits at each table, by stage number. Empty when nobody can be had.
    static func tables() async -> [Int: Ladder.CampaignTable] {
        #if DEBUG
        if DebugLaunch.showsCampaignFaces { return Ladder.CampaignTable.samples }
        #endif
        guard Ladder.isOn else { return [:] }
        let friends = await GameCenter.friendIDsIfAllowed()
        guard let tables = try? await Ladder.campaignTables(friends: friends, gamePlayerID: playerID) else { return [:] }
        return Dictionary(tables.map { ($0.stage, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
