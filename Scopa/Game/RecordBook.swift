import Foundation
import Observation
import ScopaCore
import ScopaRewards

/// Every game finished on this phone, and the record they add up to: the page under the
/// name in Settings, and the head-to-head line on the last summary.
///
/// Kept on the device, beside `Experience`, and never synced, not even with the account.
/// The log is mostly other people: their names, their Game Center ids, when you sat down
/// with them. A server has no business holding that for a page only this phone shows. It
/// is also the one thing here that grows with every game, where the account carries a
/// fixed handful of numbers.
@MainActor
@Observable
final class RecordBook {
    /// One book for the app, so the summary and the settings read the same games.
    static let shared = RecordBook()

    private struct Wrapper: Codable {
        var version: Int
        var log: GameLog
    }

    static let version = 1

    private(set) var log = GameLog()
    private(set) var isLoaded = false
    /// A book this build cannot read, written by a later one most likely. Left alone rather
    /// than written over with an empty one.
    private var isUnreadable = false
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    /// The real book, in Application Support next to the daily deals.
    convenience init() {
        let folder = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        self.init(url: folder?.appendingPathComponent("record.json"))
    }

    /// Reads the book, or starts one. A phone with no book has never had this release, so
    /// whatever `Achievements` counted before it is carried over once, here.
    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        #if DEBUG
        // `-recordPage` and `-recordLine` read a sample for the launch, and write nothing.
        if let sample = DebugLaunch.sampleRecord { log = sample; return }
        #endif
        guard let url else { return }
        if let data = try? Data(contentsOf: url) {
            guard let wrapper = try? Self.decoder.decode(Wrapper.self, from: data),
                  wrapper.version <= Self.version else { isUnreadable = true; return }
            log = wrapper.log
            return
        }
        log = GameLog(totals: Self.carriedOver())
        save()
    }

    /// What the counters knew before there was a log: wins, losses, and what was swept.
    /// Losses were only counted from 1.1, so a phone older than that comes in light, which
    /// is the right way round.
    private static func carriedOver() -> RecordTotals {
        let record = Achievements.record
        return RecordTotals(before: WonLost(won: record.wins, lost: record.losses), scope: record.scope,
                            settebelli: record.settebelli, cappotti: record.cappotti)
    }

    /// A finished game, written once. Called before `Achievements.record`, so a book opened
    /// for the first time by this very game carries over the counters without it.
    func record(_ game: LoggedGame) {
        load()
        guard log.add(game) else { return }
        save()
    }

    /// The head-to-head with whoever was across the table, once `gameID` is in the book.
    /// Read from a summary's body, so it never loads: `record` has, by the time it matters.
    func standing(after gameID: UUID?) -> Rivalry? {
        gameID.flatMap(log.standing(after:))
    }

    private func save() {
        #if DEBUG
        guard !DebugLaunch.showsRecord, !DebugLaunch.showsRecordLine else { return }
        #endif
        guard let url, !isUnreadable, let data = try? Self.encoder.encode(Wrapper(version: Self.version, log: log)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
