import Testing
@testable import ScopaCore

private func player(_ name: String) -> Player { Player(id: .init(rawValue: name.lowercased()), name: name) }

/// Collects updates from a stream so tests can wait for one without racing.
private actor Recorder {
    private var updates: [TableUpdate] = []
    private var task: Task<Void, Never>?

    func listen(_ stream: AsyncStream<TableUpdate>) {
        task = Task { for await update in stream { self.append(update) } }
    }

    private func append(_ update: TableUpdate) { updates.append(update) }

    /// Waits until an update matches, or gives up. Avoids fixed sleeps in tests.
    func first(where match: @Sendable (TableUpdate) -> Bool, within ticks: Int = 400) async -> TableUpdate? {
        for _ in 0..<ticks {
            if let hit = updates.first(where: match) { return hit }
            await Task.yield()
        }
        return nil
    }

    /// The first match at or after `index`, for a test that walks a stream in order.
    func first(where match: @Sendable (TableUpdate) -> Bool, after index: Int, within ticks: Int = 400) async -> (Int, TableUpdate)? {
        for _ in 0..<ticks {
            if let hit = updates[min(index, updates.count)...].enumerated().first(where: { match($0.element) }) {
                return (index + hit.offset, hit.element)
            }
            await Task.yield()
        }
        return nil
    }

    func all() -> [TableUpdate] { updates }
    func stop() { task?.cancel() }
}

private func isLobby(_ u: TableUpdate) -> Bool { if case .lobby = u { return true }; return false }
private func lobbyOf(_ u: TableUpdate?) -> Lobby? { if case .lobby(let l) = u { return l }; return nil }
private func viewOf(_ u: TableUpdate?) -> PlayerView? { if case .view(let v) = u { return v }; return nil }
private func recordOf(_ u: TableUpdate?) -> GameRecord? { if case .record(let r) = u { return r }; return nil }

@Suite struct Wiring {
    @Test func messagesSurviveEncoding() throws {
        let view = GameState(configuration: try GameConfiguration(players: [player("A"), player("B")])).view(forSeat: 0)
        let cases: [GameMessage] = [
            .join(player("A")),
            .play(Move(seat: 1, card: Card(.seven, of: .coins), captures: [Card(.three, of: .clubs)])),
            .lobby(Lobby(host: player("A"), players: [player("A"), player("B")], teams: false)),
            .view(view),
            .events([.dealt, .scopa(seat: 0), .gameEnded(winnerSide: 1)]),
            .rejected(.captureIsMandatory),
        ]
        for message in cases {
            let envelope = Envelope(from: player("A").id, message: message)
            #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
        }
    }

    @Test func lobbyKnowsWhenItCanStart() {
        var lobby = Lobby(host: player("A"))
        #expect(!lobby.canStart)
        lobby.players.append(player("B"))
        #expect(lobby.canStart && !lobby.isFull)
        lobby.teams = true
        #expect(!lobby.canStart)
        lobby.players += [player("C"), player("D")]
        #expect(lobby.canStart && lobby.isFull)
    }
}

