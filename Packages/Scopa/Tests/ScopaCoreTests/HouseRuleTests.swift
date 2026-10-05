import Foundation
import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

private func players(_ count: Int) -> [Player] {
    (0..<count).map { Player(id: .init(rawValue: "p\($0)"), name: "P\($0)") }
}

private func table(_ house: Set<HouseRule>, seats: Int = 2, teams: Bool = false) throws -> GameConfiguration {
    try GameConfiguration(players: players(seats), teams: teams, house: house)
}

/// A round in progress with seat 0 to play `hand` over `table`.
private func state(_ house: Set<HouseRule>, hand: [Card], table cards: [Card], stock: Int = 6) throws -> GameState {
    var state = GameState(configuration: try table(house))
    state.round = Round(stock: Array(repeating: c(.king, .swords), count: stock), table: cards,
                        hands: [hand, [c(.king, .cups)]], captures: [[], []], scope: [0, 0],
                        turnSeat: 0, lastCaptureSide: nil)
    state.phase = .playing
    return state
}

@Suite struct AssoPigliaTutto {
    @Test func anAceTakesTheWholeTable() {
        let cards = [c(.five), c(.knave, .cups), c(.ace, .swords)]
        #expect(Rules.captureOptions(for: c(.ace), on: cards, house: [.assoPigliaTutto]) == [cards])
        // Without the rule it takes only the ace that matches it.
        #expect(Rules.captureOptions(for: c(.ace), on: cards) == [[c(.ace, .swords)]])
    }

    @Test func anAceOnAnEmptyTableIsLaid() {
        #expect(Rules.captureOptions(for: c(.ace), on: [], house: [.assoPigliaTutto]).isEmpty)
    }

    @Test func takingItAllWithAnAceIsNoScopa() throws {
        let before = try state([.assoPigliaTutto], hand: [c(.ace), c(.two)], table: [c(.five), c(.king)])
        let (after, events) = try Rules.apply(Move(seat: 0, card: c(.ace), captures: [c(.five), c(.king)]), to: before)
        #expect(after.round?.table.isEmpty == true)
        #expect(after.round?.scope == [0, 0])
        #expect(!events.contains(.scopa(seat: 0)))
        #expect(!before.view(forSeat: 0).isScopa(playing: c(.ace), taking: [c(.five), c(.king)]))
    }

    @Test func anyOtherSweepStillScores() throws {
        let before = try state([.assoPigliaTutto], hand: [c(.seven), c(.two)], table: [c(.five), c(.two, .cups)])
        let (after, _) = try Rules.apply(Move(seat: 0, card: c(.seven), captures: [c(.five), c(.two, .cups)]), to: before)
        #expect(after.round?.scope == [1, 0])
    }

    @Test func noAceIsDealtFaceUp() throws {
        let config = try table([.assoPigliaTutto])
        for seed in UInt64(1)...200 {
            var rng = SeededGenerator(seed: seed)
            let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
            #expect(!(state.round?.table.contains { $0.rank == .ace } ?? true))
        }
    }

    @Test func aClassicDeckShufflesExactlyAsBefore() {
        // The daily deal is seeded, so a classic table must draw the same deck it always did.
        var old = SeededGenerator(seed: 9), new = SeededGenerator(seed: 9)
        #expect(Rules.shuffledDeck(using: &old) == Rules.shuffledDeck(for: try! table([]), using: &new))
    }
}

