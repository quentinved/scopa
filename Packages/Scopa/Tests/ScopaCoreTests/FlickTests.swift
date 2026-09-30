import Testing
@testable import ScopaCore

/// A card flicked at the table plays its one move, and leaves a real choice to the player.
@Suite struct Flick {
    private static func card(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

    private static func view(hand: [Card], table: [Card], turn: Int = 0) throws -> PlayerView {
        let players = [Player(id: .init(rawValue: "a"), name: "A"), Player(id: .init(rawValue: "b"), name: "B")]
        var state = GameState(configuration: try GameConfiguration(players: players))
        state.round = Round(
            stock: Array(repeating: Card(.king, of: .clubs), count: 10),
            table: table,
            hands: [hand, [Card(.two, of: .swords)]],
            captures: [[], []], scope: [0, 0], turnSeat: turn, lastCaptureSide: nil
        )
        state.phase = .playing
        return state.view(forSeat: 0)
    }

    /// At normal this used to lay the three, which the rules refuse: it has to take.
    @Test(arguments: AssistLevel.allCases)
    func aLoneTakeIsMade(level: AssistLevel) throws {
        let three = Self.card(.three, .coins)
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: [three, Self.card(.king)])
        var selection = HandSelection(assist: level)
        #expect(selection.flick(Self.card(.three, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.three, .cups), captures: [three]),
                "\(level)")
    }

    @Test(arguments: AssistLevel.allCases)
    func aCardThatMatchesNothingIsLaid(level: AssistLevel) throws {
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: [Self.card(.king), Self.card(.knight)])
        var selection = HandSelection(assist: level)
        #expect(selection.flick(Self.card(.two, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.two, .cups)), "\(level)")
    }

    /// Two ways to take: the card stays up, to choose from on the cloth.
    @Test(arguments: AssistLevel.allCases)
    func aChoiceLeavesTheCardUp(level: AssistLevel) throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let view = try Self.view(hand: [Self.card(.five)], table: table)
        var selection = HandSelection(assist: level)
        #expect(selection.flick(Self.card(.five), in: view) == .select, "\(level)")
        #expect(selection.card == Self.card(.five), "\(level)")
    }

    /// A take the player built goes as built, whichever of the two it is.
    @Test func aBuiltTakeIsSentAsBuilt() throws {
        let ace = Self.card(.ace), four = Self.card(.four)
        let view = try Self.view(hand: [Self.card(.five)], table: [ace, four, Self.card(.two), Self.card(.three)])
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.five), on: view.table)
        selection.toggle(ace, on: view.table)
        selection.toggle(four, on: view.table)
        #expect(selection.flick(Self.card(.five), in: view) == .play)
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.five), captures: [ace, four]))
    }

    @Test func nothingGoesOutOfTurn() throws {
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: [Self.card(.king)], turn: 1)
        var selection = HandSelection(assist: .normal)
        #expect(selection.flick(Self.card(.two, .cups), in: view) == .select)
        #expect(selection.isEmpty)
    }
}
