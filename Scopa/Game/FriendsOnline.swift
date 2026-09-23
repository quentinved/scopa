import Foundation
import GameKit
import os
import ScopaGameCenter

/// Which Game Center friends have Scopa open, for "Marco is on Scopa".
///
/// A heartbeat to the Worker about once a minute while the app is in front. Each beat says
/// this player is here and names their friends; the answer is the friends who are here too
/// and who named this player back. Being seen is mutual: turn this off and the phone stops
/// beating, tells the Worker to forget it, and stops hearing about anybody else as well.
///
/// It needs Game Center's permission to see friends, and never asks for it on its own: the
/// prompt comes only from the player turning this on in Settings, or from the ranked duo's
/// partner picker, which asks for the same thing.
@MainActor @Observable
final class FriendsOnline {
    private enum Key {
        static let wanted = "friendsOnline.wanted"
    }

    /// What the player chose. On unless they turned it off: the permission to see friends
    /// is the real gate, and it is one they gave.
    private(set) var isWanted: Bool

    /// Game Center's answer on seeing friends, as of the last look.
    private(set) var access: FriendsAccess = .notAsked

    /// The friends here right now, by Game Center name.
    private(set) var online: [Friend] = []

    struct Friend: Hashable, Identifiable {
        let id: String
        let name: String
    }

    /// Whether beats go out at all.
    var isOn: Bool { isWanted && access == .granted && Ladder.isOn }

    /// Friends already announced this time round. Someone who leaves drops out of it, so
    /// coming back is news again.
    private var announced: Set<String> = []
    /// The friend list, with the names Game Center shows. Reloaded now and then, since a
    /// friend added in Game Center should not take a relaunch to count.
    private var friends: [String: String] = [:]
    private var friendsLoaded: Date?
    /// A signature lasts the Worker an hour. Kept for a little less.
    private var identity: (GameCenterIdentity, Date)?

    private static let friendsLifetime: TimeInterval = 10 * 60
    private static let identityLifetime: TimeInterval = 50 * 60

    init() {
        isWanted = UserDefaults.standard.object(forKey: Key.wanted) as? Bool ?? true
    }

    /// Looks at the permission again, without asking. On every return to the front: it can
    /// be changed in the iPhone's Settings while Scopa is away.
    func refreshAccess() async {
        access = await GameCenter.friendsAccess()
    }

    /// The switch in Settings. Turning it on asks Game Center for the friends, which is the
    /// one place this ever brings up Apple's prompt.
    func turnOn() async {
        setWanted(true)
        _ = try? await GameCenter.loadFriends()
        await refreshAccess()
    }

    func turnOff() async {
        setWanted(false)
        online = []
        announced = []
        guard let identity = try? await signature() else { return }
        try? await Ladder.leavePresence(identity: identity)
    }

    /// One heartbeat. Returns how long to wait before the next one.
    func beat() async -> Duration {
        let fallback = Duration.seconds(60)
        guard isOn else { return fallback }
        do {
            try await loadFriendsIfStale()
            guard let identity = try await signature(),
                  let answer = try await Ladder.beat(friends: Array(friends.keys), identity: identity)
            else { return fallback }
            // A beat that lands after the switch went off must not put anybody back.
            guard isOn else { return fallback }
            online = answer.online
                .map { Friend(id: $0.id, name: friends[$0.id] ?? $0.name) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            announced.formIntersection(online.map(\.id))
            return .seconds(max(answer.every, 30))
        } catch {
            Log.table.error("Friends online did not beat: \(String(describing: error), privacy: .public)")
            return fallback
        }
    }

    /// The friends who have arrived since the last time anyone was told, marked as told.
    func takeNews() -> [Friend] {
        let news = online.filter { !announced.contains($0.id) }
        announced.formUnion(news.map(\.id))
        return news
    }

    // MARK: Pieces

    private func setWanted(_ wanted: Bool) {
        isWanted = wanted
        UserDefaults.standard.set(wanted, forKey: Key.wanted)
    }

    private func loadFriendsIfStale() async throws {
        if let friendsLoaded, Date.now.timeIntervalSince(friendsLoaded) < Self.friendsLifetime { return }
        let players = try await GameCenter.loadFriends()
        friends = Dictionary(players.map { ($0.gamePlayerID, $0.displayName ?? $0.alias) }, uniquingKeysWith: { first, _ in first })
        friendsLoaded = .now
    }

    private func signature() async throws -> GameCenterIdentity? {
        guard GameCenter.isSignedIn else { return nil }
        if let (identity, made) = identity, Date.now.timeIntervalSince(made) < Self.identityLifetime { return identity }
        let fresh = try await GameCenter.identity()
        identity = (fresh, .now)
        return fresh
    }
}