@Suite struct HostAndGuests {
    /// Builds a host plus `guestNames.count` guests on one loopback network, all started.
    private static func table(guests guestNames: [String], teams: Bool = false, seed: UInt64 = 5) async -> (HostCoordinator, Recorder, [(GuestClient, Recorder)]) {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), teams: teams, rng: SeededGenerator(seed: seed))
        let hostRecorder = Recorder()
        await hostRecorder.listen(host.updates)
        await host.start()

        var guests: [(GuestClient, Recorder)] = []
        for name in guestNames {
            let client = GuestClient(transport: network.transport(for: player(name)))
            let recorder = Recorder()
            await recorder.listen(client.updates)
            await client.start()
            try? await client.join()
            guests.append((client, recorder))
        }
        return (host, hostRecorder, guests)
    }

    @Test func guestsJoinAndSeeTheLobby() async {
        let (host, _, guests) = await Self.table(guests: ["Bea", "Caro"])
        let seen = lobbyOf(await guests[1].1.first { u in (lobbyOf(u)?.players.count ?? 0) == 3 })
        #expect(seen?.players.map(\.name) == ["Host", "Bea", "Caro"])
        #expect(await host.lobby.players.count == 3)
        await host.stop()
    }

    @Test func aFifthPlayerIsRefused() async {
        let (host, _, guests) = await Self.table(guests: ["Bea", "Caro", "Dino", "Elio"])
        let refused = await guests[3].1.first { if case .joinRefused = $0 { return true }; return false }
        #expect(refused != nil)
        #expect(await host.lobby.players.count == 4)
        await host.stop()
    }

    @Test func leavingTheLobbyFreesTheSeat() async {
        let (host, hostRecorder, guests) = await Self.table(guests: ["Bea", "Caro"])
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 3 }
        try? await guests[0].0.leave()
        let after = lobbyOf(await hostRecorder.first { u in
            guard let lobby = lobbyOf(u) else { return false }
            return lobby.players.count == 2 && !lobby.players.contains { $0.name == "Bea" }
        })
        #expect(after?.players.map(\.name) == ["Host", "Caro"])
        await host.stop()
    }

    @Test func everyoneGetsOnlyTheirOwnHand() async throws {
        let (host, hostRecorder, guests) = await Self.table(guests: ["Bea", "Caro"])
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 3 }
        try await host.startGame()

        let hostView = viewOf(await hostRecorder.first { viewOf($0) != nil })
        let beaView = viewOf(await guests[0].1.first { viewOf($0) != nil })
        #expect(hostView?.seat == 0 && beaView?.seat == 1)
        #expect(hostView?.hand.count == 3 && beaView?.hand.count == 3)
        let hostHand: Set<Card> = Set(hostView?.hand ?? [])
        let beaHand: Set<Card> = Set(beaView?.hand ?? [])
        #expect(hostHand.isDisjoint(with: beaHand))
        // A guest only ever learns how many cards others hold.
        #expect(beaView?.opponents.allSatisfy { $0.cardsInHand == 3 } == true)
        #expect(beaView?.table.count == 4)
        await host.stop()
    }

    @Test func aGuestPlaysAndEveryoneSeesIt() async throws {
        let (host, hostRecorder, guests) = await Self.table(guests: ["Bea"])
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 2 }
        try await host.startGame()

        // Seat 1 leads, so Bea plays first.
        let view = viewOf(await guests[0].1.first { viewOf($0)?.isMyTurn == true })!
        let card = view.hand[0]
        let capture = Rules.captureOptions(for: card, on: view.table).first ?? []
        try await guests[0].0.play(card, capturing: capture)

        let hostAfter = viewOf(await hostRecorder.first { viewOf($0)?.isMyTurn == true })
        #expect(hostAfter?.opponents.first?.cardsInHand == 2)
        let tableHasCard = hostAfter?.table.contains(card) ?? false
        #expect(capture.isEmpty ? tableHasCard : !tableHasCard)
        await host.stop()
    }

    @Test func playingOutOfTurnIsRejectedAndChangesNothing() async throws {
        let (host, hostRecorder, guests) = await Self.table(guests: ["Bea", "Caro"])
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 3 }
        try await host.startGame()

        // Seat 1 leads, so Caro at seat 2 is out of turn.
        let caro = viewOf(await guests[1].1.first { viewOf($0) != nil })!
        #expect(!caro.isMyTurn)
        try await guests[1].0.play(caro.hand[0])

        let rejection = await guests[1].1.first { if case .rejected = $0 { return true }; return false }
        #expect(rejection != nil)
        let stillSeatOne = await host.session?.state.round?.turnSeat
        #expect(stillSeatOne == 1)
        await host.stop()
    }

    @Test func teamsRequireFourPlayers() async {
        let (host, hostRecorder, _) = await Self.table(guests: ["Bea"], teams: true)
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 2 }
        await #expect(throws: HostCoordinator.HostError.cannotStart) { try await host.startGame() }
        await host.stop()
    }

    @Test func aDroppedGuestIsReportedToEveryone() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")))
        let hostRecorder = Recorder()
        await hostRecorder.listen(host.updates)
        await host.start()

        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        await bea.start()
        try await bea.join()
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 2 }

        network.disconnect(player("Bea").id)
        let gone = lobbyOf(await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 1 })
        #expect(gone?.players.map(\.name) == ["Host"])
        await host.stop()
    }
}

