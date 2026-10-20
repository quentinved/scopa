import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit) -> Card { Card(rank, of: suit) }

private func configuration(for deal: PracticeDeal, target: Int = 1) throws -> GameConfiguration {
    let players = (0..<deal.seats).map { Player(id: PlayerID(rawValue: "p\($0)"), name: "P\($0)") }
    return try GameConfiguration(players: players, teams: deal.teams, targetScore: target, house: [deal.rule])
}

/// Deals `deal` and plays every scripted move, collecting the events.
private func playOut(_ deal: PracticeDeal) async throws -> (GameSession, [GameEvent]) {
    let session = GameSession(configuration: try configuration(for: deal))
    var events = await session.startRound(deck: deal.deck)
    for move in deal.moves { events += try await session.play(move) }
    return (session, events)
}

private func roundScore(_ events: [GameEvent]) -> RoundScore? {
    events.lazy.compactMap { if case .roundEnded(let score) = $0 { score } else { nil } }.first
}

@Suite struct StackedDecks {
    @Test func aStackedDeckDealsWhatItWasLaidOutWith() throws {
        let table = [c(.ace, .coins), c(.two, .cups), c(.three, .swords), c(.four, .clubs)]
        let first = [[c(.five, .coins), c(.six, .coins), c(.seven, .coins)],
                     [c(.five, .cups), c(.six, .cups), c(.seven, .cups)]]
        let second = [[c(.king, .coins), c(.king, .cups), c(.king, .swords)],
                      [c(.knight, .coins), c(.knight, .cups), c(.knight, .swords)]]
        let deck = Deck.stacked(table: table, deals: [first, second])
        #expect(deck.count == 16)

        let players = [Player(id: PlayerID(rawValue: "a"), name: "A"), Player(id: PlayerID(rawValue: "b"), name: "B")]
        let (state, _) = Rules.deal(deck, into: GameState(configuration: try GameConfiguration(players: players)))
        var round = try #require(state.round)
        #expect(round.table == table)
        #expect(round.hands == first)
        Rules.dealHands(&round, state.configuration)
        #expect(round.hands == second)
        #expect(round.stock.isEmpty)
    }

    @Test func aSessionDealsAStackedDeckAndRecordsIt() async throws {
        let deal = HouseRule.napola.practice
        let session = GameSession(configuration: try configuration(for: deal))
        #expect(await session.startRound(deck: deal.deck) == [.dealt])
        #expect(await session.record.rounds.first?.deck == deal.deck)
        // A round in play is not dealt over, stacked or not.
        #expect(await session.startRound(deck: deal.deck).isEmpty)
    }
}

@Suite struct PracticeDeals {
    @Test(arguments: HouseRule.allCases)
    func everyScriptedMoveIsLegal(_ rule: HouseRule) async throws {
        let deal = rule.practice
        #expect(deal.rule == rule)
        #expect(deal.moves.first?.seat == 1, "seat 1 leads when seat 0 deals")
        _ = try await playOut(deal)
    }

    @Test func napolaIsMadeAndRunsOnToFour() async throws {
        let (session, events) = try await playOut(HouseRule.napola.practice)
        let score = try #require(roundScore(events))
        #expect(score.categoryPoints[.napola] == [4, 0])
        #expect(await session.state.phase == .finished(winnerSide: 0))
    }

    @Test func theAceTakesAllWithoutAScopa() async throws {
        let deal = HouseRule.assoPigliaTutto.practice
        let (state, _) = Rules.deal(deal.deck, into: GameState(configuration: try configuration(for: deal)))
        #expect(state.round?.table.contains { $0.rank == .ace } == false, "an ace was dealt face up")

        let (session, events) = try await playOut(deal)
        #expect(deal.moves[1].captures.count == 5)
        #expect(!events.contains { if case .scopa = $0 { true } else { false } })
        #expect(await session.state.round?.scope == [0, 0])
        #expect(await session.state.phase == .finished(winnerSide: 0))
    }

    @Test func reBelloScoresBesideTheSettebello() async throws {
        let (session, events) = try await playOut(HouseRule.reBello.practice)
        let score = try #require(roundScore(events))
        #expect(score.categoryPoints[.reBello] == [1, 0])
        #expect(score.categoryPoints[.settebello] == [1, 0])
        #expect(await session.state.phase == .finished(winnerSide: 0))
    }

    @Test func scoponeDealsTenEachOnAnEmptyTableAndPartnersSweepTogether() async throws {
        let deal = HouseRule.scopone.practice
        #expect(Set(deal.deck) == Set(Deck.standard))
        let (dealt, _) = Rules.deal(deal.deck, into: GameState(configuration: try configuration(for: deal)))
        #expect(dealt.round?.table.isEmpty == true)
        #expect(dealt.round?.hands.map(\.count) == [10, 10, 10, 10])

        let (session, events) = try await playOut(deal)
        #expect(events.filter { if case .scopa = $0 { true } else { false } } == [.scopa(seat: 2), .scopa(seat: 0)])
        #expect(await session.state.round?.scope == [2, 0])
        #expect(await session.state.phase == .playing, "the rest of the hand is played freely")
    }

    @Test(arguments: HouseRule.allCases)
    func movesPlayedAreReadOffTheView(_ rule: HouseRule) async throws {
        let deal = rule.practice
        let session = GameSession(configuration: try configuration(for: deal))
        await session.startRound(deck: deal.deck)
        for (index, move) in deal.moves.enumerated() {
            #expect(deal.played(in: await session.state.view(forSeat: 0)) == index)
            try await session.play(move)
        }
    }
}

@Suite struct ScriptedBots {
    @Test func theBotsPlayTheirScriptedMoves() async throws {
        let deal = HouseRule.reBello.practice
        let table = HotSeatTable(configuration: try configuration(for: deal), bots: [1], pace: .zero)
        await table.deal(stacked: deal.deck, botMoves: deal.botMoves)
        for move in deal.moves where move.seat == PracticeDeal.learner {
            try await table.play(move.card, capturing: move.captures)
        }
        let snapshot = await table.snapshot
        #expect(snapshot.record.rounds.first?.moves == deal.moves)
        #expect(snapshot.record.replay().final == snapshot.state)
        await table.stop()
    }

    @Test func aMoveTheRulesRefuseHandsTheSeatBackToTheBot() async throws {
        let deal = HouseRule.napola.practice
        // The king of coins is in nobody's hand.
        let script = [Move(seat: 1, card: .reBello)] + deal.botMoves
        let table = HotSeatTable(configuration: try configuration(for: deal), bots: [1], pace: .zero)
        await table.deal(stacked: deal.deck, botMoves: script)
        let state = await table.state
        #expect(state.round?.hands[1].count == 2, "the bot sat still")
        #expect(state.round?.turnSeat == 0)
        await table.stop()
    }
}
