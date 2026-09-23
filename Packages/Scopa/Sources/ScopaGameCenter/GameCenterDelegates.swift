import Foundation
import GameKit

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
        box.resume(.success(match))
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

    init(_ handler: @escaping @MainActor @Sendable (GKInvite) -> Void) {
        self.handler = handler
    }

    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        let handler = self.handler
        Task { @MainActor in handler(invite) }
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

    func resume(_ result: Result<T, Error>) {
        let taken: CheckedContinuation<T, Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        taken?.resume(with: result)
    }
}
