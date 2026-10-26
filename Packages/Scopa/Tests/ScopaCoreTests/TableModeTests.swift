import Foundation
import Testing
@testable import ScopaCore

// The campaign's second road: a start already behind, one round, every hand face up, and a
// run of games in a row.

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

private func players(_ count: Int) -> [Player] {
    (0..<count).map { Player(id: .init(rawValue: "p\($0)"), name: "P\($0)") }
}

private func duel(target: Int = 7, headStart: [Int] = [], openHands: Bool = false) throws -> GameConfiguration {
    try GameConfiguration(players: players(2), targetScore: target, turnClock: .off, headStart: headStart,
                          openHands: openHands)
}

/// A round over, its piles split as given: `first` to side 0 and every other card to side 1.
private func ended(_ state: GameState, first: [Card]) -> GameState {
    let taken = Set(first)
    let rest = Deck.standard.filter { !taken.contains($0) }
    let round = Round(stock: [], table: [], hands: [[], []], captures: [first, rest], scope: [0, 0],
                      turnSeat: 0, lastCaptureSide: 1)
    var playing = state
    playing.phase = .playing
    playing.round = round
    return Rules.finishRound(playing, round, []).0
}

/// Twenty-one cards and six coins to side 0, every seven to side 1: two points each.
private var levelSplit: [Card] {
    let sevens = Set(Suit.allCases.map { Card(.seven, of: $0) })
    let low: Set<Card> = [c(.ace, .coins), c(.two, .coins), c(.three, .coins)]
    return Array(Deck.standard.filter { !sevens.contains($0) && !low.contains($0) }.prefix(21))
}

@Suite struct Rimonta {
    @Test func theHeadStartIsOnTheBoardBeforeACardIsDealt() throws {
        let config = try duel(headStart: [0, 3])
        var rng = SeededGenerator(seed: 4)
        let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
        #expect(state.scores == [0, 3])
        #expect(state.view(forSeat: 0).scores == [0, 3])
    }

    @Test func aHeadStartFitsTheTable() throws {
        #expect(throws: ConfigurationError.invalidHeadStart) { try duel(headStart: [0, 3, 3]) }
        #expect(throws: ConfigurationError.invalidHeadStart) { try duel(target: 7, headStart: [0, 7]) }
        #expect(throws: ConfigurationError.invalidHeadStart) { try duel(headStart: [0, -1]) }
        // Two sides in teams, whatever the chairs.
        let teams = try GameConfiguration(players: players(4), teams: true, targetScore: 7, headStart: [0, 2])
        #expect(GameState(configuration: teams).scores == [0, 2])
    }

    @Test func theRaceToTheTargetIsTheUsualOne() throws {
        let behind = try duel(target: 7, headStart: [0, 6])
        // Every point of the round to side 0 is four, which leaves the race on.
        let still = ended(GameState(configuration: behind), first: Deck.standard)
        #expect(still.scores == [4, 6] && !still.isFinished)
        let close = try duel(target: 7, headStart: [3, 6])
        #expect(ended(GameState(configuration: close), first: Deck.standard).phase == .finished(winnerSide: 0))
    }

    /// Two level players at the campaign's comeback tables: the one behind still wins about one
    /// game in three, which is a comeback and not a giveaway.
    @Test(arguments: [(6, 2), (7, 2), (8, 2)])
    func aLevelPlayerCanStillComeBack(target: Int, deficit: Int) throws {
        let config = try GameConfiguration(players: players(2), targetScore: target, turnClock: .off,
                                           headStart: [0, deficit])
        let bot = Bot(strength: BotStrength(searches: false, follows: 1))
        let games = 150
        let wins = (0..<games).count { seed in playOut(config, bot: bot, seed: UInt64(seed) &+ 11) == 0 }
        #expect((games / 5...games / 2).contains(wins))
    }

    private func playOut(_ config: GameConfiguration, bot: Bot, seed: UInt64) -> Int? {
        var rng = SeededGenerator(seed: seed)
        var state = GameState(configuration: config, dealerSeat: Int(seed % 2))
        for _ in 0..<40 {
            (state, _) = Rules.startRound(state, using: &rng)
            while state.phase == .playing, let seat = state.round?.turnSeat,
                  let move = bot.move(for: state.view(forSeat: seat), using: &rng) {
                guard let next = try? Rules.apply(move, to: state).0 else { return nil }
                state = next
            }
            if case .finished(let winner) = state.phase { return winner }
        }
        return nil
    }
}

@Suite struct UnaMano {
    @Test func whoeverLeadsAfterTheRoundWins() throws {
        let state = ended(GameState(configuration: try duel(target: 1)), first: Deck.standard)
        #expect(state.phase == .finished(winnerSide: 0))
        #expect(state.scores == [4, 0])
    }

