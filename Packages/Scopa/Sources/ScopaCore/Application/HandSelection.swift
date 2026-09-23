/// A player's part-made choice: which card to play, and which table cards to take with it.
/// Lives in the core so the rules around it are tested once, not re-derived in every UI.
public struct HandSelection: Hashable, Sendable {
    public enum Action: Hashable, Sendable {
        /// Nothing on the table matches, so the card goes down.
        case lay
        /// A legal take. `sweeps` means it clears the table and scores a scopa.
        case take(cards: [Card], sweeps: Bool)
        /// Several ways to take, none picked yet.
        case chooseWhatToTake
        /// The picked cards match no legal take.
        case notAllowed

        public var isPlayable: Bool {
            switch self {
            case .lay, .take: true
            case .chooseWhatToTake, .notAllowed: false
            }
        }
    }

    public private(set) var card: Card?
    public private(set) var chosen: Set<Card>
    /// How much help to give. Changing it mid-round only affects the next pick.
    public var assist: AssistLevel

    public init(assist: AssistLevel = .default) {
        card = nil
        chosen = []
        self.assist = assist
    }

    public var isEmpty: Bool { card == nil }

    public mutating func clear() {
        card = nil
        chosen = []
    }

    /// Picking the same card again clears. A new card pre-fills the take when there is only one way to make it.
    public mutating func select(_ card: Card, on table: [Card]) {
        guard self.card != card else { clear(); return }
        self.card = card
        let options = Rules.captureOptions(for: card, on: table)
        chosen = assist.fillsSingleCapture && options.count == 1 ? Set(options[0]) : []
    }

    /// What tapping a card in hand should do.
    public enum HandTap: Hashable, Sendable {
        /// The card is already picked and allows one move only: the tap sends it.
        case play
        /// Anything else: pick this card up, or put the picked one back down.
        case select
    }

    /// A second tap on the picked card plays it when that card allows exactly one move:
    /// it matches nothing and must be laid, or it has a single take. The tap confirms
    /// something the player can see, and saves the reach to the button, which in landscape
    /// is a column away.
    ///
    /// At every level, because neither move can be the wrong one: a card with one take has
    /// to make it — laying it instead is refused as `captureIsMandatory` — and a card with
    /// none can only go down. Normal is the level that leaves the take to the player, so
    /// nothing is filled in or outlined while the card is merely picked up; the single take
    /// is put together here, at the moment the tap asks for it to be played. Two ways to
    /// take is a choice nobody has made yet, so there the tap puts the card back down.
    public mutating func tapInHand(_ handCard: Card, in view: PlayerView) -> HandTap {
        guard card == handCard, view.isMyTurn else { return .select }
        let options = Rules.captureOptions(for: handCard, on: view.table)
        guard options.count <= 1 else { return .select }
        // Above normal the first tap already filled this in; at normal it is empty until
        // now. Anything else picked is a take the player is still building, and a tap on
        // the card in hand goes back to meaning "put it down".
        let only = options.first.map(Set.init) ?? []
        guard chosen.isEmpty || chosen == only else { return .select }
        var confirmed = self
        confirmed.chosen = only
        guard confirmed.move(in: view) != nil else { return .select }
        self = confirmed
        return .play
    }

    /// The selection that dropping the played card onto `tableCard` would finish, when that
    /// makes a take the rules accept. `nil` while the take is unfinished, such as a sum
    /// needing a second card, so the caller picks the card up and waits for the rest.
    ///
    /// This holds at every level because it never plays anything illegal: it is the gesture
    /// being taken at its word, not the interface doing the player's arithmetic.
    public func completing(with tableCard: Card, in view: PlayerView) -> HandSelection? {
        guard let card, view.table.contains(tableCard) else { return nil }
        var attempt = self
        if !attempt.chosen.contains(tableCard) { attempt.toggle(tableCard, on: view.table) }
        let options = Rules.captureOptions(for: card, on: view.table)
        guard options.contains(where: { Set($0) == attempt.chosen }) else { return nil }
        return attempt
    }

    /// Adds or removes a table card. Beginners can only touch cards a legal take could
    /// include, and a card already in the take always comes back out — at every level, and
    /// whether the take it leaves behind is finished or not.
    ///
    /// Below normal a finished take plays itself, so a tap on a card the take already holds
    /// used to mean "send it": undoing the take the interface had filled in was thought to
    /// leave a beginner with a dead button. It left them with worse. A take filled in for
    /// them had no way out at all — every card in it, and the card in hand, played the
    /// move — so a player who wanted the other take, or who had simply touched the wrong
    /// card, had to watch it go. The button says what an unfinished take is waiting for,
    /// which is a better answer than not letting go.
    public mutating func toggle(_ tableCard: Card, on table: [Card]) {
        guard card != nil, table.contains(tableCard) else { return }
        if assist.highlightsCaptures, !capturable(on: table).contains(tableCard) { return }
        if chosen.contains(tableCard) { chosen.remove(tableCard) } else { chosen.insert(tableCard) }
    }

    /// Table cards to outline. Empty above beginner, so nothing is given away.
    public func capturable(on table: [Card]) -> Set<Card> {
        guard assist.highlightsCaptures, let card else { return [] }
        return Set(Rules.captureOptions(for: card, on: table).joined())
    }

    public func action(in view: PlayerView) -> Action? {
        guard let card else { return nil }
        let taken = chosen.sorted { ($0.rank, $0.suit.rawValue) < ($1.rank, $1.suit.rawValue) }
        let options = Rules.captureOptions(for: card, on: view.table)

        // Only a beginner is stopped from laying a card that has to take. Above that the
        // player is allowed the mistake and hears about it from the rules, which is safe
        // now that the refusal is shown rather than vanishing in silence.
        if chosen.isEmpty {
            guard assist.checksBeforeSending else { return .lay }
            return options.isEmpty ? .lay : .chooseWhatToTake
        }

        // Above beginner, whatever is picked is sent and the rules answer.
        guard assist.checksBeforeSending else {
            return .take(cards: taken, sweeps: view.isScopa(taking: taken))
        }
        guard options.contains(where: { Set($0) == chosen }) else { return .notAllowed }
        return .take(cards: taken, sweeps: view.isScopa(taking: taken))
    }

    /// The move to send, or nil while the choice is unfinished or illegal.
    public func move(in view: PlayerView) -> Move? {
        guard let card, let action = action(in: view), action.isPlayable else { return nil }
        if case .take(let cards, _) = action {
            return Move(seat: view.seat, card: card, captures: cards)
        }
        return Move(seat: view.seat, card: card)
    }
}

