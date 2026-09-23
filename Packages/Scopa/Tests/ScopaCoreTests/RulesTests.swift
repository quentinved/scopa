import Foundation
import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

@Suite struct CaptureOptions {
    @Test func singleMatchBeatsSums() {
        let table = [c(.seven, .coins), c(.three), c(.four)]
        let options = Rules.captureOptions(for: c(.seven, .cups), on: table)
        #expect(options == [[c(.seven, .coins)]])
    }

    @Test func allSumsAreOffered() {
        let table = [c(.ace), c(.two), c(.three), c(.four, .coins), c(.four, .cups)]
        let options = Rules.captureOptions(for: c(.five), on: table).map(Set.init)
        #expect(options.count == 3)
        #expect(options.contains([c(.ace), c(.four, .coins)]))
        #expect(options.contains([c(.ace), c(.four, .cups)]))
        #expect(options.contains([c(.two), c(.three)]))
    }

    @Test func noCaptureWhenNothingFits() {
        #expect(Rules.captureOptions(for: c(.two), on: [c(.king), c(.five)]).isEmpty)
        #expect(Rules.captureOptions(for: c(.ace), on: []).isEmpty)
    }
}

@Suite struct Scores {
    @Test func primieraTakesBestPerSuit() {
        let cards = [c(.seven, .coins), c(.king, .coins), c(.six, .cups), c(.ace, .swords)]
        #expect(Scoring.primiera(of: cards) == 21 + 18 + 16)
    }

    @Test func mostSevensCountsSevensOnly() {
        // Classic: a 6 and an ace in two suits beat two bare sevens on total. Most sevens: they do not.
        let a = [c(.seven, .coins), c(.seven, .cups)]
        let b = [c(.six, .coins), c(.ace, .cups), c(.six, .swords), c(.ace, .clubs)]
        let classic = Scoring.score(captures: [a, b], scope: [0, 0])
        #expect(classic.categoryWinners[.primiera] == 1)
        let sevens = Scoring.score(captures: [a, b], scope: [0, 0], primiera: .mostSevens)
        #expect(sevens.categoryWinners[.primiera] == 0)
        #expect(sevens.tallies[.primiera] == [2, 0])
        #expect(sevens.primieraCards == [a, []])
    }

    @Test func tiesAwardNothing() {
        let a = [c(.seven, .coins), c(.two, .cups)]
        let b = [c(.six, .coins), c(.two, .swords)]
        let score = Scoring.score(captures: [a, b], scope: [1, 0])
        #expect(score.categoryWinners[.cards] == .some(nil))
        #expect(score.categoryWinners[.coins] == .some(nil))
        #expect(score.categoryWinners[.settebello] == 0)
        #expect(score.categoryWinners[.primiera] == 0)
        #expect(score.points == [3, 0])
    }

    /// The house rule: a category ended level pays both sides rather than neither.
    @Test func sharedTiesPayEverybodyLevel() {
        let a = [c(.seven, .coins), c(.two, .cups)]
        let b = [c(.six, .coins), c(.two, .swords)]
        let score = Scoring.score(captures: [a, b], scope: [1, 0], ties: .shared)
        // Cards and coins are level at two and one: a point each, on top of the sweep, the
        // settebello and the primiera, which side one won outright.
        #expect(score.points == [5, 2])
        #expect(score.categoryWinners[.cards] == .some(nil))
        #expect(score.categoryPoints[.cards] == [1, 1])
        #expect(score.categoryPoints[.coins] == [1, 1])
        #expect(score.categoryPoints[.settebello] == [1, 0])
        #expect(score.points(for: .primiera, side: 0) == 1)
    }

    /// Level at nothing is not level: a category neither side scored in pays neither of them.
    @Test func sharedTiesPayNobodyForNothing() {
        let a = [c(.seven, .cups)]
        let b = [c(.seven, .swords)]
        let score = Scoring.score(captures: [a, b], scope: [0, 0], ties: .shared)
        #expect(score.categoryPoints[.coins] == [0, 0])
        #expect(score.categoryPoints[.settebello] == [0, 0])
        // A card each and a seven each: both of those are level at something, and pay.
        #expect(score.points == [2, 2])
    }

