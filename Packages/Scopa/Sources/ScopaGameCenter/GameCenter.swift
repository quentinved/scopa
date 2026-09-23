import Foundation
import GameKit
import ScopaCore

public enum GameCenterError: Error, Sendable, Hashable {
    /// Game Center is off for this device, or the player closed the sign-in.
    case notSignedIn
    case cancelled
    case matchmakingFailed(String)
    /// The player said no to Scopa seeing their friends, or turned friend lists off for
    /// every game in Settings.
    case friendsDenied
    /// Friend lists are restricted on this device, usually by Screen Time, and the
    /// player cannot turn them on.
    case friendsRestricted
    /// The list could not be fetched: offline, Game Center down, or a missing usage
    /// description. The text is Apple's.
    case friendsUnavailable(String)
}

/// What the player has said about Scopa seeing their Game Center friends.
public enum FriendsAccess: Sendable {
    case granted, notAsked, denied, restricted
}

/// Signing in and finding a table, as plain async calls.
public enum GameCenter {
    /// The Game Center id, stable for this player across our games. The name is their
    /// Game Center name rather than the one typed into the app.
    public static func id(of player: GKPlayer) -> PlayerID {
        PlayerID(rawValue: "gc:" + player.gamePlayerID)
    }

    public static func player(for player: GKPlayer) -> Player {
        Player(id: id(of: player), name: player.displayName)
    }

    /// Whether the player is signed in right now, without asking them anything.
    public static var isSignedIn: Bool { GKLocalPlayer.local.isAuthenticated }

    /// The Game Center name of whoever is signed in, or nil when nobody is. The name and
    /// not the id, because it is the one a player recognises as themselves.
    public static var localName: String? {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : nil
    }

    /// Signs in, showing Apple's sheet through `present` if the device asks for one.
    /// A second call while signed in returns at once. Game Center keeps the handler and
    /// calls it again on every sign-in change, so it is set once.
    public static func signIn(present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> Player {
        if GKLocalPlayer.local.isAuthenticated {
            registerInviteListener()
            return player(for: GKLocalPlayer.local)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let box = OnceBox(continuation)
            GKLocalPlayer.local.authenticateHandler = { controller, error in
                if let controller {
                    Task { @MainActor in present(controller) }
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    // This handler replaces the one `signInQuietly` left behind, so the
                    // invite listener and the sign-in announcement have to happen here too.
                    registerInviteListener()
                    announceSignIn()
                    box.resume(.success(player(for: GKLocalPlayer.local)))
                } else {
                    box.resume(.failure(GameCenterError.notSignedIn))
                }
            }
        }
    }

    /// Finds a table of `players`, and waits until everyone is connected.
    ///
    /// A `pool` limits a search to players searching under the same name, one league or
    /// one stake, so a ranked table never meets a casual one. Without one, anybody of the
    /// same table size will do.
    public static func findMatch(players: Int, pool: String? = nil) async throws -> GKMatch {
        try await findMatch(players: players...players, pool: pool)
    }

    /// The same, taking any table size in `players`. Game Center fills towards the top of
    /// the range and settles for fewer when nobody else is searching.
    public static func findMatch(players: ClosedRange<Int>, pool: String? = nil) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
        if let pool, !pool.isEmpty { request.playerGroup = group(for: pool) }
        do {
            let match = try await GKMatchmaker.shared().findMatch(for: request)
            try await waitUntilFull(match)
            return match
        } catch let error as GKError where error.code == .cancelled {
            throw GameCenterError.cancelled
        } catch let error as GameCenterError {
            throw error
        } catch {
            throw GameCenterError.matchmakingFailed(error.localizedDescription)
        }
    }

