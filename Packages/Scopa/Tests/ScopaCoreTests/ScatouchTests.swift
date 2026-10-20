import Testing
@testable import ScopaCore

private func players(_ count: Int) -> [Player] {
    (0..<count).map { Player(id: PlayerID(rawValue: "p\($0)"), name: "P\($0)") }
}

/// Every card at the table: hands, table, stock and piles.
private func everyCard(in state: GameState) -> [Card] {
    guard let round = state.round else { return [] }
    return round.hands.flatMap { $0 } + round.table + round.stock + round.captures.flatMap { $0 }
}

@Suite struct ScatouchSwaps {
    @Test func aSwapTradesPlacesAndKeepsFortyCards() async throws {
        let session = GameSession(configuration: try GameConfiguration(players: players(2)),
                                  rng: SeededGenerator(seed: 11))
        await session.startRound()
        let before = await session.state
        let held = before.round!.hands[0][1]
        let wanted = before.round!.stock[5]

        try await session.swap(held, inHandOf: 0, for: wanted)
        let after = await session.state
        #expect(after.round!.hands[0][1] == wanted)
        #expect(after.round!.stock[5] == held)
        #expect(after.round!.table == before.round!.table)
        #expect(after.round!.hands[1] == before.round!.hands[1])
        #expect(Set(everyCard(in: after)) == Set(Deck.standard))
        #expect(everyCard(in: after).count == 40)
    }

    @Test func aSwapIsRefusedForACardThatIsNotThere() async throws {
        let session = GameSession(configuration: try GameConfiguration(players: players(2)),
                                  rng: SeededGenerator(seed: 3))
        let card = Deck.standard[0]
        await #expect(throws: SwapError.notPlaying) { try await session.swap(card, inHandOf: 0, for: card) }

        await session.startRound()
        let round = await session.state.round!
        let theirs = round.hands[1][0], mine = round.hands[0][0], onTable = round.table[0]
        await #expect(throws: SwapError.cardNotInHand) { try await session.swap(theirs, inHandOf: 0, for: round.stock[0]) }
        await #expect(throws: SwapError.cardNotInStock) { try await session.swap(mine, inHandOf: 0, for: onTable) }
    }

    @Test func theRecordStillReplaysAfterASwap() async throws {
        let session = GameSession(configuration: try GameConfiguration(players: players(3)),
                                  rng: SeededGenerator(seed: 21))
        await session.startRound()
        for _ in 0..<4 { _ = try await session.play(try #require(Rules.automaticMove(in: await session.state))) }
        let state = await session.state
        try await session.swap(state.round!.hands[1][0], inHandOf: 1, for: state.round!.stock.last!)
        for _ in 0..<7 { _ = try await session.play(try #require(Rules.automaticMove(in: await session.state))) }

        let replayed = await session.record.replay()
        #expect(replayed.steps.count == 11)
        #expect(replayed.final == (await session.state))
    }

    @Test func upcomingDealsFollowTheDealOrder() throws {
        let config = try GameConfiguration(players: players(2))
        let (state, _) = Rules.deal(Deck.standard, into: GameState(configuration: config))
        let deals = state.upcomingDeals
        #expect(deals.count == 5)
        var round = state.round!
        round.hands = [[], []]
        Rules.dealHands(&round, config)
        #expect(deals[0] == round.hands)
        #expect(deals.flatMap { $0.flatMap { $0 } }.count == state.round!.stock.count)
    }
}

@Suite struct SteeredSeats {
    private func table(seed: UInt64 = 4) throws -> HotSeatTable {
        HotSeatTable(configuration: try GameConfiguration(players: players(2)), bots: [1], pace: .zero,
                     rng: SeededGenerator(seed: seed))
    }

    @Test func aSteeredBotWaitsForItsMove() async throws {
        let table = try table()
        await table.steer([1])
        await table.deal()
        try await Task.sleep(for: .milliseconds(200))
        var state = await table.state
        // Seat 0 deals, so the bot leads, and it has not thought for itself.
        #expect(state.round!.turnSeat == 1)
        #expect(state.round!.hands[1].count == 3)

        let card = state.round!.hands[1][0]
        try await table.play(card, capturing: Rules.captureOptions(for: card, on: state.round!.table).first ?? [])
        state = await table.state
        #expect(!state.round!.hands[1].contains(card), "the move handed in was not the bot's")
        #expect(state.round!.turnSeat == 0)
        await table.stop()
    }

    @Test func aSteeredBotLetGoPlaysOneTurnOnly() async throws {
        let table = try table(seed: 9)
        await table.steer([1])
        await table.deal()
        await table.letSteeredSeatPlay()
        var state = await table.state
        #expect(state.round!.hands[1].count == 2)
        #expect(state.round!.turnSeat == 0)

        let card = state.round!.hands[0][0]
        try await table.play(card, capturing: Rules.captureOptions(for: card, on: state.round!.table).first ?? [])
        try await Task.sleep(for: .milliseconds(200))
        state = await table.state
        #expect(state.round!.turnSeat == 1, "the bot played a second turn on its own")
        await table.stop()
    }

    @Test func steeringOffLetsTheBotGoOn() async throws {
        let table = try table()
        await table.steer([1])
        await table.deal()
        await table.steer([])
        let state = await table.state
        #expect(state.round!.turnSeat == 0)
        await table.stop()
    }

    @Test func onlyAPersonsHandIsSwapped() async throws {
        let table = try table()
        await table.steer([1])
        await table.deal()
        let round = await table.state.round!
        await #expect(throws: SwapError.cardNotInHand) {
            try await table.swap(round.hands[1][0], inHandOf: 1, for: round.stock[0])
        }
        try await table.swap(round.hands[0][2], inHandOf: 0, for: round.stock[0])
        #expect(await table.state.round!.hands[0][2] == round.stock[0])
        await table.stop()
    }
}
