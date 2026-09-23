import Testing
@testable import ScopaCore

/// Reading a batch of events the way the table screen reads it.
///
/// These are the decisions behind what the screen announces: which card flew, what it took,
/// whether to shout "scopa", and whether a deal starts a round or only tops the hands up.
/// They used to live in the app where nothing could reach them.
@Suite struct EventDigests {
    static let sevenOfCoins = Card(.seven, of: .coins)
    static let threeOfCups = Card(.three, of: .cups)
    static let fourOfSwords = Card(.four, of: .swords)

    @Test func anEmptyBatchSaysNothingHappened() {
        let digest = EventDigest([])
        #expect(digest.played == nil)
        #expect(digest.captured.isEmpty)
        #expect(!digest.sweeps)
        #expect(!digest.isRefill)
        #expect(!digest.startsARound)
        #expect(digest.roundScore == nil)
    }

    @Test func aCardLaidDownTakesNothing() {
        let digest = EventDigest([.played(seat: 2, card: Self.threeOfCups)])
        #expect(digest.played?.seat == 2)
        #expect(digest.played?.card == Self.threeOfCups)
        #expect(digest.captured.isEmpty)
        #expect(!digest.sweeps)
    }

    @Test func aTakeCarriesTheCardsItWon() {
        let digest = EventDigest([
            .played(seat: 0, card: Self.sevenOfCoins),
            .captured(seat: 0, cards: [Self.threeOfCups, Self.fourOfSwords]),
        ])
        #expect(digest.played?.card == Self.sevenOfCoins)
        #expect(digest.captured == [Self.threeOfCups, Self.fourOfSwords])
        #expect(!digest.sweeps)
    }

    @Test func aSweepNamesTheSeatThatClearedTheTable() {
        let digest = EventDigest([
            .played(seat: 3, card: Self.sevenOfCoins),
            .captured(seat: 3, cards: [Self.threeOfCups]),
            .scopa(seat: 3),
        ])
        #expect(digest.sweeps)
        #expect(digest.sweptSeat == 3)
        #expect(digest.played?.seat == 3)
    }

    /// The distinction the deal banner hangs on: a deal after a card is the hands being
    /// topped up mid-round, and only a deal on its own opens a round.
    @Test func aDealAfterACardIsARefillRatherThanAFreshRound() {
        let digest = EventDigest([
            .played(seat: 1, card: Self.threeOfCups),
            .captured(seat: 1, cards: []),
            .dealt,
        ])
        #expect(digest.isRefill)
        #expect(!digest.startsARound)
    }

    @Test func aDealOnItsOwnStartsARound() {
        let digest = EventDigest([.dealt])
        #expect(!digest.isRefill)
        #expect(digest.startsARound)
        #expect(digest.played == nil)
    }

    @Test func theRoundsLastCardsGoToWhoeverCapturedLast() {
        let digest = EventDigest([
            .leftoverSwept(side: 1, cards: [Self.threeOfCups, Self.fourOfSwords]),
            .roundEnded(RoundScore(points: [3, 4], categoryWinners: [:], scope: [0, 1])),
        ])
        #expect(digest.leftovers?.side == 1)
        #expect(digest.leftovers?.cards.count == 2)
        #expect(digest.touchesLeftovers)
        #expect(digest.roundScore?.points == [3, 4])
    }

    /// The cloth is only ever cleared by a batch that says something about it. A plain move
    /// leaves the last round's cards where the screen put them.
    @Test func aPlainMoveLeavesTheLeftoversAlone() {
        let digest = EventDigest([.played(seat: 0, card: Self.threeOfCups)])
        #expect(!digest.touchesLeftovers)
        #expect(digest.leftovers == nil)
    }

    /// A fresh deal spends whatever the last round left behind, even when the same batch
    /// swept it up a moment earlier.
    @Test func aFreshDealSpendsTheLeftovers() {
        let swept = EventDigest([.leftoverSwept(side: 0, cards: [Self.threeOfCups]), .dealt])
        #expect(swept.touchesLeftovers)
        #expect(swept.leftovers == nil)

        let dealtAlone = EventDigest([.dealt])
        #expect(dealtAlone.touchesLeftovers)
        #expect(dealtAlone.leftovers == nil)
    }

    /// A refill inside a round is not a fresh deal, so it must not clear anything.
    @Test func aRefillLeavesTheLeftoversAlone() {
        let digest = EventDigest([
            .leftoverSwept(side: 1, cards: [Self.fourOfSwords]),
            .played(seat: 0, card: Self.threeOfCups),
            .dealt,
        ])
        #expect(digest.isRefill)
        #expect(digest.leftovers?.side == 1)
    }

    @Test func theEndOfTheGameNamesTheWinningSide() {
        let digest = EventDigest([
            .roundEnded(RoundScore(points: [11, 6], categoryWinners: [:], scope: [2, 0])),
            .gameEnded(winnerSide: 0),
        ])
        #expect(digest.winnerSide == 0)
        #expect(digest.roundScore?.scope == [2, 0])
    }

    /// The last of each kind wins, which is what the screen wants: one card in the air and
    /// one pile landing, however many events the batch carried.
    @Test func theLastCardInABatchIsTheOneShown() {
        let digest = EventDigest([
            .played(seat: 0, card: Self.threeOfCups),
            .captured(seat: 0, cards: [Self.fourOfSwords]),
            .played(seat: 1, card: Self.sevenOfCoins),
            .captured(seat: 1, cards: [Self.threeOfCups]),
        ])
        #expect(digest.played?.seat == 1)
        #expect(digest.played?.card == Self.sevenOfCoins)
        #expect(digest.captured == [Self.threeOfCups])
    }
}

/// The digest read off real games rather than hand-built batches, so the two cannot drift.
@Suite struct EventDigestsOverRealGames {
    @Test func everyBatchAGameProducesCanBeRead() async throws {
        let players = [Player(id: PlayerID(rawValue: "a"), name: "A"),
                       Player(id: PlayerID(rawValue: "b"), name: "B")]
        let configuration = try GameConfiguration(players: players, teams: false, targetScore: 11, turnClock: .off)
        let session = GameSession(configuration: configuration, rng: SeededGenerator(seed: 7))
        var sweeps = 0, cardsPlayed = 0, rounds = 0

        _ = await session.startRound()
        while await session.state.phase == .playing {
            guard let move = await Rules.automaticMove(in: session.state) else {
                _ = await session.startRound()
                continue
            }
            let digest = EventDigest(try await session.play(move))
            if digest.sweeps { sweeps += 1 }
            if digest.played != nil { cardsPlayed += 1 }
            if digest.roundScore != nil { rounds += 1 }
            // A card that took nothing never reports captures, and a sweep always names a seat.
            if digest.sweeps { #expect(digest.sweptSeat != nil) }
            if digest.played == nil { #expect(digest.captured.isEmpty) }
        }

        #expect(cardsPlayed > 0)
        #expect(rounds > 0)
        #expect(sweeps >= 0)
    }
}
