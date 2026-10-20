import Foundation
import Observation
import StoreKit

/// Whether the App Store has a newer Scopa than this one, and whether today is a day to
/// say so.
///
/// The store is asked at most every few hours and its answer is kept, so a launch with no
/// network still knows. The card shows once a day at most, and "Later" quiets that version
/// for three days. A build ahead of the store, TestFlight's or a developer's, never sees it.
@MainActor
@Observable
final class StoreVersion {
    static let appID = "6810455597"
    /// Opens Scopa's own page in the App Store app.
    static let storeURL = URL(string: "itms-apps://apps.apple.com/app/id\(appID)")!

    /// How long the store's answer is good for.
    private static let askEvery: TimeInterval = 4 * 3_600
    /// The least time between two cards.
    private static let showEvery: TimeInterval = 86_400
    /// How long "Later" quiets one version.
    private static let laterWait: TimeInterval = 3 * 86_400

    private enum Key {
        static let latest = "storeVersion.latest"
        static let asked = "storeVersion.asked"
        static let shown = "storeVersion.shown"
        static let later = "storeVersion.later"
        static let laterUntil = "storeVersion.laterUntil"
    }

    /// The version the store last said it has.
    private(set) var latest: String?
    private let defaults: UserDefaults
    /// Pretended with `-updateAvailable`, so nothing is fetched and nothing written down.
    private let isForced: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isForced = DebugLaunch.storeVersion != nil
        latest = DebugLaunch.storeVersion ?? defaults.string(forKey: Key.latest)
    }

    /// The version to offer now, or nil when the store is not ahead or it is too soon.
    func offer(now: Date = .now) -> String? {
        guard let latest, Self.isNewer(latest, than: Releases.version) else { return nil }
        if isForced { return latest }
        guard !Self.isQuiet else { return nil }
        if let shown = defaults.object(forKey: Key.shown) as? Date,
           now.timeIntervalSince(shown) < Self.showEvery { return nil }
        if defaults.string(forKey: Key.later) == latest,
           let until = defaults.object(forKey: Key.laterUntil) as? Date, now < until { return nil }
        return latest
    }

    func markShown(now: Date = .now) {
        guard !isForced else { return }
        defaults.set(now, forKey: Key.shown)
    }

    /// Quiets this version for a few days. A newer one is offered on its own day.
    func later(now: Date = .now) {
        guard !isForced, let latest else { return }
        defaults.set(latest, forKey: Key.later)
        defaults.set(now.addingTimeInterval(Self.laterWait), forKey: Key.laterUntil)
    }

    /// Asks the store again once its last answer has gone stale. A failure counts as an
    /// answer, so a phone with no network is not asking on every launch.
    func refresh(now: Date = .now) async {
        guard !isForced, !Self.isQuiet else { return }
        if let asked = defaults.object(forKey: Key.asked) as? Date,
           now.timeIntervalSince(asked) < Self.askEvery { return }
        defaults.set(now, forKey: Key.asked)
        guard let version = await Self.fetch() else { return }
        latest = version
        defaults.set(version, forKey: Key.latest)
    }

    /// Compares dotted versions number by number, so 1.3.10 is newer than 1.3.9.
    static func isNewer(_ version: String, than other: String) -> Bool {
        let mine = numbers(version), theirs = numbers(other)
        for index in 0..<max(mine.count, theirs.count) {
            let left = mine[safe: index] ?? 0, right = theirs[safe: index] ?? 0
            if left != right { return left > right }
        }
        return false
    }

    private static func numbers(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    // MARK: The store

    private struct Lookup: Decodable {
        struct Entry: Decodable { let version: String }
        let results: [Entry]
    }

    private static func fetch() async -> String? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [URLQueryItem(name: "id", value: appID)]
        if let country = await country() { components.queryItems?.append(URLQueryItem(name: "country", value: country)) }
        guard let url = components.url else { return nil }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return (try? JSONDecoder().decode(Lookup.self, from: data))?.results.first?.version
    }

    /// The storefront's country as the lookup wants it. StoreKit gives three letters, which
    /// `Locale` folds to the two the lookup takes; anything else asks the default store.
    private static func country() async -> String? {
        guard let code = await Storefront.current?.countryCode,
              let region = Locale(identifier: "und_\(code)").region?.identifier,
              region.count == 2 else { return nil }
        return region.lowercased()
    }

    /// Screenshots are taken with `-noGameCenter` and must not be covered by a card nobody
    /// asked for. `-updateAvailable` asks for one.
    private static var isQuiet: Bool {
        #if DEBUG
        DebugLaunch.staysSignedOut
        #else
        false
        #endif
    }
}