    @Test func aLevelRoundDealsAnother() throws {
        let level = ended(GameState(configuration: try duel(target: 1)), first: levelSplit)
        #expect(level.scores == [2, 2])
        guard case .roundOver = level.phase else { Issue.record("a level round ended the game"); return }
        // The totals carry on, and the next round decides.
        let decided = ended(level, first: [])
        #expect(decided.phase == .finished(winnerSide: 1))
        #expect(decided.scores == [2, 6])
    }
}

@Suite struct CarteScoperte {
    /// Seat 0 to play six and three of swords over an ace; seat 1 holds `theirs`.
    private func view(openHands: Bool, theirs: [Card] = [c(.four), c(.king, .coins), c(.king, .cups)],
                      emptyStock: Bool = false) throws -> PlayerView {
        let mine = [c(.six, .swords), c(.three, .swords)]
        let table = [c(.ace)]
        let used = Set(mine + table + theirs)
        let rest = Deck.standard.filter { !used.contains($0) }
        var state = GameState(configuration: try duel(openHands: openHands))
        let half = rest.count / 2
        state.round = Round(stock: emptyStock ? [] : rest, table: table, hands: [mine, theirs],
                            captures: emptyStock ? [Array(rest.prefix(half)), Array(rest.dropFirst(half))] : [[], []],
                            scope: [0, 0], turnSeat: 0, lastCaptureSide: nil)
        state.phase = .playing
        return state.view(forSeat: 0)
    }

    @Test func everyHandIsInTheView() throws {
        let config = try duel(openHands: true)
        var rng = SeededGenerator(seed: 8)
        let (state, _) = Rules.startRound(GameState(configuration: config), using: &rng)
        #expect(state.view(forSeat: 0).opponents.first?.hand == state.round?.hands[1])
        #expect(state.view(forSeat: 1).opponents.first?.hand == state.round?.hands[0])
        let hidden = Rules.startRound(GameState(configuration: try duel()), using: &rng).0
        #expect(hidden.view(forSeat: 0).opponents.first?.hand == nil)
    }

    @Test func aHiddenTableReadsOnTheWireAsBefore() throws {
        let classic = String(decoding: try JSONEncoder().encode(try duel()), as: UTF8.self)
        #expect(!classic.contains("openHands") && !classic.contains("headStart"))
        let opponent = PlayerView.Opponent(seat: 1, player: players(2)[1], cardsInHand: 3)
        #expect(!String(decoding: try JSONEncoder().encode(opponent), as: UTF8.self).contains("hand\""))
        // And a table that has them takes them across and back.
        let open = try duel(headStart: [0, 2], openHands: true)
        #expect(try JSONDecoder().decode(GameConfiguration.self, from: JSONEncoder().encode(open)) == open)
    }

    @Test func theSearchDealsOnlyTheStock() throws {
        var rng = SeededGenerator(seed: 2)
        let open = try view(openHands: true)
        let worlds = Search.worlds(for: open, using: &rng)
        #expect(!worlds.isEmpty)
        #expect(worlds.allSatisfy { $0.round?.hands[1] == open.opponents[0].hand })
        // With the stock gone there is nothing left to guess.
        let last = try view(openHands: true, emptyStock: true)
        #expect(Search.worldCount(for: last) == 1)
        #expect(Search.worlds(for: last, using: &rng).first?.round?.hands[1] == last.opponents[0].hand)
    }

    @Test func theBotLaysWhatTheHandItSeesCannotSweep() throws {
        let bot = Bot(strength: BotStrength(searches: false, follows: 1))
        var rng = SeededGenerator(seed: 5)
        // Hidden, the three is the cheaper card to give, and either leaves a sweep to somebody.
        #expect(bot.move(for: try view(openHands: false), using: &rng)?.card == c(.three, .swords))
        // Face up, the four across the table would sweep the ace and the three, and nothing takes the six.
        #expect(bot.move(for: try view(openHands: true), using: &rng)?.card == c(.six, .swords))
    }
}

@Suite struct TorneoRun {
    @Test func eachWinBringsTheNextGame() {
        var run = Torneo(games: 3)
        #expect(run.game == 0)
        #expect(run.record(won: true) == .next)
        #expect(run.record(won: true) == .next)
        #expect(run.isLastGame)
    }

    @Test func aLossStartsItAgain() {
        var run = Torneo(games: 3, won: 2)
        #expect(run.record(won: false) == .lost)
        #expect(run.game == 0)
    }

    @Test func winningTheLastGameStartsANewRun() {
        var run = Torneo(games: 3, won: 2)
        #expect(run.record(won: true) == .champion)
        #expect(run.game == 0)
    }

    @Test func aStoredCountNeverPointsPastTheLastGame() {
        #expect(Torneo(games: 3, won: 9).game == 2)
        #expect(Torneo(games: 3, won: -2).game == 0)
        #expect(Torneo(games: 0).isLastGame)
    }
}