@Suite struct Scopone {
    @Test func itNeedsTwoTeams() {
        #expect(throws: ConfigurationError.scoponeRequiresTeams) {
            try GameConfiguration(players: players(4), house: [.scopone])
        }
        #expect(throws: ConfigurationError.teamsRequireFourPlayers) {
            try GameConfiguration(players: players(2), teams: true, house: [.scopone])
        }
    }

    @Test func theWholeDeckIsDealtAndTheTableStartsEmpty() throws {
        let config = try table([.scopone], seats: 4, teams: true)
        var rng = SeededGenerator(seed: 3)
        let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
        let round = try #require(state.round)
        #expect(round.table.isEmpty)
        #expect(round.stock.isEmpty)
        #expect(round.hands.map(\.count) == [10, 10, 10, 10])
        #expect(state.view(forSeat: 0).handNumber == 1)
    }

    @Test func aRoundPlaysOutToFortyCards() throws {
        let config = try table([.scopone, .napola], seats: 4, teams: true)
        for seed in UInt64(1)...10 {
            var rng = SeededGenerator(seed: seed)
            var (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
            while state.phase == .playing {
                (state, _) = try Rules.apply(try #require(Rules.automaticMove(in: state)), to: state)
            }
            #expect(state.round?.captures.map(\.count).reduce(0, +) == 40)
        }
    }

    @Test func theHardBotAnswersATenCardHand() throws {
        let config = try table([.scopone], seats: 4, teams: true)
        var rng = SeededGenerator(seed: 5)
        let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
        let seat = try #require(state.round?.turnSeat)
        let started = Date()
        let move = Bot(level: .hard).move(for: state.view(forSeat: seat), using: &rng)
        #expect(move != nil)
        // Generous for a debug build on a busy machine; a phone in release is far quicker.
        #expect(Date().timeIntervalSince(started) < 20)
    }
}

@Suite struct HouseScoring {
    @Test func theReBelloIsAPointOfItsOwn() {
        let score = Scoring.score(captures: [[.reBello], [c(.two)]], scope: [0, 0], house: [.reBello])
        #expect(score.categoryWinners[.reBello] == 0)
        #expect(score.points(for: .reBello, side: 0) == 1)
    }

    @Test func aNapolaScoresItsRun() {
        let run = [c(.ace, .coins), c(.two, .coins), c(.three, .coins), c(.four, .coins), c(.six, .coins)]
        #expect(Scoring.napola(of: run) == 4)
        #expect(Scoring.napola(of: Array(run.prefix(3))) == 3)
        #expect(Scoring.napola(of: [c(.ace, .coins), c(.three, .coins), c(.four, .coins)]) == 0)
        #expect(Scoring.napola(of: Deck.standard) == 10)

        let score = Scoring.score(captures: [[c(.two)], run], scope: [0, 0], house: [.napola])
        #expect(score.points(for: .napola, side: 1) == 4)
        #expect(score.categoryWinners[.napola] == 1)
    }

    @Test func aClassicRoundScoresNoHouseCategory() {
        let score = Scoring.score(captures: [[.reBello, c(.ace, .coins), c(.two, .coins), c(.three, .coins)], []],
                                  scope: [0, 0])
        #expect(score.categoryWinners[.reBello] == nil)
        #expect(score.categoryWinners[.napola] == nil)
        #expect(score.points == [3, 0])
    }

    @Test func theTableScoresWithItsOwnRules() throws {
        var state = GameState(configuration: try table([.reBello]))
        let round = Round(stock: [], table: [], hands: [[c(.two)], []],
                          captures: [[.reBello], [c(.three)]], scope: [0, 0], turnSeat: 0, lastCaptureSide: 0)
        state.round = round
        state.phase = .playing
        let (after, _) = try Rules.apply(Move(seat: 0, card: c(.two)), to: state)
        guard case .roundOver(let score) = after.phase else { Issue.record("round did not end"); return }
        #expect(score.points(for: .reBello, side: 0) == 1)
    }
}

@Suite struct HouseRulesOnTheWire {
    @Test func aClassicTableEncodesAsItAlwaysDid() throws {
        let data = try JSONEncoder().encode(try table([]))
        #expect(!String(decoding: data, as: UTF8.self).contains("house"))
    }

    @Test func houseRulesRoundTrip() throws {
        let config = try table([.scopone, .napola], seats: 4, teams: true)
        let back = try JSONDecoder().decode(GameConfiguration.self, from: try JSONEncoder().encode(config))
        #expect(back == config)
    }

    @Test func aRuleFromALaterBuildIsDropped() throws {
        var json = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(try table([.reBello]))) as! [String: Any]
        json["house"] = ["reBello", "cirulla"]
        let back = try JSONDecoder().decode(GameConfiguration.self, from: try JSONSerialization.data(withJSONObject: json))
        #expect(back.house == [.reBello])
    }
}