    /// Signs in without showing Apple's sheet, so invitations can reach a player already
    /// signed in to Game Center on the phone. Anyone else stays signed out until they choose
    /// to play online. `ready` is called on the main actor as soon as the player turns out
    /// to be signed in, so the ladder can be asked where they stand.
    public static func signInQuietly(then ready: (@MainActor @Sendable () -> Void)? = nil) {
        signInReady = ready
        guard !GKLocalPlayer.local.isAuthenticated else {
            registerInviteListener()
            announceSignIn()
            return
        }
        guard GKLocalPlayer.local.authenticateHandler == nil else { return }
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            guard GKLocalPlayer.local.isAuthenticated else { return }
            registerInviteListener()
            announceSignIn()
        }
    }

    /// Whoever asked to be told the moment the player turns out to be signed in. Kept here
    /// rather than closed over by one handler, because the sheet's sign-in replaces the
    /// quiet one's handler outright and would otherwise leave the waiting caller waiting.
    private nonisolated(unsafe) static var signInReady: (@MainActor @Sendable () -> Void)?

    private static func announceSignIn() {
        guard let ready = signInReady else { return }
        Task { @MainActor in ready() }
    }

    /// Apple's own sheet for picking friends to invite, or anyone to fill the rest. Comes
    /// back with the match once everyone invited has sat down.
    /// The pool a ranked duo is made from: a pair plus whoever else is looking with a pair.
    public static let rankedDuoGroup = group(for: "\u{1}ranked-duo")

    /// Whether an invitation is to a ranked duo rather than a friendly table.
    public static func isRankedDuo(_ invite: GKInvite) -> Bool { invite.playerGroup == rankedDuoGroup }

    /// What a duo invitation says on the other phone, whichever way it was sent.
    private static let duoInviteMessage = "A ranked duo of Scopa? You and me, against the house."

    /// This player's Game Center friends, to pick a partner from. iOS asks the first time
    /// and remembers the answer.
    ///
    /// Only friends who also have Scopa, and have let it see their friends, come back:
    /// Game Center scopes the list to the app on both ends. No friends is an empty list,
    /// not an error; an error is a refusal or a failure to fetch, told apart here.
    public static func loadFriends() async throws -> [GKPlayer] {
        guard GKLocalPlayer.local.isAuthenticated else { throw GameCenterError.notSignedIn }
        do {
            return try await GKLocalPlayer.local.loadFriends()
        } catch let error as GKError {
            switch error.code {
            case .friendListDenied: throw GameCenterError.friendsDenied
            case .friendListRestricted: throw GameCenterError.friendsRestricted
            case .notAuthenticated: throw GameCenterError.notSignedIn
            default: throw GameCenterError.friendsUnavailable(error.localizedDescription)
            }
        } catch {
            throw GameCenterError.friendsUnavailable(error.localizedDescription)
        }
    }

    /// Whether Scopa may see this player's friends, asked without asking them: the prompt
    /// only ever comes from `loadFriends`. Anything that goes wrong reads as not yet asked.
    public static func friendsAccess() async -> FriendsAccess {
        guard GKLocalPlayer.local.isAuthenticated,
              let status = try? await GKLocalPlayer.local.loadFriendsAuthorizationStatus() else { return .notAsked }
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notAsked
        @unknown default: return .notAsked
        }
    }

    /// Apple's own friends page, where a friend request can be sent. Comes down on its
    /// own when the player is done. `done` says when, so a friend list can be fetched
    /// again: a friend added here is a partner that was not there before.
    @MainActor
    public static func showFriends(present: @escaping @MainActor @Sendable (PlatformViewController) -> Void,
                                   done: (@MainActor @Sendable () -> Void)? = nil) {
        let controller = GKGameCenterViewController(state: .localPlayerFriendsList)
        let delegate = DismissingDelegate(done)
        controller.gameCenterDelegate = delegate
        dismissingDelegate = delegate
        present(controller)
    }

    /// Apple's own page for one player: their nickname, what they play, and the button
    /// that asks them to be friends.
    ///
    /// There is no API for sending a friend request, so this page is the only place it
    /// happens. iOS 18 and up, where `init(player:)` arrived.
    @available(iOS 18.0, macOS 15.0, *)
    @MainActor
    public static func showProfile(of player: GKPlayer,
                                   present: @escaping @MainActor @Sendable (PlatformViewController) -> Void,
                                   done: (@MainActor @Sendable () -> Void)? = nil) {
        let controller = GKGameCenterViewController(player: player)
        let delegate = DismissingDelegate(done)
        controller.gameCenterDelegate = delegate
        dismissingDelegate = delegate
        present(controller)
    }

    private nonisolated(unsafe) static var dismissingDelegate: DismissingDelegate?

    /// A duo with no sheet anywhere: one friend invited by name, and nobody else.
    ///
    /// The other two chairs are the host's to fill once both are seated. They used to be
    /// asked of Game Center, which cannot answer: `addPlayers` matches against players
    /// who are *searching*, and nothing in this app ever searches the duo pool, so the
    /// table waited out its patience and the invited friend sat in the waiting room the
    /// whole time looking like they could not join.
    public static func makeDuo(with friend: GKPlayer) async throws -> GKMatch {
        let invitation = GKMatchRequest()
        invitation.minPlayers = 2
        invitation.maxPlayers = 2
        invitation.recipients = [friend]
        invitation.inviteMessage = duoInviteMessage
        // Travels with the invitation, so the friend's phone knows what it is accepting.
        invitation.playerGroup = rankedDuoGroup
        do {
            let match = try await GKMatchmaker.shared().findMatch(for: invitation)
            // A friend takes longer to answer a notification than a stranger takes to be found.
            try await waitUntilFull(match, patience: 1800)
            return match
        } catch let error as GKError where error.code == .cancelled {
            throw GameCenterError.cancelled
        } catch let error as GameCenterError {
            throw error
        } catch {
            throw GameCenterError.matchmakingFailed(error.localizedDescription)
        }
    }

    /// A duo asked for through Apple's invitation sheet, where any Game Center friend can
    /// be named rather than only the ones this app is allowed to list.
    ///
    /// `loadFriends` answers with the friends who have let *Scopa* see them, which in
    /// practice is the friends who already play it; everybody else is missing from the
    /// partner picker. Apple's friends page is no help either: it browses profiles and has
    /// no way to invite anyone from it. This sheet is the one place the rest of the friend
    /// list can be asked to a table, so it is what "invite someone else" opens.
    ///
    /// Comes back with the match once the friend has said yes. The sheet does the waiting.
    @MainActor
    public static func inviteDuo(present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = duoInviteMessage
        // Travels with the invitation, so the friend's phone knows it is a duo it is accepting.
        request.playerGroup = rankedDuoGroup
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            throw GameCenterError.matchmakingFailed("No matchmaker")
        }
        // The friend named and nobody else: the other two chairs belong to the house.
        controller.matchmakingMode = .inviteOnly
        return try await matchmaker(controller, present: present)
    }

    @MainActor
    public static func inviteFriends(players: ClosedRange<Int>, group: Int? = nil, fillingWithStrangers: Bool = false,
                                     present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
        request.inviteMessage = "A game of Scopa?"
        if let group { request.playerGroup = group }
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            throw GameCenterError.matchmakingFailed("No matchmaker")
        }
        // A duo is one friend and two strangers from the same pool; a friendly table is
        // only the people named.
        controller.matchmakingMode = fillingWithStrangers ? .default : .inviteOnly
        return try await matchmaker(controller, present: present)
    }

    /// Apple's invitation sheet for a table that already exists: one more friend named,
    /// and their phone rings the way it rang for the first invitation.
    ///
    /// Nothing comes back. The friend arrives through the match's own delegate and their
    /// phone sends its join once seated, so this only puts the sheet up and takes it down.
    /// `seats` is the size the table was made for, and Game Center will not seat more.
    @MainActor
    public static func invite(to match: GKMatch, seats: Int,
                              present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = seats
        request.inviteMessage = "A game of Scopa?"
        guard let controller = GKMatchmakerViewController(matchRequest: request) else { return }
        // Only the people named: a chair kept for a friend is not a chair for a stranger.
        controller.matchmakingMode = .inviteOnly
        // Cancelling is how this sheet ends even when an invitation went out, so the
        // answer is thrown away either way.
        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GKMatch, Error>) in
            let delegate = MatchmakerDelegate(continuation)
            controller.matchmakerDelegate = delegate
            matchmakerDelegate = delegate
            present(controller)
            // After the sheet is up, the way Apple's own sample does it: this is what tells
            // the sheet it is filling a chair at `match` rather than opening a second table.
            controller.addPlayers(to: match)
        }
    }

    /// Apple's invitation sheet, asking a friend to a room of ours on the Worker rather
    /// than to a match of Apple's.
    ///
    /// Game Center knows nothing about rooms, so the thing the invitation has to carry is
    /// the four letters, and `group` is where they ride: see `Relay.inviteGroup`. The match
    /// made when the friend says yes is only a doorbell: it tells this sheet the friend is
    /// coming, and both ends walk away from it at once. They play in the room.
    @MainActor
    public static func inviteToRoom(group: Int, present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        try await inviteFriends(players: 2...2, group: group, present: present)
    }

    /// Says yes to an invitation and then walks away from the match it makes: the other end
    /// of `inviteToRoom`, where the code was in the invitation and the match is the doorbell.
    ///
    /// Accepted properly, because the host's sheet is waiting for exactly that and hangs
    /// until it comes; left a beat later, because by then it has done all it was for.
    public static func acknowledge(_ invite: GKInvite) async {
        guard let match = try? await GKMatchmaker.shared().match(for: invite) else { return }
        try? await Task.sleep(for: .seconds(1))
        match.disconnect()
    }

    /// The other end of an invitation: the sheet that accepts it and waits for the table.
    @MainActor
    public static func accept(_ invite: GKInvite, present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        try await matchmaker(GKMatchmakerViewController(invite: invite), present: present)
    }

    /// Hands every invitation this player accepts, from a notification or from Messages,
    /// to `handler`. Registered once and kept for the life of the app.
    ///
    /// Handed to Game Center only once the player is authenticated: a listener registered on
    /// a signed-out local player is never called. The app registers this on the first screen,
    /// before the quiet sign-in has answered, so it has to be held until then.
    public static func listenForInvites(_ handler: @escaping @MainActor @Sendable (GKInvite) -> Void) {
        inviteListener = InviteListener(handler)
        registerInviteListener()
    }

    private nonisolated(unsafe) static var inviteListener: InviteListener?

    /// The player the listener is registered for. Game Center lets its listeners go when the
    /// signed-in player changes, so registering again after every sign-in is what keeps
    /// invitations arriving; remembering who it was for is what stops it registering twice.
    private nonisolated(unsafe) static var listeningFor: String?

    /// Registers the invitation listener, if there is one and there is somebody to register
    /// it for. Called after every sign-in, and cheap to call when nothing has changed.
    private static func registerInviteListener() {
        guard let inviteListener, GKLocalPlayer.local.isAuthenticated else { return }
        let player = GKLocalPlayer.local.gamePlayerID
        guard listeningFor != player else { return }
        listeningFor = player
        GKLocalPlayer.local.register(inviteListener)
    }

    @MainActor
    private static func matchmaker(_ controller: GKMatchmakerViewController?, present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        guard let controller else { throw GameCenterError.matchmakingFailed("No matchmaker") }
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = MatchmakerDelegate(continuation)
            controller.matchmakerDelegate = delegate
            matchmakerDelegate = delegate
            present(controller)
        }
    }

    private nonisolated(unsafe) static var matchmakerDelegate: MatchmakerDelegate?

    /// Walks away from a match that was found but never sat at.
    public static func leave(_ match: GKMatch) {
        match.disconnect()
    }

    /// Stops a search that has not found anybody yet.
    public static func cancelSearch() {
        GKMatchmaker.shared().cancel()
    }

    /// The same, but giving up on the search alone after `seconds`.
    ///
    /// A caller that wants to stop looking after a while used to have to race its own
    /// timer against this call and cancel the matchmaker when the timer won. That cancels
    /// one second too much: `findMatch` returns as soon as a table is made, and the wait
    /// for the other phone to actually arrive happens after it. A timer landing in that
    /// window tore down a match that was moments from starting, which is how one phone
    /// ends up in a game and the other in no game at all.
    ///
    /// So the clock is held here, where the two phases can be told apart: it stops the
    /// moment a table is made, and the arrival is then waited for in full.
    public static func findMatch(players: Int, pool: String?, within seconds: TimeInterval) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = players
        request.maxPlayers = players
        if let pool, !pool.isEmpty { request.playerGroup = group(for: pool) }
        let deadline = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            GKMatchmaker.shared().cancel()
        }
        do {
            let match = try await GKMatchmaker.shared().findMatch(for: request)
            deadline.cancel()
            try await waitUntilFull(match)
            return match
        } catch let error as GKError where error.code == .cancelled {
            deadline.cancel()
            throw GameCenterError.cancelled
        } catch let error as GameCenterError {
            deadline.cancel()
            throw error
        } catch {
            deadline.cancel()
            throw GameCenterError.matchmakingFailed(error.localizedDescription)
        }
    }

    /// A match comes back as soon as it is *made*; the other players can still be on their
    /// way in. Nothing is sent until they have all arrived.
    private static func waitUntilFull(_ match: GKMatch, patience: Int = 600) async throws {
        for _ in 0..<patience where match.expectedPlayerCount > 0 {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard match.expectedPlayerCount == 0 else {
            match.disconnect()
            throw GameCenterError.matchmakingFailed("Not everyone arrived")
        }
    }

    /// A pool name, folded to a group number. Case and spacing do not matter, so
    /// "Nonna 7" and "NONNA7" are the same pool.
    public static func group(for pool: String) -> Int {
        let folded = pool.lowercased().filter { !$0.isWhitespace }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in folded.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        // Zero means "no group" to Game Center, so a pool never lands there.
        return Int(max(1, hash & 0x7FFF_FFFF))
    }
}

