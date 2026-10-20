import Foundation
import Observation
import ScopaCore

/// One quick game played with `Scatouch` on: the whole deal, read off the engine after every
/// update, and the liberties the mode takes with it. With `playsForBots` on, each bot waits
/// for its move to be made for it or for the player to let it go.
@MainActor
@Observable
final class ScatouchTable {
    /// The game as the engine holds it, hands and stock included. Nil until the first read.
    private(set) var state: GameState?
    /// The bot let off to play its own move this turn. Its cards leave the bottom of the
    /// screen the moment the button is pressed, not when the move lands.
    private(set) var freedSeat: Int?
    /// The bots wait for the player to make their moves. Remembered in `Scatouch`.
    private(set) var playsForBots: Bool
    let bots: Set<Int>
    /// The seat this phone plays, whose cards may be swapped.
    let homeSeat: Int

    @ObservationIgnored private let table: HotSeatTable
    @ObservationIgnored private var reading: Task<Void, Never>?

    init(table: HotSeatTable, bots: Set<Int>, homeSeat: Int) {
        self.table = table
        self.bots = bots
        self.homeSeat = homeSeat
        playsForBots = Scatouch.shared.playsForBots
        Task { [playsForBots] in await table.steer(playsForBots ? bots : []) }
    }

    /// Takes the bots' moves into the player's hands, or gives them back. A bot already
    /// thinking when this is turned on stops and waits.
    func playForBots(_ on: Bool) {
        playsForBots = on
        Scatouch.shared.playsForBots = on
        freedSeat = nil
        Task { [table, bots] in await table.steer(on ? bots : []) }
    }

    /// Reads the engine again. Called for every view the table publishes, well before a bot
    /// has waited out its pace and moved again.
    func refresh() {
        reading?.cancel()
        reading = Task { [table] in
            let state = await table.state
            guard !Task.isCancelled else { return }
            self.state = state
            if state.round?.turnSeat != freedSeat { freedSeat = nil }
        }
    }

    /// What `seat` is holding, when it agrees with the count the table shows for it.
    func hand(ofSeat seat: Int, in view: PlayerView) -> [Card]? {
        guard let held = state?.round?.hands[safe: seat],
              let count = view.opponents.first(where: { $0.seat == seat })?.cardsInHand else { return nil }
        // A read a beat behind the view still holds the card just played, which the view
        // already has on the cloth or in a pile.
        let shown = Set(view.table + view.capturedBySide.flatMap { $0 })
        let hand = held.filter { !shown.contains($0) }
        return hand.count == count ? hand : nil
    }

    /// The bot on the move, seen from its own chair, while the table waits for its move to be
    /// made for it. Nil whenever the read is behind the table on screen.
    func puppet(over view: PlayerView) -> PlayerView? {
        guard playsForBots, let state, let round = state.round, state.phase == .playing,
              let seat = view.turnSeat, seat == round.turnSeat, bots.contains(seat), seat != freedSeat,
              round.table == view.table else { return nil }
        return state.view(forSeat: seat)
    }

    /// Hands the bot on the move its own turn back.
    func letBotPlay() {
        guard let seat = state?.round?.turnSeat, bots.contains(seat) else { return }
        freedSeat = seat
        Task { [table] in await table.letSteeredSeatPlay() }
    }

    /// Trades a card in this phone's hand for one still in the stock.
    func swap(_ held: Card, for wanted: Card) {
        Task { [table, homeSeat] in try? await table.swap(held, inHandOf: homeSeat, for: wanted) }
    }
}