@Suite struct HotSeat {
    @Test func theDeviceAlwaysShowsTheSeatToPlay() async throws {
        let players = [player("A"), player("B"), player("C")]
        let table = HotSeatTable(configuration: try GameConfiguration(players: players), rng: SeededGenerator(seed: 3))
        let recorder = Recorder()
        await recorder.listen(table.updates)
        await table.deal()

        let first = viewOf(await recorder.first { viewOf($0) != nil })!
        #expect(first.seat == 1 && first.isMyTurn && first.hand.count == 3)

        try await table.play(first.hand[0], capturing: Rules.captureOptions(for: first.hand[0], on: first.table).first ?? [])
        let second = viewOf(await recorder.first { viewOf($0)?.seat == 2 })
        #expect(second?.isMyTurn == true)
        await table.stop()
    }

    @Test func playingIntoAFinishedRoundThrows() async throws {
        let table = HotSeatTable(configuration: try GameConfiguration(players: [player("A"), player("B")]))
        await #expect(throws: MoveError.notPlaying) { try await table.play(Card(.ace, of: .coins)) }
        await table.stop()
    }

    /// A refused move on this device never crosses a transport, so unless the table says so
    /// itself nothing reports it and the tap looks like it simply did nothing.
    @Test func arefusedMoveIsReported() async throws {
        let players = [player("A"), player("B")]
        let table = HotSeatTable(configuration: try GameConfiguration(players: players), rng: SeededGenerator(seed: 3))
        let recorder = Recorder()
        await recorder.listen(table.updates)
        await table.deal()

        let view = viewOf(await recorder.first { viewOf($0) != nil })!
        // Take a card that is on the table but that this card cannot legally take.
        let card = try #require(view.hand.first { Rules.captureOptions(for: $0, on: view.table).isEmpty })
        let wrong = try #require(view.table.first)
        await #expect(throws: MoveError.invalidCapture) { try await table.play(card, capturing: [wrong]) }

        let rejection = await recorder.first { if case .rejected = $0 { return true } else { return false } }
        #expect(rejection != nil)
        await table.stop()
    }

    /// The app closed mid-game and opened again: a table rebuilt from a snapshot shows the
    /// same cards, takes up from the same seat, and the record still replays to that state.
    @Test func aTableRebuiltFromASnapshotCarriesOn() async throws {
        let players = [player("A"), player("B")]
        let table = HotSeatTable(configuration: try GameConfiguration(players: players), bots: [1],
                                 pace: .zero, rng: SeededGenerator(seed: 5))
        let recorder = Recorder()
        await recorder.listen(table.updates)
        await table.deal()
        let before = viewOf(await recorder.first { viewOf($0)?.isMyTurn == true })!
        try await table.play(before.hand[0], capturing: Rules.captureOptions(for: before.hand[0], on: before.table).first ?? [])
        // Wait for the bot to answer, so the snapshot is taken between two human turns.
        let mine = viewOf(await recorder.first { viewOf($0)?.isMyTurn == true && viewOf($0)?.hand.count == 2 })!
        let snapshot = await table.snapshot
        await table.stop()

        let again = HotSeatTable(snapshot: snapshot, bots: [1], pace: .zero)
        let second = Recorder()
        await second.listen(again.updates)
        await again.resume()
        let after = viewOf(await second.first { viewOf($0) != nil })!
        #expect(after.hand == mine.hand && after.table == mine.table && after.isMyTurn)
        #expect(snapshot.record.replay().final == snapshot.state)

        // And it plays on to the end of the game from there, legally.
        var view = after
        var cursor = 0
        while !view.isFinished {
            if view.isMyTurn, let card = view.hand.first {
                try await again.play(card, capturing: Rules.captureOptions(for: card, on: view.table).first ?? [])
            } else if case .roundOver = view.phase {
                await again.deal()
            }
            let previous = view
            let (index, update) = try #require(await second.first(where: { viewOf($0) != nil && viewOf($0) != previous }, after: cursor))
            cursor = index + 1
            view = viewOf(update)!
        }
        await again.stop()
    }
}

/// The assisted flow, which is what Beginner gives you.
@Suite struct Selecting {
    private static func view(hand: [Card], table: [Card], stock: Int = 10, opponentCards: Int = 3) throws -> PlayerView {
        let config = try GameConfiguration(players: [player("A"), player("B")])
        var state = GameState(configuration: config)
        state.round = Round(
            stock: Array(repeating: Card(.king, of: .clubs), count: stock),
            table: table,
            hands: [hand, Array(repeating: Card(.two, of: .swords), count: opponentCards)],
            captures: [[], []], scope: [0, 0], turnSeat: 0, lastCaptureSide: nil
        )
        state.phase = .playing
        return state.view(forSeat: 0)
    }

