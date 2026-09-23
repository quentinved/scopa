import ScopaCore
import SwiftUI

extension Audio {
    /// Everything the table says about one played card.
    ///
    /// The sounds are layered, not chosen between: the card lands first and the
    /// consequence follows a fraction later. Anything from across the table is
    /// quieter than the same thing in your own hand.
    /// `cheer` is what the player on this phone bought. It is only ever heard for their
    /// own sweeps: a cheer is your voice, so the table across from you keeps the house one.
    func announce(_ move: TableStore.Play, mine: Bool, cheer: Cheer = .casa) {
        play(mine ? (move.captures.isEmpty ? .play : .take) : .theirs)

        if move.sweeps {
            // A scopa speaks alone, without the big-take sound under it.
            play(mine ? cheer.sound : .scopa, after: .milliseconds(140))
        } else if move.captures.count >= 3 {
            play(.sweep, gain: mine ? 1 : 0.7, after: .milliseconds(50))
        }

        if move.tookSettebello {
            play(.settebello, gain: mine ? 1 : 0.85, after: .milliseconds(mine ? 100 : 150))
        }
    }
}

/// Everything the table says out loud, in one modifier rather than five lines of
/// `TableScreen.body`, which is already at the type checker's budget.
struct TableSounds: ViewModifier {
    let store: TableStore
    let view: PlayerView?
    /// The card lifted out of the hand, if any.
    let picked: Card?

    func body(content: Content) -> some View {
        content
            .onChange(of: store.lastPlay?.id) { _, _ in
                guard let play = store.lastPlay, let view else { return }
                Audio.shared.announce(play, mine: play.seat == view.seat, cheer: store.cheer)
            }
            .sound(trigger: picked) { _, card in card == nil ? nil : .pick }
            // Three more cards each, mid-round, which arrives as a notice.
            .sound(trigger: store.notice) { _, notice in notice == .dealt ? .deal : nil }
            // The deal that starts a hand arrives as a new round instead.
            .task(id: view?.roundNumber) { Audio.shared.play(.deal) }
            .onChange(of: view?.isMyTurn == true) { was, now in
                if now, !was { Audio.shared.nudge() }
            }
    }
}

extension View {
    /// Applies the table's sounds.
    func tableSounds(_ store: TableStore, view: PlayerView?, picked: Card?) -> some View {
        modifier(TableSounds(store: store, view: view, picked: picked))
    }
}
