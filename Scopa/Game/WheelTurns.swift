import Foundation
import GameKit
import os
import ScopaGameCenter
import ScopaRewards

/// The day's wheel as everyone else turned it, read off the Worker. See `Server/src/wheel.ts`.
extension Ladder {
    struct WheelStrip: Decodable, Hashable {
        struct Turn: Decodable, Hashable, Identifiable {
            let id: String
            let name: String
            let prize: Prize
            let at: Date
            /// A Game Center friend of the reader, sent first.
            let friend: Bool
        }

        enum Prize: Decodable, Hashable {
            case denari(Int)
            case pack
            /// A shop item's id, which a build older than the item will not know.
            case item(String)
            case jackpot

            private enum Key: String, CodingKey { case kind, denari, item }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: Key.self)
                switch try container.decode(String.self, forKey: .kind) {
                case "denari": self = .denari(try container.decode(Int.self, forKey: .denari))
                case "item": self = .item(try container.decode(String.self, forKey: .item))
                case "jackpot": self = .jackpot
                default: self = .pack
                }
            }
        }

        let turns: [Turn]
        let jackpotsThisWeek: Int

        var isEmpty: Bool { turns.isEmpty && jackpotsThisWeek == 0 }
    }

    /// The last day's turns, the reader left out, friends first.
    static func wheelStrip(friends: [String], gamePlayerID: String?) async throws -> WheelStrip? {
        struct Lookup: Encodable { let player: String?; let friends: [String] }
        guard let baseURL else { return nil }
        var request = URLRequest(url: baseURL.appending(path: "v1/wheel/today"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(Lookup(player: gamePlayerID, friends: friends))
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WheelStrip.self, from: data)
    }
}

/// Reads the strip for the wheel's sheet. Quiet offline, and never brings up Game Center's
/// friends prompt: without access the strip is everyone's.
@MainActor
enum WheelTurns {
    static func today() async -> Ladder.WheelStrip? {
        #if DEBUG
        if DebugLaunch.showsWheelStrip { return .sample }
        #endif
        guard Ladder.isOn else { return nil }
        let playerID = GameCenter.isSignedIn ? GKLocalPlayer.local.gamePlayerID : nil
        do {
            return try await Ladder.wheelStrip(friends: await GameCenter.friendIDsIfAllowed(), gamePlayerID: playerID)
        } catch {
            Log.table.error("The wheel's strip could not be read: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

extension GameCenter {
    /// The friends' ids, only where Scopa may already see them: never brings up Game
    /// Center's prompt.
    static func friendIDsIfAllowed() async -> [String] {
        guard await friendsAccess() == .granted else { return [] }
        return (try? await loadFriends().map(\.gamePlayerID)) ?? []
    }
}

extension DebugLaunch {
    /// `-wheelStrip` fills the wheel's strip with made-up turns, for a screenshot.
    static var showsWheelStrip: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-wheelStrip")
        #else
        false
        #endif
    }
}

#if DEBUG
extension Ladder.WheelStrip {
    static var sample: Self {
        let now = Date.now
        func turn(_ name: String, _ prize: Prize, minutes: Double, friend: Bool = false) -> Turn {
            Turn(id: name, name: name, prize: prize, at: now.addingTimeInterval(-minutes * 60), friend: friend)
        }
        return Self(turns: [
            turn("Giulia", .denari(100), minutes: 12, friend: true),
            turn("Marco", .jackpot, minutes: 4),
            turn("Sofia", .pack, minutes: 25),
            turn("Luca", .item(Cosmetics.catalogue.items.first?.id.rawValue ?? ""), minutes: 48),
            turn("Chiara", .denari(25), minutes: 70),
            turn("Paolo", .denari(250), minutes: 130),
        ], jackpotsThisWeek: 3)
    }
}
#endif