    /// The rule travels with the table, so the round is scored the way the host set it up.
    @Test func theTableCarriesItsTieRule() throws {
        let players = [Player(id: PlayerID(rawValue: "a"), name: "A"), Player(id: PlayerID(rawValue: "b"), name: "B")]
        let config = try GameConfiguration(players: players, ties: .shared)
        let restored = try JSONDecoder().decode(GameConfiguration.self, from: JSONEncoder().encode(config))
        #expect(restored.ties == .shared)
        // And a table set up before the rule existed still reads back as the rulebook.
        let old = try GameConfiguration(players: players)
        #expect(old.ties == .classic)
    }

    /// The counts behind each point travel with the score, so a summary can show them.
    @Test func talliesExplainEveryCategory() {
        let a = [c(.seven, .coins), c(.two, .cups), c(.king, .swords)]
        let b = [c(.six, .coins), c(.two, .swords)]
        let score = Scoring.score(captures: [a, b], scope: [0, 0])
        #expect(score.tallies[.cards] == [3, 2])
        #expect(score.tallies[.coins] == [1, 1])
        #expect(score.tallies[.settebello] == [1, 0])
        #expect(score.tallies[.primiera] == [21 + 12 + 10, 18 + 12])
    }
}

@Suite struct Playing {
    static func twoPlayerState() throws -> GameState {
        let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
        var state = GameState(configuration: config)
        state.round = Round(
            stock: [], table: [c(.three), c(.four), c(.king, .cups)],
            hands: [[c(.seven, .coins), c(.ace)], [c(.king), c(.two)]],
            captures: [[], []], scope: [0, 0], turnSeat: 1, lastCaptureSide: nil
        )
        state.phase = .playing
        return state
    }

    @Test func captureIsMandatory() throws {
        let state = try Self.twoPlayerState()
        let (afterKing, _) = try Rules.apply(Move(seat: 1, card: c(.king), captures: [c(.king, .cups)]), to: state)
        #expect(throws: MoveError.captureIsMandatory) {
            try Rules.apply(Move(seat: 0, card: c(.seven, .coins)), to: afterKing)
        }
    }

    @Test func wrongTurnAndWrongCardAreRejected() throws {
        let state = try Self.twoPlayerState()
        #expect(throws: MoveError.notYourTurn(expectedSeat: 1)) { try Rules.validate(Move(seat: 0, card: c(.ace)), in: state) }
        #expect(throws: MoveError.cardNotInHand) { try Rules.validate(Move(seat: 1, card: c(.ace)), in: state) }
        #expect(throws: MoveError.invalidCapture) { try Rules.validate(Move(seat: 1, card: c(.two), captures: [c(.three)]), in: state) }
    }

    @Test func scopaCountsExceptOnLastCard() throws {
        let state = try Self.twoPlayerState()
        var (s, events) = try Rules.apply(Move(seat: 1, card: c(.king), captures: [c(.king, .cups)]), to: state)
        #expect(!events.contains(.scopa(seat: 1)))
        (s, events) = try Rules.apply(Move(seat: 0, card: c(.seven, .coins), captures: [c(.three), c(.four)]), to: s)
        #expect(events.contains(.scopa(seat: 0)))
        #expect(s.round?.scope == [1, 0])

        (s, events) = try Rules.apply(Move(seat: 1, card: c(.two)), to: s)
        (s, events) = try Rules.apply(Move(seat: 0, card: c(.ace)), to: s)
        #expect(!events.contains(.scopa(seat: 0)))
        #expect(events.contains(.leftoverSwept(side: 0, cards: [c(.two), c(.ace)])))
        guard case .roundOver(let score) = s.phase else { Issue.record("round should be over"); return }
        #expect(score.points[0] >= 3)
        #expect(s.dealerSeat == 1)
    }
}

