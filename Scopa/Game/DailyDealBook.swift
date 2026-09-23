import Foundation
import Observation
import ScopaCore

/// One day's deal, played out.
struct DailyDealResult: Codable, Hashable, Identifiable {
    /// "2026-09-08", which names both the deck and the result.
    let day: String
    let playedAt: Date
    /// Your points in the round.
    let mine: Int
    /// The bot's points.
    let theirs: Int
    let scope: Int
    /// From the review, once it has been read back. Nil until then.
    var accuracy: Int?
    /// Where it placed among everyone who played that day, once the ladder has answered.
    var rank: Int?
    var played: Int?

    var id: String { day }
    /// What the ladder ranks by: your points over the bot's, which can go below zero.
    var margin: Int { mine - theirs }
    var won: Bool { margin > 0 }
}

/// Every daily deal this phone has played, kept on disk in its own file rather than in the
/// ledger, which records money. Written as a version and a flat list so a server can be handed
/// it when the ladder goes world-wide.
@MainActor
@Observable
final class DailyDealBook {
    private struct Wrapper: Codable {
        var version: Int
        var results: [DailyDealResult]
    }

    static let version = 1

    private(set) var results: [DailyDealResult] = []
    private(set) var isLoaded = false
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    /// The real book, next to the ledger in Application Support.
    convenience init() {
        let folder = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        self.init(url: folder?.appendingPathComponent("daily.json"))
    }

    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let url, let data = try? Data(contentsOf: url),
              let wrapper = try? Self.decoder.decode(Wrapper.self, from: data),
              wrapper.version <= Self.version
        else { return }
        results = wrapper.results.sorted { $0.day < $1.day }
    }

    func result(for day: String) -> DailyDealResult? {
        results.first { $0.day == day }
    }

    /// Whether the day's deal has been played. The deck does not change until midnight, so a
    /// second go is the same deal and only the first result is kept.
    func hasPlayed(_ day: String) -> Bool { result(for: day) != nil }

    /// Writes a day's result, or leaves the one already there.
    func record(_ result: DailyDealResult) {
        guard !hasPlayed(result.day) else { return }
        results.append(result)
        results.sort { $0.day < $1.day }
        save()
    }

    /// Fills in where a day's result placed on the ladder.
    func note(rank: Int, played: Int, for day: String) {
        guard let index = results.firstIndex(where: { $0.day == day }) else { return }
        results[index].rank = rank
        results[index].played = played
        save()
    }

    /// Fills in the review's verdict on a result already written.
    func note(accuracy: Int, for day: String) {
        guard let index = results.firstIndex(where: { $0.day == day }), results[index].accuracy == nil else { return }
        results[index].accuracy = accuracy
        save()
    }

    /// Days played in a row, counting back from `day`, or from the day before when `day` itself
    /// has not been played yet.
    func streak(endingOn day: String, calendar: Calendar = .current) -> Int {
        let played = Set(results.map(\.day))
        guard var date = Self.date(from: day, calendar: calendar) else { return 0 }
        if !played.contains(day) {
            guard let before = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = before
        }
        var count = 0
        while played.contains(DailyDeal.day(for: date, calendar: calendar)) {
            count += 1
            guard let before = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = before
        }
        return count
    }

    var best: DailyDealResult? {
        results.max { $0.margin < $1.margin }
    }

    var wins: Int { results.count { $0.won } }

    private func save() {
        guard let url, let data = try? Self.encoder.encode(Wrapper(version: Self.version, results: results)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func date(from day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
