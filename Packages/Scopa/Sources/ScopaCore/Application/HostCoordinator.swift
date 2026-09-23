/// Runs the lobby and the game on the host device, and keeps every guest's view in sync.
public actor HostCoordinator {
    public enum HostError: Error, Sendable {
        case cannotStart
        case gameAlreadyRunning
        case noGame
    }

    public let updates: AsyncStream<TableUpdate>
    public private(set) var lobby: Lobby
    public private(set) var session: GameSession?

    private let transport: any GameTransport
    private let advertising: (any TableAdvertising)?
    private let continuation: AsyncStream<TableUpdate>.Continuation
    private var rng: any RandomNumberGenerator & Sendable
    private var pump: Task<Void, Never>?
    /// Seats whose device has gone. The host plays for them so the table never stalls.
    private var absent: Set<PlayerID> = []
    /// Seats the machine plays on purpose. Filled from the lobby, played by the host.
    private var bots: Set<PlayerID> = []
    private let bot: Bot
    /// How long a bot waits before playing, so the table can watch its move land.
    private let pace: Duration

    public init(
        transport: any GameTransport,
        advertising: (any TableAdvertising)? = nil,
        teams: Bool = false,
        strength: BotStrength = BotLevel.default.strength,
        pace: Duration = .milliseconds(2600),
        rng: any RandomNumberGenerator & Sendable = SeededGenerator(seed: UInt64.random(in: .min ... .max))
    ) {
        self.bot = Bot(strength: strength)
        self.transport = transport
        self.advertising = advertising
        self.lobby = Lobby(host: transport.localPlayer, teams: teams)
        self.pace = pace
        self.rng = rng
        (updates, continuation) = UpdateStream.make()
    }

    public var localPlayer: Player { transport.localPlayer }


    /// Starts listening to guests and advertising the table.
    public func start() {
        guard pump == nil else { return }
        advertising?.advertise(lobby)
        continuation.yield(.lobby(lobby))
        pump = Task { [transport] in
            for await envelope in transport.incoming { await self.handle(envelope) }
        }
    }

    public func stop() {
        pump?.cancel()
        pump = nil
        advertising?.stopAdvertising()
        continuation.finish()
    }

    // MARK: Lobby

    /// The host's own reaction, sent to everyone including this device.
    public func react(_ reaction: Reaction) async {
        await relay(reaction, from: localPlayer.id)
    }

    private func relay(_ reaction: Reaction, from player: PlayerID) async {
        continuation.yield(.reacted(player: player, reaction: reaction))
        try? await transport.send(.reacted(player: player, reaction: reaction), to: .all)
    }

    public func setTurnClock(_ clock: TurnClock) async {
        guard session == nil else { return }
        lobby.turnClock = clock
        await publishLobby()
    }

    public func setTargetScore(_ score: Int) async {
        guard session == nil, GameConfiguration.targetRange.contains(score) else { return }
        lobby.targetScore = score
        await publishLobby()
    }

    public func setPrimiera(_ rule: PrimieraRule) async {
        guard session == nil else { return }
        lobby.primiera = rule
        await publishLobby()
    }

    public func setTies(_ rule: TieRule) async {
        guard session == nil else { return }
        lobby.ties = rule
        await publishLobby()
    }

    /// Names the game for the ladder before it is dealt. Guests read it off the lobby.
    public func setGameID(_ id: String) async {
        guard session == nil else { return }
        lobby.gameID = id
        await publishLobby()
    }

    /// Seats declared partners opposite each other, host first: whoever came with the host
    /// takes seat two, and the other pair the seats between. A four-hand table with two
    /// duos at it; anybody who came alone simply partners whoever is left.
    public func seatPartners() async {
        guard session == nil, lobby.players.count == 4 else { return }
        let host = lobby.host
        var rest = lobby.players.filter { $0.id != host.id }
        let partnerIndex = rest.firstIndex { $0.partner == host.id.rawValue || host.partner == $0.id.rawValue } ?? 0
        let partner = rest.remove(at: partnerIndex)
        lobby.players = [host, rest[0], partner, rest[1]]
        await publishLobby()
    }

    public func setTeams(_ teams: Bool) async {
        guard session == nil else { return }
        lobby.teams = teams
        await publishLobby()
    }

    /// Who sits down when the machine does, absent a cast from the app.
    public static let houseBots = ["Hugo", "Laurence", "Lucas"]

    private static func botID(_ index: Int) -> PlayerID { PlayerID(rawValue: "bot-\(index)") }

    /// Seats bots until the table has `seats` players, named in order from `names`.
    /// Only before the game starts; the bots are then played by this device.
    public func addBots(upTo seats: Int, names: [String] = houseBots) async {
        guard session == nil else { return }
        while lobby.players.count < seats, seatBot(names: names) {}
        await publishLobby()
    }

    /// Seats one more bot, under the first of `names` whose seat is free: what the host
    /// taps on an empty chair while the table is being set.
    public func addBot(names: [String] = houseBots) async {
        guard seatBot(names: names) else { return }
        await publishLobby()
    }

    /// Sends a bot away again, so the chair is there for somebody real. Only a bot can be
    /// shown the door this way; a person leaves on their own.
    public func removeBot(_ id: PlayerID) async {
        guard session == nil, bots.contains(id) else { return }
        lobby.players.removeAll { $0.id == id }
        bots.remove(id)
        await publishLobby()
    }

    /// Takes one seat, without telling the table. False when the table is full, the game
    /// has started, or every name in the cast is already sitting down.
    private func seatBot(names: [String]) -> Bool {
        guard session == nil, !lobby.isFull else { return false }
        guard let index = names.indices.first(where: { index in
            !lobby.players.contains { $0.id == Self.botID(index) }
        }) else { return false }
        lobby.players.append(Player(id: Self.botID(index), name: names[index], isBot: true))
        bots.insert(Self.botID(index))
        return true
    }

    private func publishLobby() async {
        advertising?.advertise(lobby)
        continuation.yield(.lobby(lobby))
        try? await transport.send(.lobby(lobby), to: .all)
    }

    // MARK: Game

    public func startGame() async throws {
        guard session == nil else { throw HostError.gameAlreadyRunning }
        guard lobby.canStart,
              let config = try? GameConfiguration(players: lobby.players, teams: lobby.teams, targetScore: lobby.targetScore,
                                                  turnClock: lobby.turnClock, primiera: lobby.primiera,
                                                  ties: lobby.ties)
        else { throw HostError.cannotStart }
        advertising?.stopAdvertising()
        let session = GameSession(configuration: config, rng: rng)
        self.session = session
        await broadcast(events: session.startRound())
        await coverAbsentSeats()
    }

    /// The same table again once a game has ended: the seats stay, the scores go back to
    /// nothing and the cards are dealt afresh. Guests find out when a new view arrives.
    /// `gameID` names the new game for the ladder, the way `setGameID` names the first one.
    /// The ladder settles a game once, so a second report under the first game's name would
    /// move nothing and show the first game's points again.
    public func playAgain(gameID: String? = nil) async throws {
        guard let session else { throw HostError.noGame }
        guard case .finished = await session.state.phase else { throw HostError.gameAlreadyRunning }
        self.session = nil
        // Before the deal, so a guest reads the new name off the lobby with the new hand.
        if let gameID {
            lobby.gameID = gameID
            await publishLobby()
        }
        try await startGame()
    }

    /// Plays when this device's own seat runs out of time. Other seats are played by their own device.
    public func playAutomatically() async {
        guard let session else { return }
        let current = await session.state
        guard let seat = current.configuration.seat(of: localPlayer.id),
              current.round?.turnSeat == seat,
              let move = Rules.automaticMove(in: current)
        else { return }
        if let events = try? await session.play(move) { await broadcast(events: events) }
    }

    /// Deals the next round after a scoreboard pause.
    public func dealNextRound() async throws {
        guard let session else { throw HostError.noGame }
        await broadcast(events: session.startRound())
        await coverAbsentSeats()
    }

    /// The host's own move.
    public func play(_ card: Card, capturing captures: [Card] = []) async throws {
        guard let session else { throw HostError.noGame }
        let events: [GameEvent]
        do {
            events = try await session.play(card, capturing: captures, by: localPlayer.id)
        } catch {
            // Guests are told when their move is refused; the host has to tell itself.
            continuation.yield(.rejected(error))
            throw error
        }
        await broadcast(events: events)
        await coverAbsentSeats()
    }

    // MARK: Incoming

    private func handle(_ envelope: Envelope) async {
        switch envelope.message {
        case .join(let player): await seat(player)
        case .leave(let id): await remove(id)
        case .play(let move): await play(move, from: envelope.from)
        case .react(let reaction): await relay(reaction, from: envelope.from)
        case .lobby, .joinRefused, .view, .events, .rejected, .playerLeft, .reacted, .record:
            return
        }
    }

    private func seat(_ player: Player) async {
        // Someone coming back to a seat they already hold picks it up again, whether or not
        // the table had noticed them go. A connection that drops and returns inside a turn
        // never looked absent from here.
        if session != nil, lobby.players.contains(where: { $0.id == player.id }) {
            absent.remove(player.id)
            await welcomeBack(player.id)
            return
        }
        makeRoomForAPerson(over: player)
        guard session == nil, !lobby.isFull, !lobby.players.contains(where: { $0.id == player.id }) else {
            try? await transport.send(.joinRefused, to: .player(player.id))
            return
        }
        lobby.players.append(player)
        await publishLobby()
    }

    /// A person who turns up is worth more than a bot, so the last bot seated gives up its
    /// chair rather than the table turning a friend away.
    private func makeRoomForAPerson(over player: Player) {
        guard session == nil, lobby.isFull, !lobby.players.contains(where: { $0.id == player.id }),
              let seated = lobby.players.last(where: { bots.contains($0.id) }) else { return }
        lobby.players.removeAll { $0.id == seated.id }
        bots.remove(seated.id)
    }

    private func play(_ move: Move, from sender: PlayerID) async {
        guard let session else { return }
        guard await session.state.configuration.seat(of: sender) == move.seat else {
            try? await transport.send(.rejected(.notYourTurn(expectedSeat: move.seat)), to: .player(sender))
            return
        }
        do {
            await broadcast(events: try await session.play(move))
            await coverAbsentSeats()
        } catch {
            try? await transport.send(.rejected(error), to: .player(sender))
        }
    }

    private func remove(_ id: PlayerID) async {
        if session == nil {
            lobby.players.removeAll { $0.id == id }
            await publishLobby()
        } else {
            absent.insert(id)
            continuation.yield(.playerLeft(id))
            try? await transport.send(.playerLeft(id), to: .all)
            await coverAbsentSeats()
        }
    }

    /// Plays every bot seat, and every seat whose device has gone, until the turn reaches
    /// a person who is here. Without this the game stops dead on an empty seat and nobody
    /// can finish the round. Somebody who leaves is simply replaced by the bot: the same
    /// player, the same pace, a machine's hand on their cards until they come back.
    private func coverAbsentSeats() async {
        guard let session, !(absent.isEmpty && bots.isEmpty) else { return }
        while true {
            let current = await session.state
            guard current.phase == .playing,
                  let seat = current.round?.turnSeat,
                  let player = current.configuration.players[safe: seat],
                  bots.contains(player.id) || absent.contains(player.id)
            else { return }
            // A bot seat takes its time so its move can be watched. An empty seat does
            // not: the table has already stalled once waiting on it.
            if bots.contains(player.id) {
                try? await Task.sleep(for: pace)
                guard await session.state == current else { return }
            }
            guard let move = bot.move(for: current.view(forSeat: seat), using: &rng),
                  let events = try? await session.play(move)
            else { return }
            await broadcast(events: events)
        }
    }

    private func welcomeBack(_ id: PlayerID) async {
        guard let session, let view = await session.view(for: id) else { return }
        try? await transport.send(.lobby(lobby), to: .player(id))
        try? await transport.send(.view(view), to: .player(id))
    }

    /// Sends each player their own view, and the events to everyone.
    private func broadcast(events: [GameEvent]) async {
        guard let session else { return }
        let views = await session.views()
        for (id, view) in views where id != localPlayer.id {
            try? await transport.send(.view(view), to: .player(id))
        }
        if let mine = views[localPlayer.id] { continuation.yield(.view(mine)) }
        guard !events.isEmpty else { return }
        try? await transport.send(.events(events), to: .all)
        continuation.yield(.events(events))

        // The game is over, so the cards are no secret any more: everyone gets the whole
        // record to read back, after the events that ended it.
        guard events.contains(where: { if case .gameEnded = $0 { true } else { false } }) else { return }
        let record = await session.record
        try? await transport.send(.record(record), to: .all)
        continuation.yield(.record(record))
    }
}