    private static func card(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

    @Test func oneWayToTakeIsFilledIn() throws {
        let table = [Self.card(.three), Self.card(.four)]
        let view = try Self.view(hand: [Self.card(.seven, .coins)], table: table)
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.seven, .coins), on: table)
        #expect(selection.chosen == Set(table))
        #expect(selection.action(in: view) == .take(cards: [Self.card(.three), Self.card(.four)], sweeps: true))
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.seven, .coins), captures: [Self.card(.three), Self.card(.four)]))
    }

    @Test func severalWaysWaitForThePlayer() throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let view = try Self.view(hand: [Self.card(.five)], table: table)
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.five), on: table)
        #expect(selection.chosen.isEmpty)
        #expect(selection.action(in: view) == .chooseWhatToTake)
        #expect(selection.move(in: view) == nil)

        selection.toggle(Self.card(.ace), on: table)
        #expect(selection.action(in: view) == .notAllowed)
        selection.toggle(Self.card(.four), on: table)
        #expect(selection.action(in: view) == .take(cards: [Self.card(.ace), Self.card(.four)], sweeps: false))
    }

    @Test func aCardWithNoMatchIsLaidDown() throws {
        let table = [Self.card(.king), Self.card(.knight)]
        let view = try Self.view(hand: [Self.card(.two)], table: table)
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.two), on: table)
        #expect(selection.action(in: view) == .lay)
        #expect(selection.move(in: view)?.captures.isEmpty == true)
        #expect(selection.capturable(on: table).isEmpty)
    }

    @Test func tappingTheSameCardClearsAndStrayTapsAreIgnored() throws {
        let table = [Self.card(.three), Self.card(.four)]
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.seven, .coins), on: table)
        selection.select(Self.card(.seven, .coins), on: table)
        #expect(selection.isEmpty && selection.chosen.isEmpty)

        selection.select(Self.card(.five), on: table)
        selection.toggle(Self.card(.king, .cups), on: table)
        #expect(selection.chosen.isEmpty)
    }

    @Test func aSweepOnTheLastCardDoesNotScore() throws {
        let table = [Self.card(.three), Self.card(.four)]
        let view = try Self.view(hand: [Self.card(.seven, .coins)], table: table, stock: 0, opponentCards: 0)
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.seven, .coins), on: table)
        #expect(selection.action(in: view) == .take(cards: [Self.card(.three), Self.card(.four)], sweeps: false))
    }
}

@Suite struct Assisting {
    private static func card(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

    private static func state(hand: [Card], table: [Card]) throws -> GameState {
        let config = try GameConfiguration(players: [player("A"), player("B")])
        var state = GameState(configuration: config)
        state.round = Round(
            stock: Array(repeating: Card(.king, of: .clubs), count: 10),
            table: table,
            hands: [hand, [Card(.two, of: .swords)]],
            captures: [[], []], scope: [0, 0], turnSeat: 0, lastCaptureSide: nil
        )
        state.phase = .playing
        return state
    }

    private static func view(hand: [Card], table: [Card]) throws -> PlayerView {
        try state(hand: hand, table: table).view(forSeat: 0)
    }

    @Test func onlyNormalGoesWithoutTheTakeFilledIn() throws {
        let table = [Self.card(.three), Self.card(.four)]
        for level in AssistLevel.allCases {
            var selection = HandSelection(assist: level)
            selection.select(Self.card(.seven, .coins), on: table)
            #expect(selection.chosen.isEmpty == (level == .normal))
        }
    }

    @Test func onlyNormalGoesWithoutTheOutlines() throws {
        let table = [Self.card(.three), Self.card(.four), Self.card(.king)]
        for level in AssistLevel.allCases {
            var selection = HandSelection(assist: level)
            selection.select(Self.card(.seven, .coins), on: table)
            #expect(selection.capturable(on: table).isEmpty == (level == .normal))
        }
    }

    /// A three in hand and a three on the table: the take is filled in, and tapping the
    /// card you are taking has to play it. Toggling it back off left the button dead.
    /// A three in hand with a three on the table must take it. Offering "Play" there gave
    /// every level a button the rules would refuse, which read as the game ignoring the tap.
    @Test func aBeginnerIsNotLetLayACardThatHasToTake() throws {
        let table = [Self.card(.three, .coins), Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: .beginner)
        selection.select(Self.card(.three, .cups), on: table)
        // The take is filled in, so clear it to reach the empty-handed case.
        selection.toggle(Self.card(.three, .coins), on: table)
        #expect(selection.chosen.isEmpty)
        #expect(selection.action(in: view) == .chooseWhatToTake)
        #expect(selection.move(in: view) == nil)
    }

    /// Normal is allowed to try it. The move is well formed, goes to the rules and comes
    /// back refused, which is the lesson that level is for.
    @Test func normalMayStillTryToLayACardThatHasToTake() throws {
        let table = [Self.card(.three, .coins), Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.three, .cups), on: table)
        #expect(selection.chosen.isEmpty)
        #expect(selection.action(in: view) == .lay)
        let move = try #require(selection.move(in: view))
        let state = try Self.state(hand: [Self.card(.three, .cups)], table: table)
        #expect(throws: MoveError.captureIsMandatory) { try Rules.validate(move, in: state) }
    }

