/// One phone on the table. A seat is either a person taking the phone when their turn comes
/// or a bot, mixed freely, so two friends can share a table with a third hand dealt to the
/// machine. A driving adapter over `GameSession`, emitting the same `TableUpdate` stream as
/// the networked host and guest.
public actor HotSeatTable {
    public let updates: AsyncStream<TableUpdate>

    private let session: GameSession
    private let continuation: AsyncStream<TableUpdate>.Continuation
    /// Seats played by the machine.
    private let bots: Set<Int>
    private let bot: Bot
    /// How long a bot waits before playing, so its move can be watched rather than found
    /// already made. Zero in tests.
    ///
    /// It has to outlast the screen's capture animation, which plays a take out card by
    /// card and runs about two and a quarter seconds. A bot playing into that lands its
    /// card while the last one is still in the air.
    private let pace: Duration
    /// The wait after a move that took nothing, which is a much shorter piece of screen
    /// business: the card crosses, is held up to be read, and sits down. Waiting out the
    /// full pace after one of those is the table doing nothing at all.
    private var quickPace: Duration { pace * 3 / 5 }
    /// Whether the move just published took cards, which is what decides between the two.
    private var lastMoveTook = false
    /// Set while a fresh hand is still landing on the table, so the bot about to play waits
    /// out `dealPace` instead of `pace` and the three cards can be watched arriving.
    private var handIsLanding = false
    private var rng: any RandomNumberGenerator & Sendable
    /// The seat whose cards are on screen. It follows the turn between people and stays put
    /// while a bot plays, because a bot's view would put its hand face up on the phone.
    private var shownSeat: Int
    private var isThinking = false
    private var isStopped = false

    public init(
        configuration: GameConfiguration,
        bots: Set<Int> = [],
        strength: BotStrength = BotLevel.default.strength,
        pace: Duration = .milliseconds(2500),
        rng: any RandomNumberGenerator & Sendable = SeededGenerator(seed: UInt64.random(in: .min ... .max))
    ) {
        session = GameSession(configuration: configuration, rng: rng)
        self.bots = bots
        self.bot = Bot(strength: strength)
        self.pace = pace
        self.rng = rng
        self.shownSeat = (0..<configuration.seatCount).first { !bots.contains($0) } ?? 0
        (updates, continuation) = UpdateStream.make()
    }

    /// A table put back the way it was, after the app was closed mid-game and reopened.
    /// Nothing is published until `resume()` is called.
    public init(
        snapshot: Snapshot,
        bots: Set<Int> = [],
        strength: BotStrength = BotLevel.default.strength,
        pace: Duration = .milliseconds(2500),
        rng: any RandomNumberGenerator & Sendable = SeededGenerator(seed: UInt64.random(in: .min ... .max))
    ) {
        session = GameSession(state: snapshot.state, record: snapshot.record, rng: rng)
        self.bots = bots
        self.bot = Bot(strength: strength)
        self.pace = pace
        self.rng = rng
        self.shownSeat = (0..<snapshot.state.configuration.seatCount).first { !bots.contains($0) } ?? 0
        (updates, continuation) = UpdateStream.make()
    }

    public var state: GameState { get async { await session.state } }

    /// Everything needed to set this table up again later: the game as it stands and the
    /// record of how it got there. Small enough to write to disk after every move.
    public struct Snapshot: Hashable, Codable, Sendable {
        public let state: GameState
        public let record: GameRecord

        public init(state: GameState, record: GameRecord) {
            self.state = state
            self.record = record
        }
    }

    public var snapshot: Snapshot {
        get async { Snapshot(state: await session.state, record: await session.record) }
    }

    /// Shows the table as it stands and, if a bot was on the move when the game was put
    /// down, lets it play. The counterpart of `deal()` for a table built from a snapshot.
    public func resume() async {
        await publish([])
        await letBotsPlay()
    }

    /// The wait after a deal: half again as long as an ordinary move, so three cards have
    /// time to arrive and settle before the table moves on. Scaled from `pace` rather than
    /// fixed, so a table paced at zero still runs flat out.
    private var dealPace: Duration { pace + pace / 2 }

    /// Deals the first round, or the next one after a scoreboard pause.
    public func deal() async {
        await publish(session.startRound())
        await letBotsPlay()
    }

    public func play(_ card: Card, capturing captures: [Card] = []) async throws(MoveError) {
        guard let seat = await session.state.round?.turnSeat else { throw .notPlaying }
        let events: [GameEvent]
        do {
            events = try await session.play(Move(seat: seat, card: card, captures: captures))
        } catch {
            // A refusal here never crossed a transport, so nothing else would ever report it
            // and the tap would look like it did nothing at all.
            continuation.yield(.rejected(error))
            throw error
        }
        await publish(events)
        await letBotsPlay()
    }

    /// Plays the best available move for the seat that ran out of time.
    public func playAutomatically() async {
        guard let move = Rules.automaticMove(in: await session.state) else { return }
        if let events = try? await session.play(move) { await publish(events) }
        await letBotsPlay()
    }

    public func stop() {
        isStopped = true
        continuation.finish()
    }

    // MARK: Bots

    /// Plays every bot seat in turn until the cards come back round to a person, or the
    /// round ends. Only ever one of these runs: the pause between moves is a suspension
    /// point, and a second pass started there would deal the same seat two cards.
    private func letBotsPlay() async {
        guard !isThinking else { return }
        isThinking = true
        defer { isThinking = false }

        while !isStopped, let waiting = await seatWaitingOnABot() {
            let wait = handIsLanding ? dealPace : (lastMoveTook ? pace : quickPace)
            handIsLanding = false
            try? await Task.sleep(for: wait)
            guard !isStopped, await seatWaitingOnABot() == waiting else { return }
            guard let move = bot.move(for: await session.state.view(forSeat: waiting), using: &rng),
                  let events = try? await session.play(move)
            else { return }
            await publish(events)
        }
    }

    /// The seat the table is waiting on, when a bot is sitting in it.
    private func seatWaitingOnABot() async -> Int? {
        let state = await session.state
        guard state.phase == .playing, let seat = state.round?.turnSeat, bots.contains(seat) else { return nil }
        return seat
    }

    // MARK: Plumbing

    /// The phone shows the seat about to play, unless a bot is about to play, in which case
    /// it keeps showing whoever passed it last.
    private func publish(_ events: [GameEvent]) async {
        if events.contains(.dealt) { handIsLanding = true }
        lastMoveTook = events.contains { if case .captured = $0 { true } else { false } }
        let state = await session.state
        if let seat = state.round?.turnSeat, !bots.contains(seat) { shownSeat = seat }
        continuation.yield(.view(state.view(forSeat: shownSeat)))
        if !events.isEmpty { continuation.yield(.events(events)) }
        // The end of a round as well as of the game: a one-round table like the daily deal
        // ends there, and wants reading back like any other.
        if state.round != nil, state.phase != .playing { continuation.yield(.record(await session.record)) }
    }
}
