import Testing
@testable import ScopaCore

/// One tap plays: the first tap does what the second one would have, and nothing more.
@Suite struct OneTap {
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

    /// The only take, put together and sent — at normal too, where nothing was filled in.
    @Test(arguments: AssistLevel.allCases)
    func aLoneTakeGoesAtTheFirstTap(level: AssistLevel) throws {
        let three = Self.card(.three, .coins)
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: [three, Self.card(.king)])
        var selection = HandSelection(assist: level)
        #expect(selection.tapToPlay(Self.card(.three, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.three, .cups), captures: [three]),
                "\(level)")
    }

    @Test(arguments: AssistLevel.allCases)
    func aCardThatMatchesNothingIsLaidAtTheFirstTap(level: AssistLevel) throws {
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: [Self.card(.king), Self.card(.knight)])
        var selection = HandSelection(assist: level)
        #expect(selection.tapToPlay(Self.card(.two, .cups), in: view) == .play, "\(level)")
        #expect(selection.move(in: view) == Move(seat: 0, card: Self.card(.two, .cups)), "\(level)")
    }

    /// Two ways to take: nothing is sent and nothing is touched, so the caller picks the
    /// card up the way it always has.
    @Test(arguments: AssistLevel.allCases)
    func aChoiceIsLeftToThePlayer(level: AssistLevel) throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let view = try Self.view(hand: [Self.card(.five)], table: table)
        var selection = HandSelection(assist: level)
        #expect(selection.tapToPlay(Self.card(.five), in: view) == .select, "\(level)")
        #expect(selection.isEmpty, "\(level)")
    }

    @Test func nothingGoesOutOfTurn() throws {
        let view = try Self.view(hand: [Self.card(.two, .cups)], table: [Self.card(.king)], turn: 1)
        var selection = HandSelection(assist: .beginner)
        #expect(selection.tapToPlay(Self.card(.two, .cups), in: view) == .select)
        #expect(selection.isEmpty)
    }

    /// Another card already up does not stop the one tapped from going.
    @Test func theCardTappedIsTheOneThatGoes() throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let view = try Self.view(hand: [Self.card(.five), Self.card(.king, .cups)], table: table)
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.five), on: table)
        // The king's one take is all four, which sums to ten.
        #expect(selection.tapToPlay(Self.card(.king, .cups), in: view) == .play)
        #expect(selection.move(in: view)?.card == Self.card(.king, .cups))
        #expect(selection.chosen == Set(table))
    }

    /// A take the player is building is theirs to finish, so the tap on its card means
    /// "put it down", as it does without the setting.
    @Test func aHalfBuiltTakeIsNotSent() throws {
        let table = [Self.card(.ace), Self.card(.two), Self.card(.king)]
        let view = try Self.view(hand: [Self.card(.three, .cups)], table: table)
        var selection = HandSelection(assist: .normal)
        selection.select(Self.card(.three, .cups), on: table)
        selection.toggle(Self.card(.ace), on: table)
        #expect(selection.tapToPlay(Self.card(.three, .cups), in: view) == .select)
        #expect(selection.chosen == [Self.card(.ace)])
    }

    /// What the hint reads: every card with one move when one tap plays, and otherwise
    /// only the card already up.
    @Test func theHintKnowsWhichCardsGoAtOnce() throws {
        let table = [Self.card(.ace), Self.card(.four), Self.card(.two), Self.card(.three)]
        let hand = [Self.card(.five), Self.card(.king, .cups), Self.card(.ace, .cups)]
        let view = try Self.view(hand: hand, table: table)
        var selection = HandSelection(assist: .beginner)
        #expect(selection.playsOnTap(in: view, oneTap: true) == [Self.card(.king, .cups), Self.card(.ace, .cups)])
        #expect(selection.playsOnTap(in: view, oneTap: false).isEmpty)
        selection.select(Self.card(.king, .cups), on: table)
        #expect(selection.playsOnTap(in: view, oneTap: false) == [Self.card(.king, .cups)])
    }
}
