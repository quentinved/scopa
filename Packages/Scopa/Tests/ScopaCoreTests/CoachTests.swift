import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

/// A view of a two-handed table, on turn unless said otherwise. `taken` is what has gone
/// into the piles face up, which is what lets the coach count the deck.
private func view(hand: [Card], table: [Card], stock: Int = 20, turnSeat: Int = 0,
                  taken: [[Card]] = [[], []], opponentCards: Int = 3) -> PlayerView {
    let players = [Player(id: PlayerID(rawValue: "a"), name: "A"),
                   Player(id: PlayerID(rawValue: "b"), name: "B")]
    let configuration = try! GameConfiguration(players: players)
    return PlayerView(
        seat: 0, hand: hand, table: table,
        opponents: [.init(seat: 1, player: players[1], cardsInHand: opponentCards)],
        stockCount: stock, captureCounts: taken.map(\.count), captures: taken[0], capturedBySide: taken,
        scope: [0, 0], scores: [0, 0],
        turnSeat: turnSeat, phase: .playing, roundNumber: 1, configuration: configuration
    )
}

private func counsel(_ view: PlayerView, for card: Card) throws -> Coach.Counsel {
    try #require(Coach.counsel(for: card, in: view))
}

@Suite struct CoachOnYourHand {
    @Test func weighsEveryCardInHand() {
        let hand = [c(.seven, .cups), c(.king), c(.two)]
        let counsels = Coach.hand(view(hand: hand, table: [c(.four), c(.three)]))
        #expect(counsels.map(\.card) == hand)
    }

    @Test func namesTheSweepAndCallsItTheBestThereIs() throws {
        let table = [c(.four), c(.three)]
        let counsel = try counsel(view(hand: [c(.seven, .cups), c(.king)], table: table), for: c(.seven, .cups))
        #expect(counsel.sweeps)
        #expect(counsel.standing == .best)
        #expect(counsel.reasons.first == .sweeps)
        #expect(Set(counsel.captures) == Set(table))
    }

    /// Two ways to take with one card. The counsel is on the one the interface fills in.
    @Test func counselsTheBiggerOfTwoTakes() throws {
        let counsel = try counsel(view(hand: [c(.seven, .cups)], table: [c(.four), c(.three), c(.two)]),
                                  for: c(.seven, .cups))
        #expect(Set(counsel.captures) == Set([c(.four), c(.three)]))
    }

    @Test func saysWhenTheSettebelloIsComingOver() throws {
        let counsel = try counsel(view(hand: [c(.seven, .cups), c(.king)],
                                       table: [.settebello, c(.king, .cups), c(.two)]),
                                  for: c(.seven, .cups))
        #expect(counsel.reasons.contains(.takesSettebello))
        #expect(counsel.reasons.contains(.takesCoins(1)))
    }

    @Test func aLayIsToldWhyItCannotTake() throws {
        let counsel = try counsel(view(hand: [c(.two, .cups), c(.king)], table: [c(.five), c(.six)]),
                                  for: c(.two, .cups))
        #expect(counsel.captures.isEmpty)
        #expect(counsel.reasons.first == .nothingMatches)
    }

    /// Both cards have to go down. The coach names the cheap one as cheap and the seven of
    /// coins as what it is.
    @Test func picksOutTheCheapestCardToGiveUp() throws {
        let table = [c(.two), c(.three)]
        let position = view(hand: [.settebello, c(.king, .swords)], table: table)
        #expect(try counsel(position, for: c(.king, .swords)).reasons.contains(.cheapestToLose))
        let seven = try counsel(position, for: .settebello)
        #expect(seven.warnings.contains(.givesTheSettebello))
        #expect(seven.standing == .costly)
    }

    @Test func warnsAboutTheSweepALayWouldLeave() throws {
        // A four and a five on the table: laying the ace makes ten, and anybody's king sweeps it.
        let counsel = try counsel(view(hand: [c(.ace, .swords), c(.knight, .swords)],
                                       table: [c(.four), c(.five)]),
                                  for: c(.ace, .swords))
        #expect(counsel.warnings.contains(.leavesASweep(.king)))
        #expect(counsel.standing == .costly)
    }

    /// The same table, with every king already taken. Nobody can be holding one, so there
    /// is nothing to warn about: a coach that cries wolf is not worth listening to.
    @Test func doesNotWarnAboutARankThatIsAllAccountedFor() throws {
        let kings = Suit.allCases.map { Card(.king, of: $0) }
        let counsel = try counsel(view(hand: [c(.ace, .swords), c(.knight, .swords)],
                                       table: [c(.four), c(.five)], taken: [kings, []]),
                                  for: c(.ace, .swords))
        #expect(!counsel.warnings.contains { if case .leavesASweep = $0 { true } else { false } })
    }

