import Foundation
import ScopaCore
import ScopaRewards

/// A local game left unfinished, kept on disk so it is still there on the next launch.
///
/// Only tables played on this phone are kept. A networked game lives on the other devices too
/// and cannot be resumed alone, and the daily deal is a single round from the day's generator.
struct SavedGame: Codable, Equatable {
    static let version = 1

    var version = Self.version
    /// The table as it stood. `HotSeatTable` is rebuilt from this.
    let snapshot: HotSeatTable.Snapshot
    /// Which seats the machine plays, and which one belongs to this phone.
    let bots: Set<Int>
    let deviceSeat: Int
    /// The wager, if any. The stake left the purse when the game began, so the game has to be
    /// finishable for the pot to come back.
    let stake: Stake?
    let wagerID: UUID
    /// What the game had earned so far, so a scopa swept before the relaunch still pays.
    let tally: RewardTally?
    let savedAt: Date
    /// Dealt with Scatouch on, so it comes back with every card face up and still pays nothing.
    /// Missing from a save written before it existed.
    var scatouch: Bool? = nil
    /// A ranked game against the house that the app was closed on, so it comes back ranked, at
    /// the division it was dealt at, and reports under its own id when it ends. Nil for any
    /// other game, and for a ranked one walked out of, which the ladder has already had as lost.
    var ranked: Ranked? = nil

    struct Ranked: Codable, Equatable {
        let id: UUID
        let step: Int
        let format: String
    }

    var state: GameState { snapshot.state }
    var configuration: GameConfiguration { state.configuration }

    /// Who the resumed game is against, by name, for the lobby card. In teams a partner shares
    /// your side of the score and is left out.
    var opponentNames: [String] {
        let mine = configuration.side(ofSeat: deviceSeat)
        return configuration.players.indices
            .filter { configuration.side(ofSeat: $0) != mine }
            .map { configuration.players[$0].name }
    }

    /// This phone's side of the score, and the best of the other sides.
    var ownScore: Int { state.scores[safe: configuration.side(ofSeat: deviceSeat)] ?? 0 }
    var bestOtherScore: Int {
        let mine = configuration.side(ofSeat: deviceSeat)
        return state.scores.enumerated().filter { $0.offset != mine }.map(\.element).max() ?? 0
    }
}

/// Where the one unfinished game lives: a small JSON file beside the ledger. The write happens
/// after every move, so it goes through a detached task rather than the main actor.
enum SavedGameFile {
    private static var url: URL? {
        let folder = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return folder?.appendingPathComponent("table.json")
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func load() -> SavedGame? {
        guard let url, let data = try? Data(contentsOf: url),
              let saved = try? decoder.decode(SavedGame.self, from: data),
              saved.version <= SavedGame.version,
              // A finished game is never offered back, however it got written.
              !saved.state.isFinished
        else { return nil }
        return saved
    }

    static func save(_ game: SavedGame) {
        guard let url, let data = try? encoder.encode(game) else { return }
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func clear() {
        guard let url else { return }
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