    /// A card with one take: the second tap sends it, so the whole move is two taps in the
    /// same place rather than a reach to the button. Normal has nothing filled in when the
    /// tap arrives, so the tap fills the take in itself — there is only the one, and the
    /// rules would refuse anything else this card could do.
    @Test(arguments: AssistLevel.allCases)
    func aSecondTapPlaysTheOnlyTakeThatCardHas(level: AssistLevel) throws {
        let three = Self.card(.three, .coins)
        let table = [three, Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.three, .cups), on: table)
        #expect(selection.tapInHand(Self.card(.three, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.three, .cups), captures: [three]),
                "\(level)")
    }

    /// And a card that matches nothing: laying it is the one move it has.
    @Test(arguments: AssistLevel.allCases)
    func aSecondTapLaysACardThatMatchesNothing(level: AssistLevel) throws {
        let table = [Self.card(.king), Self.card(.knight)]
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.two, .cups), on: table)
        #expect(selection.tapInHand(Self.card(.two, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.two, .cups)), "\(level)")
    }

    /// Several ways to take is a choice nobody has made yet, so the tap puts the card back
    /// down rather than picking one of them.
    @Test(arguments: AssistLevel.allCases)
    func aSecondTapOnAChoiceOnlyPutsTheCardDown(level: AssistLevel) throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let view = try Self.view(hand: [Self.card(.five)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.five), on: table)
        #expect(selection.tapInHand(Self.card(.five), in: view) == .select, "\(level)")
    }

    /// A take the player is still putting together is not the one the card has, so the tap
    /// means what it always meant: put the card back down. Only normal can be in this
    /// state — above it the single take is filled in from the start.
    @Test func aSecondTapOnAHalfBuiltTakePutsTheCardDown() throws {
        let table = [Self.card(.ace), Self.card(.two), Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.three, .cups), on: table)
        selection.toggle(Self.card(.ace), on: table)
        #expect(selection.tapInHand(Self.card(.three, .cups), in: view) == .select)
        #expect(selection.chosen == [Self.card(.ace)])
    }

    /// The first tap never plays: a card has to be pickable up and lookable at.
    @Test func theFirstTapOnlyPicksTheCardUp() throws {
        let table = [Self.card(.three, .coins), Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: .beginner)
        #expect(selection.tapInHand(Self.card(.three, .cups), in: view) == .select)
    }

    /// The tap plays, but it still tells the player nothing before they ask: picking the
    /// card up at normal leaves the cloth bare, whatever the card could take.
    @Test(arguments: [[Card(.three, of: .coins), Card(.king, of: .clubs)], [Card(.king, of: .clubs)]])
    func normalOutlinesNothingWhenTheCardIsPickedUp(table: [Card]) throws {
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.three, .cups), on: table)
        #expect(selection.chosen.isEmpty)
        #expect(selection.capturable(on: table).isEmpty)
    }

    @Test(arguments: AssistLevel.allCases)
    func layingIsStillOfferedWhenNothingMatches(level: AssistLevel) throws {
        let table = [Self.card(.king), Self.card(.knight)]
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.two, .cups), on: table)
        #expect(selection.action(in: view) == .lay, "\(level)")
        #expect(selection.move(in: view) != nil, "\(level)")
    }

    /// An ace dropped on an ace is a finished take at any level, so it plays on the first
    /// drag. Toggling instead meant a beginner's filled-in take was cleared by the drop and
    /// the card had to be dragged over a second time.
    @Test(arguments: AssistLevel.allCases)
    func droppingOntoTheCardItTakesFinishesTheTake(level: AssistLevel) throws {
        let ace = Self.card(.ace, .coins)
        let table = [ace, Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.ace, .cups)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.ace, .cups), on: table)
        let finished = try #require(selection.completing(with: ace, in: view), "\(level)")
        #expect(finished.chosen == [ace])
        #expect(finished.move(in: view) != nil)
    }

    /// A sum still needs its second card, so the first drop only picks it up.
    @Test(arguments: AssistLevel.allCases)
    func droppingOntoHalfOfASumDoesNotPlayIt(level: AssistLevel) throws {
        let three = Self.card(.three), four = Self.card(.four)
        let table = [three, four]
        let view = try Self.view(hand: [Self.card(.seven, .coins)], table: table)
        var selection = HandSelection(assist: level)
        selection.select(Self.card(.seven, .coins), on: table)
        // Beginners have the pair filled in, everyone else has nothing. Reduce both to
        // exactly one card held, which is the half-made case this is about.
        if selection.chosen.contains(four) { selection.toggle(four, on: table) }
        if !selection.chosen.contains(three) { selection.toggle(three, on: table) }
        #expect(selection.chosen == [three], "\(level)")

        // Half a sum is not a take, so the drop only picks the card up.
        #expect(selection.completing(with: three, in: view) == nil, "\(level)")
        // Dropping on the other half finishes it.
        let finished = try #require(selection.completing(with: four, in: view), "\(level)")
        #expect(finished.chosen == Set([three, four]))
    }

    /// A take that was filled in can be taken apart again. It used to play itself instead,
    /// whichever of its cards was touched, so a sum nobody asked for could not be undone.
    @Test(arguments: AssistLevel.allCases)
    func aFilledInTakeCanBeTakenApart(level: AssistLevel) throws {
        let three = Self.card(.three), six = Self.card(.six, .coins)
        let table = [three, six]
        let nine = Self.card(.knight, .cups)
        let view = try Self.view(hand: [nine], table: table)
        var selection = HandSelection(assist: level)
        selection.select(nine, on: table)
        if selection.chosen.isEmpty { selection.toggle(three, on: table); selection.toggle(six, on: table) }
        #expect(selection.chosen == Set([three, six]), "\(level)")

        // The card let go of leaves the take. Where the interface checks the take before
        // sending it, what is left is no longer a move it will send.
        selection.toggle(six, on: table)
        #expect(selection.chosen == [three], "\(level)")
        if level.checksBeforeSending { #expect(selection.move(in: view) == nil, "\(level)") }

        // And it goes back in.
        selection.toggle(six, on: table)
        #expect(selection.chosen == Set([three, six]), "\(level)")
        #expect(selection.move(in: view) != nil, "\(level)")
    }

    @Test func aBeginnerCannotTapACardNoTakeUses() throws {
        let table = [Self.card(.three), Self.card(.four), Self.card(.king)]
        var beginner = HandSelection(assist: .beginner)
        beginner.select(Self.card(.seven, .coins), on: table)
        beginner.toggle(Self.card(.king), on: table)
        #expect(!beginner.chosen.contains(Self.card(.king)))

        var normal = HandSelection(assist: .normal)
        normal.select(Self.card(.seven, .coins), on: table)
        normal.toggle(Self.card(.king), on: table)
        #expect(normal.chosen.contains(Self.card(.king)))
    }

    @Test func onlyABeginnerIsStoppedBeforeAnIllegalTake() throws {
        let table = [Self.card(.three), Self.card(.four)]
        let view = try Self.view(hand: [Self.card(.seven, .coins)], table: table)
        var beginner = HandSelection(assist: .beginner)
        beginner.select(Self.card(.seven, .coins), on: table)
        // A beginner starts with the only take filled in, so clear it to make a wrong one.
        beginner.toggle(Self.card(.four), on: table)
        #expect(beginner.action(in: view) == .notAllowed)
        #expect(beginner.move(in: view) == nil)
    }

    @Test func normalIsTheDefault() {
        #expect(HandSelection().assist == .normal)
        #expect(AssistLevel.default == .normal)
        #expect(AssistLevel.allCases == [.coached, .beginner, .normal])
        #expect(AssistLevel.allCases.filter(\.explains) == [.coached])
    }

    @Test func normalSendsTheWrongTakeSoTheRulesCanRefuseIt() throws {
        let table = [Self.card(.three), Self.card(.four)]
        let view = try Self.view(hand: [Self.card(.seven, .coins)], table: table)
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.seven, .coins), on: table)
        selection.toggle(Self.card(.three), on: table)
        #expect(selection.action(in: view) == .take(cards: [Self.card(.three)], sweeps: false))

        let move = selection.move(in: view)
        #expect(move?.captures == [Self.card(.three)])
        var state = GameState(configuration: view.configuration)
        state.round = Round(stock: [], table: table, hands: [[Self.card(.seven, .coins)], []], captures: [[], []], scope: [0, 0], turnSeat: 0, lastCaptureSide: nil)
        state.phase = .playing
        #expect(throws: MoveError.invalidCapture) { try Rules.validate(move!, in: state) }
    }
}

