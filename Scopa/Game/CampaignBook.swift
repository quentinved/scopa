import Foundation
import Observation

/// The campaign's progress: the best stars won at each table, and the way back to the map
/// after a game.
///
/// One number per stage in `UserDefaults`, under `campaign.stars.<id>`. Stars only climb,
/// so `AccountSync` carries them as counters and the larger of two devices' is the truth.
/// A stage is cleared at one star; the next unlocks on the first win.
@MainActor
@Observable
final class CampaignBook {
    /// What the last campaign game did, for the map's one-shot on the way back.
    struct Outcome: Equatable {
        let stage: CampaignStage
        /// The best at this table before the game.
        let before: Int
        /// What this game earned, nought for a loss.
        let earned: Int
        /// Set when this game cleared the region's last table for the first time.
        let finishedRegion: CampaignRegion?

        var won: Bool { earned > 0 }
        var firstClear: Bool { before == 0 && earned > 0 }
        /// The best at this table now.
        var best: Int { max(before, earned) }
    }

    private(set) var stars: [String: Int] = [:]
    /// The map is up over the lobby. Set on the walk back from a campaign table.
    var showsMap = false
    private(set) var outcome: Outcome?
    /// The game last recorded, so a summary drawn twice records once.
    private var recordedGame: UUID?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        readStoredAgain()
    }

    static func key(_ id: String) -> String { "campaign.stars.\(id)" }

    /// Every stage's key, for the account to carry.
    static var counterKeys: [String] { Campaign.stages.map { key($0.id) } }

    func readStoredAgain() {
        stars = Campaign.stages.reduce(into: [:]) { stars, stage in
            let value = defaults.integer(forKey: Self.key(stage.id))
            if value > 0 { stars[stage.id] = min(value, 3) }
        }
    }

    // MARK: Reading

    func stars(of stage: CampaignStage) -> Int { stars[stage.id] ?? 0 }

    func isCleared(_ stage: CampaignStage) -> Bool { stars(of: stage) > 0 }

    /// The stars written down for good, leaving out any a debug flag planted in memory, so
    /// only these are ever paid for.
    func keptStars(of stage: CampaignStage) -> Int {
        min(defaults.integer(forKey: Self.key(stage.id)), 3)
    }

    /// The first table is always open; every other one opens on a win at the table before.
    /// A table already won stays open, even when a region was put in ahead of it since.
    func isUnlocked(_ stage: CampaignStage) -> Bool {
        guard !isCleared(stage), let previous = Campaign.stage(number: stage.number - 1) else { return true }
        return isCleared(previous)
    }

    /// The table the road has reached: the first not yet won, or the last once all are.
    var current: CampaignStage {
        Campaign.stages.first { !isCleared($0) } ?? Campaign.stages[Campaign.stages.count - 1]
    }

    var totalStars: Int { stars.values.reduce(0, +) }

    static var maxStars: Int { Campaign.stages.count * 3 }

    func stars(in region: CampaignRegion) -> Int {
        region.stages.reduce(0) { $0 + stars(of: $1) }
    }

    func isFinished(_ region: CampaignRegion) -> Bool {
        region.stages.allSatisfy(isCleared)
    }

    // MARK: Writing

    /// Writes a finished game down and keeps what it did for the map. Nil when this game
    /// was already recorded.
    @discardableResult
    func record(_ stage: CampaignStage, stars earned: Int, game: UUID) -> Outcome? {
        guard recordedGame != game else { return nil }
        recordedGame = game
        let before = stars(of: stage)
        if earned > before {
            stars[stage.id] = earned
            defaults.set(earned, forKey: Self.key(stage.id))
        }
        let finished = before == 0 && earned > 0 && stage.isFinale ? stage.region : nil
        let outcome = Outcome(stage: stage, before: before, earned: earned, finishedRegion: finished)
        self.outcome = outcome
        return outcome
    }

    /// Hands the last outcome to the map once.
    func takeOutcome() -> Outcome? {
        defer { outcome = nil }
        return outcome
    }

    #if DEBUG
    /// Plants the road as won up to, not including, stage `number`. Kept in memory only.
    func pretend(reached number: Int) {
        for stage in Campaign.stages where stage.number < number {
            stars[stage.id] = max(stars[stage.id] ?? 0, 1 + (stage.number * 7) % 3)
        }
    }

    /// Plants the road as a build from before Piemonte left it: won up to, not including,
    /// stage `number` of the thirty it counted then, and nothing in Piemonte. Memory only.
    func pretendBeforePiemonte(reached number: Int) {
        let old = Campaign.stages.filter { $0.region != .piemonte }
        for (offset, stage) in old.prefix(max(number - 1, 0)).enumerated() {
            stars[stage.id] = max(stars[stage.id] ?? 0, 1 + (offset * 7) % 3)
        }
    }

    /// Plants a game just won at `number`, for the map's walk-back moment.
    func pretendReturn(from number: Int, stars earned: Int = 3) {
        guard let stage = Campaign.stage(number: number) else { return }
        pretend(reached: number)
        if earned > 0 { stars[stage.id] = earned }
        outcome = Outcome(stage: stage, before: 0, earned: earned,
                          finishedRegion: stage.isFinale && earned > 0 ? stage.region : nil)
        showsMap = true
    }
    #endif
}
