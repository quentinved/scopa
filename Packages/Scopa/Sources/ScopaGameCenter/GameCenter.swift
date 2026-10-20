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
    /// calls it again on every sign-in change.
    ///
    /// Every caller waiting at once is answered by the one handler. Each used to set its own,
    /// and setting a handler replaces the last: an invitation accepted while the ranked button
    /// was still signing in left the first caller waiting on a handler nobody called again.
    public static func signIn(present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> Player {
        if GKLocalPlayer.local.isAuthenticated {
            registerInviteListener()
            return player(for: GKLocalPlayer.local)
        }
        return try await withCheckedThrowingContinuation { continuation in
            signInPresenter = present
            guard let round = signInWaiters.add(OnceBox(continuation)) else { return }
            GKLocalPlayer.local.authenticateHandler = { controller, _ in authenticated(showing: controller) }
            Task { @MainActor in await watchSignIn(round) }
        }
    }

    /// How long a sign-in may go unanswered with Apple's sheet nowhere on screen. Game Center
    /// answers within a second or two, or puts its sheet up and waits for the player, which is
    /// waited out for as long as it is up.
    static let signInPatience: Duration = .seconds(20)
    private nonisolated(unsafe) static weak var signInSheet: PlatformViewController?

    /// Tells everyone waiting on sign-in `round` that it failed, once it has gone unanswered for
    /// `signInPatience` and Apple's sheet is not up. A handler Game Center never calls back,
    /// because its sheet could not be shown or went without a word, otherwise kept every later
    /// caller waiting with it: only the first of a round asks Game Center anything.
    @MainActor
    private static func watchSignIn(_ round: Int) async {
        try? await Task.sleep(for: signInPatience)
        while signInWaiters.isWaiting(in: round), signInSheet?.presentingViewController != nil {
            try? await Task.sleep(for: .seconds(1))
        }
        signInWaiters.answer(.failure(GameCenterError.notSignedIn), onlyIn: round)
    }

    /// Everything a sign-in change means, whoever set the handler: Apple's sheet shown if a
    /// caller can show it, the invitation listener put back, and everyone waiting answered.
    private static func authenticated(showing controller: PlatformViewController?) {
        if let controller {
            // The quiet sign-in has nobody to show it to, and leaves the player signed out.
            guard let present = signInPresenter else { return }
            Task { @MainActor in
                signInSheet = controller
                present(controller)
            }
            return
        }
        guard GKLocalPlayer.local.isAuthenticated else {
            // Signed out, or the sheet turned down. The listener went with the player.
            listeningFor = nil
            signInWaiters.answer(.failure(GameCenterError.notSignedIn))
            if let gone = signedOut { Task { @MainActor in gone() } }
            return
        }
        registerInviteListener()
        announceSignIn()
        signInWaiters.answer(.success(player(for: GKLocalPlayer.local)))
    }

    private static let signInWaiters = SignInWaiters()
    private nonisolated(unsafe) static var signInPresenter: (@MainActor @Sendable (PlatformViewController) -> Void)?

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
    /// `gone` is told when the player turns out to be signed out, in Settings mid-session or
    /// from the start, so nothing goes on acting for an account no longer there.
    public static func signInQuietly(then ready: (@MainActor @Sendable () -> Void)? = nil,
                                     whenSignedOut gone: (@MainActor @Sendable () -> Void)? = nil) {
        signInReady = ready
        signedOut = gone
        guard !GKLocalPlayer.local.isAuthenticated else {
            registerInviteListener()
            announceSignIn()
            return
        }
        guard GKLocalPlayer.local.authenticateHandler == nil else { return }
        GKLocalPlayer.local.authenticateHandler = { controller, _ in authenticated(showing: controller) }
    }

    /// Whoever asked to be told the moment the player turns out to be signed in. Kept here
    /// rather than closed over by one handler, because the sheet's sign-in replaces the
    /// quiet one's handler outright and would otherwise leave the waiting caller waiting.
    private nonisolated(unsafe) static var signInReady: (@MainActor @Sendable () -> Void)?
    private nonisolated(unsafe) static var signedOut: (@MainActor @Sendable () -> Void)?

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

    /// A duo asked for through Apple's invitation sheet: the `friend` picked from Scopa's own
    /// list already named on it, or nobody, so any Game Center friend can be.
    ///
    /// Both ways go through the sheet. The friend picked from the list used to be invited with
    /// no sheet at all, through `GKMatchmaker.findMatch` with the friend as a recipient, and
    /// that was the way that failed: the other phone accepts with Apple's sheet, and a sheet
    /// at one end with the programmatic call at the other is a handshake neither end finishes.
    /// The inviting phone showed nothing but a spinner, gave up after three minutes or when
    /// the Ranked sheet was closed, and the friend who got through after restarting the app
    /// sat at a table nobody was hosting any more. The sheet at both ends is the pairing that
    /// has worked from the first day, and the sheet shows the inviter where the friend is.
    ///
    /// `loadFriends` only answers with friends who already play Scopa, and Apple's friends page
    /// has no way to invite anybody, so the empty sheet is also the one place the rest of the
    /// friend list can be asked to a table.
    ///
    /// Comes back with the match once the friend has said yes. The sheet does the waiting.
    @MainActor
    public static func inviteDuo(_ friend: GKPlayer? = nil,
                                 present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = duoInviteMessage
        // Named on the sheet, which sends the invitation the moment it is up.
        if let friend { request.recipients = [friend] }
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
    /// `naming` puts friends on the sheet already invited: the ones picked in the Games app
    /// before it opened Scopa.
    public static func inviteFriends(players: ClosedRange<Int>, naming friends: [GKPlayer] = [], group: Int? = nil,
                                     fillingWithStrangers: Bool = false,
                                     present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
        request.inviteMessage = "A game of Scopa?"
        if !friends.isEmpty { request.recipients = Array(friends.prefix(players.upperBound - 1)) }
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
        // One sheet at a time, as for every other: an invitation said yes to while this one is
        // up takes it down rather than leaving it over the table that replaced this one.
        putAwaySheet()
        // Cancelling is how this sheet ends even when an invitation went out, so the
        // answer is thrown away either way: kept only if it is the table's own match, and let
        // go otherwise, so no second match is left open beside the table.
        let found = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GKMatch, Error>) in
            let delegate = MatchmakerDelegate(continuation)
            controller.matchmakerDelegate = delegate
            matchmakerDelegate = delegate
            matchmakerSheet = controller
            present(controller)
            // After the sheet is up, the way Apple's own sample does it: this is what tells
            // the sheet it is filling a chair at `match` rather than opening a second table.
            controller.addPlayers(to: match)
            watch(controller, answering: delegate)
        }
        if let found, found !== match { found.disconnect() }
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
    ///
    /// `requested` is handed the friends a player picked in the Games app before choosing to
    /// play Scopa with them, which arrives here rather than as an invitation.
    public static func listenForInvites(_ handler: @escaping @MainActor @Sendable (GKInvite) -> Void,
                                        requested: (@MainActor @Sendable ([GKPlayer]) -> Void)? = nil) {
        // One listener only: a second registered beside the first would accept every invitation twice.
        if let old = inviteListener { GKLocalPlayer.local.unregisterListener(old) }
        inviteListener = InviteListener(handler, requested: requested)
        listeningFor = nil
        registerInviteListener()
    }

    private nonisolated(unsafe) static var inviteListener: InviteListener?

    /// The player the listener is registered for. Game Center lets its listeners go when the
    /// signed-in player changes, so registering again after every sign-in is what keeps
    /// invitations arriving; remembering who it was for is what stops it registering twice.
    private nonisolated(unsafe) static var listeningFor: String?

    /// Registers the invitation listener, if there is one and there is somebody to register
    /// it for. Called after every sign-in, and cheap to call when nothing has changed.
    ///
    /// Taken off first and put back, so a player who signed out and in again, or a different
    /// player on the same phone, is listened for exactly once.
    private static func registerInviteListener() {
        guard let inviteListener, GKLocalPlayer.local.isAuthenticated else { return }
        let player = GKLocalPlayer.local.gamePlayerID
        guard listeningFor != player else { return }
        listeningFor = player
        GKLocalPlayer.local.unregisterListener(inviteListener)
        GKLocalPlayer.local.register(inviteListener)
    }

    @MainActor
    private static func matchmaker(_ controller: GKMatchmakerViewController?, present: @escaping @MainActor @Sendable (PlatformViewController) -> Void) async throws -> GKMatch {
        guard let controller else { throw GameCenterError.matchmakingFailed("No matchmaker") }
        putAwaySheet()
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = MatchmakerDelegate(continuation)
            controller.matchmakerDelegate = delegate
            matchmakerDelegate = delegate
            matchmakerSheet = controller
            present(controller)
            watch(controller, answering: delegate)
        }
    }

    private nonisolated(unsafe) static var matchmakerDelegate: MatchmakerDelegate?
    private nonisolated(unsafe) static weak var matchmakerSheet: GKMatchmakerViewController?

    /// One sheet at a time: an invitation accepted while this phone's own sheet was up used to
    /// leave the first one waiting on an answer that could no longer come.
    @MainActor
    private static func putAwaySheet() {
        matchmakerDelegate?.give(up: GameCenterError.cancelled)
        guard let old = matchmakerSheet, old.presentingViewController != nil else { return }
        #if canImport(UIKit)
        old.dismiss(animated: false)
        #else
        old.dismiss(nil)
        #endif
    }

    /// Takes Apple's invitation sheet down from outside, when what it waited for happened
    /// another way: a friend asked to a room by name who has already walked in by the code.
    @MainActor
    public static func takeDownMatchmaker() {
        matchmakerDelegate?.give(up: GameCenterError.cancelled)
        guard let sheet = matchmakerSheet, sheet.presentingViewController != nil else { return }
        #if canImport(UIKit)
        sheet.dismiss(animated: true)
        #else
        sheet.dismiss(nil)
        #endif
    }

    /// Ends the wait if the sheet never got on screen, or left it without a word.
    ///
    /// Apple's sheet answers through its delegate, and only while it is up. Put on a SwiftUI
    /// sheet that is on its way down, it goes with it and nothing is ever said: the phone that
    /// accepted an invitation sat in "joining" until the app was killed.
    @MainActor
    private static func watch(_ controller: GKMatchmakerViewController, answering delegate: MatchmakerDelegate) {
        Task { @MainActor [weak controller] in
            var shown = false
            for tick in 0... {
                try? await Task.sleep(for: .milliseconds(500))
                guard !delegate.isAnswered else { return }
                // Presented rather than in a window: something Apple puts over its own sheet
                // takes the sheet's view out of the window without the sheet having gone.
                let onScreen = controller?.presentingViewController != nil
                if onScreen { shown = true }
                if shown, !onScreen {
                    return delegate.give(up: GameCenterError.cancelled)
                }
                // Ten seconds and never up: the presenting screen refused it.
                if !shown, tick >= 20 {
                    return delegate.give(up: GameCenterError.matchmakingFailed("The Game Center sheet did not open"))
                }
            }
        }
    }

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
        try await findMatch(players: players...players, pool: pool, within: seconds)
    }

    /// The same, taking any table size in `players`.
    public static func findMatch(players: ClosedRange<Int>, pool: String?, within seconds: TimeInterval) async throws -> GKMatch {
        let request = GKMatchRequest()
        request.minPlayers = players.lowerBound
        request.maxPlayers = players.upperBound
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
    ///
    /// A search called off during the wait leaves the match behind it, so the match is
    /// disconnected here: the caller only ever sees the error, never the match to leave.
    private static func waitUntilFull(_ match: GKMatch, patience: Int = 600) async throws {
        for _ in 0..<patience where match.expectedPlayerCount > 0 {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                match.disconnect()
                throw error
            }
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