@Suite struct Disconnecting {
    /// Host plus guests on one loopback network, already dealt.
    private static func game(guests names: [String], seed: UInt64 = 9) async throws -> (LoopbackNetwork, HostCoordinator, Recorder, [(GuestClient, Recorder)]) {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), rng: SeededGenerator(seed: seed))
        let hostRecorder = Recorder()
        await hostRecorder.listen(host.updates)
        await host.start()

        var guests: [(GuestClient, Recorder)] = []
        for name in names {
            let client = GuestClient(transport: network.transport(for: player(name)))
            let recorder = Recorder()
            await recorder.listen(client.updates)
            await client.start()
            try? await client.join()
            guests.append((client, recorder))
        }
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == names.count + 1 }
        try await host.startGame()
        return (network, host, hostRecorder, guests)
    }

    @Test func aGuestLeavingMidGameDoesNotStallTheTable() async throws {
        let (network, host, hostRecorder, _) = try await Self.game(guests: ["Bea"])
        // Seat 1 leads, so the table is waiting on Bea when she vanishes.
        #expect(await host.session?.state.round?.turnSeat == 1)
        network.disconnect(player("Bea").id)

        let left = await hostRecorder.first { if case .playerLeft = $0 { return true }; return false }
        #expect(left != nil)

        // The host played for the empty seat, so it is the host's turn again.
        let turn = await host.session?.state.round?.turnSeat
        #expect(turn == 0)
        await host.stop()
    }

    @Test func everyoneIsHandedTheRecordWhenTheGameEnds() async throws {
        let (_, host, hostRecorder, guests) = try await Self.game(guests: ["Bea"])
        let (bea, beaRecorder) = guests[0]
        // Bea can only play once her first view has landed; the seat comes with it.
        _ = await beaRecorder.first { viewOf($0) != nil }
        var turns = 0
        while await host.session?.state.isFinished == false, turns < 400 {
            turns += 1
            let state = await host.session!.state
            if state.phase != .playing { try await host.dealNextRound(); continue }
            let move = Rules.automaticMove(in: state)!
            if move.seat == 0 {
                try await host.play(move.card, capturing: move.captures)
            } else {
                // Her own view has to have caught up to this turn, or she plays a stale seat.
                _ = await beaRecorder.first { viewOf($0)?.hand.contains(move.card) == true && viewOf($0)?.isMyTurn == true }
                try await bea.play(move.card, capturing: move.captures)
                let before = state
                _ = await hostRecorder.first { u in
                    if case .view(let v) = u { return v.turnSeat != 1 || v.phase != .playing || v.stockCount != before.round?.stock.count }
                    return false
                }
                // Wait for the host to have actually taken the move, not just shown a view.
                for _ in 0..<400 where await host.session?.state == before { await Task.yield() }
            }
        }
        #expect(await host.session?.state.isFinished == true)

        let mine = recordOf(await hostRecorder.first { recordOf($0) != nil })
        let theirs = recordOf(await guests[0].1.first { recordOf($0) != nil })
        #expect(mine != nil && mine == theirs)
        #expect(mine?.replay().final.isFinished == true)
        await host.stop()
    }

    /// The host fills the empty chairs one at a time while the table is being set, and can
    /// stand a bot back up again. Every guest sees the same table.
    @Test func theHostSeatsAndUnseatsBotsOneByOne() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero)
        let recorder = Recorder()
        await recorder.listen(host.updates)
        await host.start()

        await host.addBot()
        await host.addBot()
        #expect(await host.lobby.players.map(\.name) == ["Host", "Hugo", "Laurence"])
        #expect(await host.lobby.players.filter(\.isBot).count == 2)

        let hugo = await host.lobby.players[1].id
        await host.removeBot(hugo)
        #expect(await host.lobby.players.map(\.name) == ["Host", "Laurence"])

        // The name comes back with the seat: the first free one is taken again.
        await host.addBot()
        #expect(await host.lobby.players.map(\.name) == ["Host", "Laurence", "Hugo"])
        #expect(lobbyOf(await recorder.first { (lobbyOf($0)?.players.count ?? 0) == 3 }) != nil)

        // A person is never turned away for a machine.
        await host.addBot()
        #expect(await host.lobby.isFull)
        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        await bea.start()
        try await bea.join()
        _ = await recorder.first { lobbyOf($0)?.players.contains { $0.name == "Bea" } == true }
        #expect(await host.lobby.players.contains { $0.name == "Bea" })
        #expect(await host.lobby.players.count == 4)
        await host.stop()
    }

    /// Once the cards are out the seats are the seats: no bot joins or leaves mid-game.
    @Test func botsCannotBeSeatedOnceTheGameHasStarted() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero)
        await host.start()
        await host.addBot()
        try await host.startGame()
        let seated = await host.lobby.players
        await host.addBot()
        await host.removeBot(seated[1].id)
        #expect(await host.lobby.players == seated)
        await host.stop()
    }

    /// Two people online and two bots the host plays for them: the game runs to its end
    /// with only the people's moves coming from outside.
    @Test func theHostPlaysTheBotSeatsItAdded() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero, rng: SeededGenerator(seed: 5))
        let hostRecorder = Recorder()
        await hostRecorder.listen(host.updates)
        await host.start()
        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        let beaRecorder = Recorder()
        await beaRecorder.listen(bea.updates)
        await bea.start()
        try await bea.join()
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 2 }
        await host.addBots(upTo: 4)
        #expect(await host.lobby.players.count == 4)
        try await host.startGame()

        var turns = 0
        while await host.session?.state.isFinished == false, turns < 600 {
            turns += 1
            let state = await host.session!.state
            if state.phase != .playing { try await host.dealNextRound(); continue }
            guard let move = Rules.automaticMove(in: state) else { break }
            switch move.seat {
            case 0: try await host.play(move.card, capturing: move.captures)
            case 1:
                _ = await beaRecorder.first { viewOf($0)?.hand.contains(move.card) == true && viewOf($0)?.isMyTurn == true }
                try await bea.play(move.card, capturing: move.captures)
                let before = state
                for _ in 0..<400 where await host.session?.state == before { await Task.yield() }
            default:
                // A bot seat: the host is playing it. Give it a moment.
                for _ in 0..<400 where await host.session?.state == state { await Task.yield() }
            }
        }
        #expect(await host.session?.state.isFinished == true)
        await host.stop()
    }

    @Test func theRoundStillFinishesWhenEveryGuestIsGone() async throws {
        let (network, host, hostRecorder, _) = try await Self.game(guests: ["Bea"])
        network.disconnect(player("Bea").id)
        _ = await hostRecorder.first { if case .playerLeft = $0 { return true }; return false }

        // The host keeps playing its own seat; the empty one is covered each time.
        var guard0 = 0
        while await host.session?.state.phase == .playing, guard0 < 60 {
            guard0 += 1
            let state = await host.session!.state
            guard state.round?.turnSeat == 0, let move = Rules.automaticMove(in: state) else { break }
            try await host.play(move.card, capturing: move.captures)
        }
        let phase = await host.session?.state.phase
        let finished: Bool = if case .playing = phase { false } else { true }
        #expect(finished)
        await host.stop()
    }

    @Test func aPlayerComingBackTakesTheirSeatAgain() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), rng: SeededGenerator(seed: 3))
        let hostRecorder = Recorder()
        await hostRecorder.listen(host.updates)
        await host.start()

        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        await bea.start()
        try await bea.join()
        _ = await hostRecorder.first { (lobbyOf($0)?.players.count ?? 0) == 2 }
        try await host.startGame()

        network.disconnect(player("Bea").id)
        _ = await hostRecorder.first { if case .playerLeft = $0 { return true }; return false }

        // Bea reconnects on a fresh transport and is handed her view back.
        let again = GuestClient(transport: network.transport(for: player("Bea")))
        let againRecorder = Recorder()
        await againRecorder.listen(again.updates)
        await again.start()
        try await again.join()

        let view = viewOf(await againRecorder.first { viewOf($0) != nil })
        #expect(view?.seat == 1)
        #expect(await host.lobby.players.count == 2)
        await host.stop()
    }
}