@Suite struct FullGames {
    /// Plays random legal moves until the game ends, checking that no card is ever lost or duplicated.
    @Test(arguments: [2, 3, 4], [UInt64(1), 7, 42])
    func randomGameKeepsFortyCards(playerCount: Int, seed: UInt64) async throws {
        let players = (0..<playerCount).map { Player(id: .init(rawValue: "p\($0)"), name: "P\($0)") }
        let config = try GameConfiguration(players: players, teams: playerCount == 4)
        let session = GameSession(configuration: config, rng: SeededGenerator(seed: seed))
        var rng = SeededGenerator(seed: seed &+ 1)
        var rounds = 0

        while await !session.state.isFinished {
            await session.startRound()
            rounds += 1
            while await session.state.phase == .playing {
                let state = await session.state
                let round = state.round!
                let card = round.hands[round.turnSeat].randomElement(using: &rng)!
                let capture = Rules.captureOptions(for: card, on: round.table).randomElement(using: &rng) ?? []
                _ = try await session.play(Move(seat: round.turnSeat, card: card, captures: capture))

                // Count the round the move produced, not the snapshot taken before it.
                // The old one could never have caught a card going missing.
                let after = try #require(await session.state.round)
                let all = after.stock + after.table + after.hands.flatMap { $0 } + after.captures.flatMap { $0 }
                #expect(Set(all).count == 40 && all.count == 40)
            }
            #expect(rounds < 100)
        }

        let final = await session.state
        let winner = Rules.winner(of: final)
        #expect(winner != nil && final.scores[winner!] >= config.targetScore)
        #expect(final.round?.stock.isEmpty == true && final.round?.table.isEmpty == true)
    }
}

/// A beginner is never offered a move the rules would refuse. Normal deliberately is, since
/// the player is allowed the mistake, so this covers beginner only.
@Suite struct OfferedMovesAreLegal {
    @Test(arguments: [2, 3, 4], [AssistLevel.beginner])
    func everyOfferedMoveIsAccepted(playerCount: Int, level: AssistLevel) async throws {
        let players = (0..<playerCount).map { Player(id: .init(rawValue: "p\($0)"), name: "P\($0)") }
        let config = try GameConfiguration(players: players, teams: playerCount == 4)
        let session = GameSession(configuration: config, rng: SeededGenerator(seed: 2024))
        var rng = SeededGenerator(seed: 11)

        while await !session.state.isFinished {
            await session.startRound()
            while await session.state.phase == .playing {
                let state = await session.state
                let round = try #require(state.round)
                let view = state.view(forSeat: round.turnSeat)

                // Pick each card in turn and take the interface at its word.
                for card in round.hands[round.turnSeat] {
                    var selection = HandSelection(assist: level)
                    selection.select(card, on: round.table)
                    guard let action = selection.action(in: view), action.isPlayable else { continue }
                    let move = try #require(selection.move(in: view), "\(level) offered \(action) with no move")
                    #expect(throws: Never.self) { try Rules.validate(move, in: state) }
                }

                let card = try #require(round.hands[round.turnSeat].randomElement(using: &rng))
                let capture = Rules.captureOptions(for: card, on: round.table).randomElement(using: &rng) ?? []
                _ = try await session.play(Move(seat: round.turnSeat, card: card, captures: capture))
            }
        }
    }
}

@Suite struct Views {
    @Test func aViewKnowsWhenASweepWouldScore() throws {
        let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
        var state = GameState(configuration: config)
        state.round = Round(
            stock: [], table: [c(.three), c(.four)],
            hands: [[c(.seven, .coins)], [c(.king)]],
            captures: [[], []], scope: [0, 0], turnSeat: 0, lastCaptureSide: nil
        )
        state.phase = .playing

        let view = state.view(forSeat: 0)
        #expect(view.cardsInPlay == 2 && !view.isOnLastCard)
        #expect(view.isScopa(taking: [c(.three), c(.four)]))
        #expect(!view.isScopa(taking: [c(.three)]))
        #expect(!view.isScopa(taking: []))

        // With one card left in play, a sweep no longer scores.
        var last = state
        last.round?.hands[1] = []
        #expect(last.view(forSeat: 0).isOnLastCard)
        #expect(!last.view(forSeat: 0).isScopa(taking: [c(.three), c(.four)]))
    }
}

