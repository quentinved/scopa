import Foundation
import GameKit
import ScopaCore

// Delegate objects Game Center's view controllers and listeners hand their answers to.
// Each one bridges a callback to an async continuation and is held by `GameCenter`.

/// Takes a Game Center sheet down, from the delegate callback that carries it.
///
/// GameKit calls these delegate methods on the main thread — it is handing back its own view
/// controller for us to dismiss — but the protocols declare them nonisolated, so the compiler
/// cannot see that and warns about every `dismiss`. Said here once rather than at four call
/// sites, and *said* rather than hopped: dismissing inside a `Task { @MainActor }` would leave
/// the sheet standing for a turn of the run loop after the answer it came for was given, and
/// would have to smuggle a non-Sendable controller across the hop to do it.
private func takeDown(_ controller: PlatformViewController) {
    MainActor.assumeIsolated {
        #if canImport(UIKit)
        controller.dismiss(animated: true)
        #else
        controller.dismiss(nil)
        #endif
    }
}

/// Resolves the matchmaker sheet into a match, a cancellation or an error, exactly once,
/// and takes the sheet down on the way.
final class MatchmakerDelegate: NSObject, GKMatchmakerViewControllerDelegate {
    private let box: OnceBox<GKMatch>

    init(_ continuation: CheckedContinuation<GKMatch, Error>) {
        box = OnceBox(continuation)
    }

    func matchmakerViewControllerWasCancelled(_ controller: GKMatchmakerViewController) {
        takeDown(controller)
        box.resume(.failure(GameCenterError.cancelled))
    }

    func matchmakerViewController(_ controller: GKMatchmakerViewController, didFailWithError error: Error) {
        takeDown(controller)
        box.resume(.failure(GameCenterError.matchmakingFailed(error.localizedDescription)))
    }

    func matchmakerViewController(_ controller: GKMatchmakerViewController, didFind match: GKMatch) {
        takeDown(controller)
        // Nobody is waiting for it any more: a match that will never be sat at is let go
        // rather than left open, where the other phone would wait at it.
        if !box.resume(.success(match)) { match.disconnect() }
    }

    /// Whether the sheet has said anything yet.
    var isAnswered: Bool { box.isDone }

    /// Answers for a sheet that will not: one that never got on screen, left it without a
    /// word, or was replaced by another before it finished.
    func give(up error: Error) {
        box.resume(.failure(error))
    }
}

/// Takes Apple's Game Center page down when the player closes it.
final class DismissingDelegate: NSObject, GKGameCenterControllerDelegate {
    private let done: (@MainActor @Sendable () -> Void)?

    init(_ done: (@MainActor @Sendable () -> Void)? = nil) {
        self.done = done
    }

    func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
        takeDown(controller)
        guard let done else { return }
        Task { @MainActor in done() }
    }
}

final class InviteListener: NSObject, GKLocalPlayerListener {
    private let handler: @MainActor @Sendable (GKInvite) -> Void
    private let requested: (@MainActor @Sendable ([GKPlayer]) -> Void)?

    init(_ handler: @escaping @MainActor @Sendable (GKInvite) -> Void,
         requested: (@MainActor @Sendable ([GKPlayer]) -> Void)? = nil) {
        self.handler = handler
        self.requested = requested
    }

    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        let handler = self.handler
        Task { @MainActor in handler(invite) }
    }

    /// The player picked friends in the Games app and chose to play Scopa with them.
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        guard let requested else { return }
        // GameKit's players are handed across as they are, the way the invitation is.
        nonisolated(unsafe) let friends = recipientPlayers
        Task { @MainActor in requested(friends) }
    }
}

/// A continuation that can only be resumed once, however many times Game Center calls
/// its handler.
final class OnceBox<T: Sendable>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    /// Returns whether this was the answer, or one came first.
    @discardableResult
    func resume(_ result: Result<T, Error>) -> Bool {
        let taken: CheckedContinuation<T, Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        taken?.resume(with: result)
        return taken != nil
    }

    var isDone: Bool { lock.withLock { continuation == nil } }
}

/// Everyone waiting on one sign-in, answered together by the one handler Game Center calls.
///
/// Each sign-in is a round, ended by its answer, so a clock kept on one round can never answer
/// the callers of the next.
final class SignInWaiters: @unchecked Sendable {
    private var waiting: [OnceBox<Player>] = []
    private var round = 0
    private let lock = NSLock()

    /// The round, when this is its first caller, which is the one that starts the sign-in.
    /// Nil for a caller joining a round already under way.
    func add(_ box: OnceBox<Player>) -> Int? {
        lock.withLock {
            waiting.append(box)
            return waiting.count == 1 ? round : nil
        }
    }

    func isWaiting(in round: Int) -> Bool {
        lock.withLock { self.round == round && !waiting.isEmpty }
    }

    /// Answers everyone waiting and ends the round. `onlyIn` leaves a later round alone.
    func answer(_ result: Result<Player, Error>, onlyIn only: Int? = nil) {
        let all: [OnceBox<Player>] = lock.withLock {
            guard only == nil || only == round else { return [] }
            defer { waiting = []; round += 1 }
            return waiting
        }
        for box in all { box.resume(result) }
    }
}