public extension GameCenter {
    /// Reports progress on achievements by their App Store Connect ids. Does nothing when
    /// nobody is signed in, and a percentage already reached is Game Center's to remember.
    static func report(_ progress: [String: Double]) {
        guard GKLocalPlayer.local.isAuthenticated, !progress.isEmpty else { return }
        let achievements = progress.map { id, percent in
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = min(100, max(0, percent))
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(achievements) { _ in }
    }
}

// Apple's match and invitation objects are handed between the matchmaker sheet, the
// listener and the table. They are reference types GameKit itself passes around threads;
// nothing here mutates them.
extension GKMatch: @unchecked @retroactive Sendable {}
extension GKInvite: @unchecked @retroactive Sendable {}

#if canImport(UIKit)
import UIKit
public typealias PlatformViewController = UIViewController
#else
import AppKit
public typealias PlatformViewController = NSViewController
#endif

// MARK: - Proving who you are to a server

/// What a server needs to check that a request really comes from this Game Center
/// player: Apple's signature over the player id, our bundle id, a timestamp and a salt,
/// and where to fetch the certificate that verifies it.
public struct GameCenterIdentity: Codable, Sendable, Hashable {
    public let gamePlayerID: String
    public let teamPlayerID: String
    public let bundleID: String
    public let publicKeyURL: String
    /// Base64.
    public let signature: String
    /// Base64.
    public let salt: String
    /// Milliseconds since 1970, as Game Center gives it.
    public let timestamp: UInt64
    public let displayName: String
}

public extension GameCenter {
    /// Asks Game Center to sign for the local player. Requires being signed in.
    static func identity() async throws -> GameCenterIdentity {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { throw GameCenterError.notSignedIn }
        let (url, signature, salt, timestamp) = try await player.fetchItems()
        return GameCenterIdentity(
            gamePlayerID: player.gamePlayerID,
            teamPlayerID: player.teamPlayerID,
            bundleID: Bundle.main.bundleIdentifier ?? "",
            publicKeyURL: url.absoluteString,
            signature: signature.base64EncodedString(),
            salt: salt.base64EncodedString(),
            timestamp: timestamp,
            displayName: player.displayName
        )
    }
}

private extension GKLocalPlayer {
    func fetchItems() async throws -> (URL, Data, Data, UInt64) {
        try await withCheckedThrowingContinuation { continuation in
            fetchItems(forIdentityVerificationSignature:) { url, signature, salt, timestamp, error in
                if let url, let signature, let salt {
                    continuation.resume(returning: (url, signature, salt, timestamp))
                } else {
                    continuation.resume(throwing: error ?? GameCenterError.notSignedIn)
                }
            }
        }
    }
}