@Suite struct AutomaticMoves {
    private static func state(hand: [Card], table: [Card], stock: Int = 6, opponent: [Card] = [c(.king, .cups)]) throws -> GameState {
        let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
        var state = GameState(configuration: config)
        state.round = Round(
            stock: Array(repeating: c(.king, .swords), count: stock),
            table: table, hands: [hand, opponent],
            captures: [[], []], scope: [0, 0], turnSeat: 0, lastCaptureSide: nil
        )
        state.phase = .playing
        return state
    }

    @Test func aSweepIsPreferredOverAnythingElse() throws {
        // The 5 takes 2+3 and clears the table; the 7 takes only the seven of cups.
        let state = try Self.state(hand: [c(.five), c(.seven, .swords)], table: [c(.two), c(.three)])
        let move = Rules.automaticMove(in: state)
        #expect(move?.card == c(.five))
        #expect(Set(move?.captures ?? []) == [c(.two), c(.three)])
    }

    @Test func theSettebelloIsTakenWhenItIsOnOffer() throws {
        let state = try Self.state(hand: [c(.seven, .cups), c(.two, .swords)], table: [Card.settebello, c(.two, .clubs), c(.knight, .cups)])
        let move = Rules.automaticMove(in: state)
        #expect(move?.captures == [Card.settebello])
    }

    @Test func withNothingToTakeTheLeastUsefulCardGoesDown() throws {
        let state = try Self.state(hand: [Card.settebello, c(.three, .coins), c(.two, .clubs)], table: [c(.king, .swords)])
        let move = Rules.automaticMove(in: state)
        #expect(move?.card == c(.two, .clubs))
        #expect(move?.captures.isEmpty == true)
    }

    @Test func itAlwaysProducesALegalMove() throws {
        for seed in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seed)
            let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
            var (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
            while state.phase == .playing {
                let move = Rules.automaticMove(in: state)
                #expect(move != nil)
                (state, _) = try Rules.apply(move!, to: state)
            }
        }
    }

    @Test func nothingIsPlayedOutsideARound() throws {
        #expect(Rules.automaticMove(in: GameState(configuration: try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")]))) == nil)
    }
}

@Suite struct Clocks {
    @Test func theClockIsATableRuleEveryoneCanSee() throws {
        let config = try GameConfiguration(
            players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")],
            turnClock: .relaxed
        )
        #expect(GameState(configuration: config).view(forSeat: 1).configuration.turnClock.seconds == 30)
        #expect(TurnClock.off.seconds == nil)
        #expect(TurnClock.default == .off)
    }
}

@Suite struct AutomaticMovesFromAView {
    @Test func aSeatChoosesTheSameMoveFromItsOwnView() throws {
        for seed in UInt64(1)...15 {
            var rng = SeededGenerator(seed: seed)
            let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
            var (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
            while state.phase == .playing {
                let seat = state.round!.turnSeat
                let fromState = Rules.automaticMove(in: state)
                let fromView = Rules.automaticMove(for: state.view(forSeat: seat))
                #expect(fromState == fromView)
                (state, _) = try Rules.apply(fromState!, to: state)
            }
        }
    }

    @Test func aSeatThatIsNotPlayingChoosesNothing() throws {
        let config = try GameConfiguration(players: [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")])
        var rng = SeededGenerator(seed: 4)
        let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
        let waiting = state.round!.turnSeat == 0 ? 1 : 0
        #expect(Rules.automaticMove(for: state.view(forSeat: waiting)) == nil)
    }
}
