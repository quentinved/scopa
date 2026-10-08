import Testing
@testable import ScopaCore

private func hand(cards: Int? = nil, coins: Int? = nil, settebello: Int? = nil, primiera: Int? = nil,
                  scope: [Int] = [0, 0]) -> ScorePad.Hand {
    var hand = ScorePad.Hand(sides: scope.count)
    hand.cards = cards
    hand.coins = coins
    hand.settebello = settebello
    hand.primiera = primiera
    hand.scope = scope
    return hand
}

@Test func aHandPaysEachPointAndEveryScopa() {
    let points = hand(cards: 0, coins: 1, settebello: 0, primiera: nil, scope: [2, 1]).points(sides: 2)
    #expect(points == [4, 2])
}

@Test func totalsAddUpTheHands() {
    var pad = ScorePad(sides: ["Anna", "Marco", "Luca"])
    pad.add(hand(cards: 2, coins: 2, settebello: 1, primiera: 2, scope: [0, 1, 0]))
    pad.add(hand(cards: 0, settebello: 0, scope: [1, 0, 0]))
    #expect(pad.totals == [3, 2, 3])
}

@Test func reachingTheTargetLevelIsNoWin() {
    var pad = ScorePad(sides: ["A", "B"], target: 5)
    pad.add(hand(cards: 0, coins: 0, settebello: 1, primiera: 1, scope: [1, 3]))
    #expect(pad.totals == [3, 5])
    #expect(pad.winner == 1)

    var level = ScorePad(sides: ["A", "B"], target: 3)
    level.add(hand(cards: 0, coins: 0, settebello: 1, primiera: 1, scope: [1, 1]))
    #expect(level.totals == [3, 3])
    #expect(level.winner == nil)
}

@Test func aFinishedPadTakesNoMoreHands() {
    var pad = ScorePad(sides: ["A", "B"], target: 4)
    pad.add(hand(cards: 0, coins: 0, settebello: 0, primiera: 0))
    pad.add(hand(cards: 1))
    #expect(pad.hands.count == 1)
}

@Test func undoAndRestartKeepTheTable() {
    var pad = ScorePad(sides: ["A", "B"], target: 21)
    pad.add(hand(cards: 0))
    pad.add(hand(coins: 1))
    pad.undo()
    #expect(pad.totals == [1, 0])
    pad.restart()
    #expect(pad.hands.isEmpty)
    #expect(pad.sides == ["A", "B"] && pad.target == 21)
}