    @Test func theLastCardOfARoundSweepsUpWhatIsLeftOver() throws {
        let counsel = try counsel(view(hand: [c(.three, .cups)], table: [c(.three), c(.king), c(.six)],
                                       stock: 0, opponentCards: 0),
                                  for: c(.three, .cups))
        #expect(counsel.reasons.contains(.onlyMove))
        #expect(counsel.reasons.contains(.takesTheLeftovers))
        // Clearing the table with the last card of the round is not a scopa.
        #expect(!counsel.sweeps)
    }

    @Test func aForcedMoveIsSaidToBeForced() throws {
        let counsel = try counsel(view(hand: [c(.king)], table: [c(.two)]), for: c(.king))
        #expect(counsel.reasons == [.onlyMove, .nothingMatches])
    }

    @Test func saysNothingAboutAHandItCannotSee() {
        #expect(Coach.hand(view(hand: [], table: [c(.four)])).isEmpty)
    }
}

@Suite struct CoachOnTheirMove {
    @Test func tellsBackWhatTheirTakeCarriedOff() {
        let reading = Coach.reading(of: c(.seven, .cups), taking: [.settebello], sweeps: false,
                                    in: view(hand: [c(.king)], table: [c(.two)]))
        #expect(reading.notes.contains(.takesSettebello))
        // One coin: the seven of coins itself. The card that took it was a cup.
        #expect(reading.notes.contains(.takesCoins(1)))
    }

    @Test func aSweepIsTheFirstThingItSays() {
        let reading = Coach.reading(of: c(.seven, .cups), taking: [c(.four), c(.three)], sweeps: true,
                                    in: view(hand: [c(.king)], table: []))
        #expect(reading.notes.first == .sweeps)
    }

    @Test func aLaidCardIsExplainedAsOneThatCouldNotTake() {
        let reading = Coach.reading(of: c(.three, .coins), taking: [], sweeps: false,
                                    in: view(hand: [c(.king)], table: [c(.three, .coins), c(.knave)]))
        #expect(reading.notes.contains(.nothingMatches))
        #expect(reading.notes.contains(.givesACoin))
    }

    /// The whole point of reading their move: what it left you.
    @Test func answersWithYourOwnBestReply() throws {
        let table = [c(.four), c(.three)]
        let reading = Coach.reading(of: c(.four, .coins), taking: [], sweeps: false,
                                    in: view(hand: [c(.seven, .cups), c(.king)], table: table))
        let answer = try #require(reading.answer)
        #expect(answer.card == c(.seven, .cups))
        #expect(answer.sweeps)
    }

    /// At somebody else's turn there is no reply to give, so it does not invent one.
    @Test func keepsQuietWhenItIsNotYourMove() {
        let reading = Coach.reading(of: c(.four), taking: [], sweeps: false,
                                    in: view(hand: [c(.seven, .cups)], table: [c(.four)], turnSeat: 1))
        #expect(reading.answer == nil)
    }
}

/// Counting the deck from one seat: the sum behind the coach's warnings, and behind the
/// row of numbers the table draws for a player who asks for it.
@Suite struct CountingWhatIsLeft {
    @Test func startsAtFourOfEachRankNobodyHasSeen() {
        let seat = view(hand: [c(.king)], table: [])
        #expect(seat.unseen(.two) == 4)
        #expect(seat.unseen(.seven) == 4)
    }

    /// Your own hand, the cloth and every pile are all face up to you, so each counts away.
    @Test func countsAwayTheHandTheClothAndThePiles() {
        let seat = view(hand: [c(.three, .cups), c(.three, .coins)],
                        table: [c(.three, .swords)],
                        taken: [[c(.seven, .cups)], [c(.seven, .coins), c(.seven, .swords)]])
        #expect(seat.unseen(.three) == 1)
        #expect(seat.unseen(.seven) == 1)
    }

    /// A rank entirely accounted for reads zero rather than going negative or wrapping.
    @Test func bottomsOutAtNoneLeft() {
        let all = Suit.allCases.map { Card(.ace, of: $0) }
        let seat = view(hand: [all[0]], table: [all[1]], taken: [[all[2]], [all[3]]])
        #expect(seat.unseen(.ace) == 0)
    }

    /// What the other players are holding is not counted away: that is the part the player
    /// is working out, and counting it would be peeking rather than counting.
    @Test func leavesWhatOthersHoldAmongTheUnseen() {
        let seat = view(hand: [c(.five, .cups)], table: [], opponentCards: 3)
        #expect(seat.unseen(.five) == 3)
    }
}
