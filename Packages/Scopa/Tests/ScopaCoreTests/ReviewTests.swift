import Foundation
import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

private func players(_ count: Int) -> [Player] {
    (0..<count).map { Player(id: .init(rawValue: "p\($0)"), name: "P\($0)") }
}

/// A two-handed view with the given hand and table, seat 0 to play.
private func view(hand: [Card], table: [Card], stock: Int = 20) -> PlayerView {
    let players = players(2)
    let configuration = try! GameConfiguration(players: players)
    return PlayerView(
        seat: 0, hand: hand, table: table,
        opponents: [.init(seat: 1, player: players[1], cardsInHand: 3)],
        stockCount: stock, captureCounts: [0, 0], scope: [0, 0], scores: [0, 0],
        turnSeat: 0, phase: .playing, roundNumber: 1, configuration: configuration
    )
}

private func judge(_ move: Move, in view: PlayerView) -> Verdict {
    Reviewer.judge(move, in: view, ordinal: 0, round: 1, bot: Bot()).verdict
}

/// Plays a whole game on a session, every seat choosing with `choose`, and hands back the session.
private func playGame(seats: Int, seed: UInt64, choose: (GameState) -> Move) async throws -> GameSession {
    let config = try GameConfiguration(players: players(seats), teams: seats == 4)
    let session = GameSession(configuration: config, rng: SeededGenerator(seed: seed))
    while await !session.state.isFinished {
        await session.startRound()
        while await session.state.phase == .playing {
            _ = try await session.play(choose(await session.state))
        }
    }
    return session
}

@Suite struct Records {
    @Test(arguments: [2, 3, 4])
    func aRecordReplaysToTheSameGame(seats: Int) async throws {
        let session = try await playGame(seats: seats, seed: 9) { Rules.automaticMove(in: $0)! }
        let record = await session.record
        let replayed = record.replay()
        #expect(replayed.final == (await session.state))
        #expect(replayed.steps.count == record.rounds.reduce(0) { $0 + $1.moves.count })
        #expect(record.hasMoves)
    }

    @Test func theDeckDealsTheSameRoundAgain() {
        var rng = SeededGenerator(seed: 5)
        let deck = Rules.shuffledDeck(using: &rng)
        let state = GameState(configuration: try! GameConfiguration(players: players(2)))
        #expect(Rules.deal(deck, into: state).0 == Rules.deal(deck, into: state).0)
        #expect(Rules.deal(deck, into: state).0.round?.table == Array(deck.suffix(4)))
    }

    @Test func aRecordSurvivesEncoding() async throws {
        let session = try await playGame(seats: 2, seed: 3) { Rules.automaticMove(in: $0)! }
        let record = await session.record
        let envelope = Envelope(from: PlayerID(rawValue: "p0"), message: .record(record))
        #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
    }
}

@Suite struct Verdicts {
    @Test func theBotsOwnMoveIsTheBest() {
        let v = view(hand: [c(.seven, .cups), c(.four, .cups)], table: [c(.four), c(.three)])
        #expect(judge(Move(seat: 0, card: c(.seven, .cups), captures: [c(.four), c(.three)]), in: v) == .scopa)
    }

    @Test func layingPastASweepIsAMissedScopa() {
        let v = view(hand: [c(.seven, .cups), c(.knight, .cups)], table: [c(.four), c(.three)])
        #expect(judge(Move(seat: 0, card: c(.knight, .cups)), in: v) == .missedScopa)
    }

    @Test func layingTheSevenOfCoinsIsGivingItAway() {
        let v = view(hand: [.settebello, c(.two, .cups)], table: [c(.knave)])
        #expect(judge(Move(seat: 0, card: .settebello), in: v) == .settebelloGiven)
    }

    @Test func leavingTheSevenOfCoinsOnTheTableIsMissingIt() {
        let v = view(hand: [c(.seven, .cups), c(.two, .cups)], table: [.settebello, c(.two)])
        #expect(judge(Move(seat: 0, card: c(.two, .cups), captures: [c(.two)]), in: v) == .settebelloMissed)
    }

    @Test func layingWhileAnotherCardCouldTakeIsAMissedTake() {
        let v = view(hand: [c(.six, .cups), c(.knight, .cups)], table: [c(.six), c(.two)])
        #expect(judge(Move(seat: 0, card: c(.knight, .cups)), in: v) == .missedTake)
    }

    @Test func theOnlyMoveIsForced() {
        let v = view(hand: [c(.ace)], table: [c(.king)])
        #expect(judge(Move(seat: 0, card: c(.ace)), in: v) == .forced)
    }

    /// Both piles were two cards, so "you took the smaller pile" would be a lie. What was
    /// wrong with it was what was in it.
    @Test func takingTheSameNumberOfWorseCardsIsNotASmallerPile() {
        let table = [c(.four, .coins), c(.five, .coins), c(.four, .swords), c(.five, .swords)]
        let v = view(hand: [c(.knight, .cups)], table: table)
        let move = Move(seat: 0, card: c(.knight, .cups), captures: [c(.four, .swords), c(.five, .swords)])
        #expect(judge(move, in: v) == .tookTheWrongCards)
    }

    /// Nothing to take and an empty table, so neither card opens anything: the two moves
    /// differ only in what was handed over, and the lesson has to say so.
    @Test func layingTheCoinRatherThanTheClubIsGivingACardAway() {
        let v = view(hand: [c(.three, .coins), c(.three, .clubs)], table: [])
        #expect(judge(Move(seat: 0, card: c(.three, .coins)), in: v) == .gaveAwayAGoodCard)
    }

    /// And when the table really is the thing that was opened, it still says that.
    @Test func layingIntoASweepIsOpeningTheTable() {
        let v = view(hand: [c(.three, .swords), c(.king, .swords)], table: [c(.four), c(.two)])
        #expect(judge(Move(seat: 0, card: c(.three, .swords)), in: v) == .exposedTable)
    }

    @Test func takingTheSevenOfCoinsIsPraised() {
        let v = view(hand: [c(.seven, .cups), c(.king)], table: [.settebello, c(.king, .cups), c(.two)])
        #expect(judge(Move(seat: 0, card: c(.seven, .cups), captures: [.settebello]), in: v) == .settebello)
    }
}

@Suite struct Summaries {
    @Test func aGamePlayedByTheBotIsAllPraise() async throws {
        var rng = SeededGenerator(seed: 21)
        let session = try await playGame(seats: 2, seed: 8) { state in
            Bot().move(for: state.view(forSeat: state.round!.turnSeat), using: &rng)!
        }
        let review = Reviewer.review(await session.record)
        for seat in 0..<2 {
            let summary = review.summary(forSeat: seat)
            #expect(summary.accuracy == 100)
            #expect(summary.lessons.isEmpty)
            #expect(summary.lessonCount == 0)
        }
    }

    @Test func aCarelessGameHasLessons() async throws {
        // Every seat lays whenever it can and takes the smallest pile otherwise.
        let session = try await playGame(seats: 2, seed: 8) { state in
            let round = state.round!
            let hand = round.hands[round.turnSeat]
            if let lay = hand.first(where: { Rules.captureOptions(for: $0, on: round.table).isEmpty }) {
                return Move(seat: round.turnSeat, card: lay)
            }
            let card = hand[0]
            let take = Rules.captureOptions(for: card, on: round.table).min { $0.count < $1.count }!
            return Move(seat: round.turnSeat, card: card, captures: take)
        }
        let review = Reviewer.review(await session.record)
        let summary = review.summary(forSeat: 0)
        #expect(summary.accuracy < 100)
        #expect(!summary.lessons.isEmpty)
        #expect(summary.lessons == summary.lessons.sorted { $0.gap > $1.gap })
        #expect(review.moves.allSatisfy { $0.view.seat == $0.seat && $0.view.hand.contains($0.move.card) })
    }

    /// A summary asked for one round covers that round and nothing either side of it.
    ///
    /// The panel that shows the accuracy mid-game is headed "Round N", and it used to show
    /// the whole game to that point, so from round two on it was an average that could only
    /// converge and read within a point or two of the same number. The round
    /// is also the unit that discriminates: over twelve games a seat playing at random
    /// scored 81-97 per game but 59-99 per round, because twelve judged moves do not bury a
    /// mistake the way fifty do.
    @Test func aRoundSummaryCoversOnlyThatRound() async throws {
        // Every seat lays whenever it can, which earns lessons in every round.
        let session = try await playGame(seats: 2, seed: 8) { state in
            let round = state.round!
            let hand = round.hands[round.turnSeat]
            if let lay = hand.first(where: { Rules.captureOptions(for: $0, on: round.table).isEmpty }) {
                return Move(seat: round.turnSeat, card: lay)
            }
            let card = hand[0]
            let take = Rules.captureOptions(for: card, on: round.table).min { $0.count < $1.count }!
            return Move(seat: round.turnSeat, card: card, captures: take)
        }
        let review = Reviewer.review(await session.record)
        let rounds = Set(review.moves(forSeat: 0).map(\.round)).sorted()
        #expect(rounds.count > 1, "the game has to run past one round for this to mean anything")

        let whole = review.summary(forSeat: 0)
        for round in rounds {
            let summary = review.summary(forSeat: 0, round: round)
            #expect(summary.lessons.allSatisfy { $0.round == round })
            #expect(summary.highlights.allSatisfy { $0.round == round })
        }
        // Every move is counted once across the rounds, and nowhere twice.
        let perRound = rounds.map { review.summary(forSeat: 0, round: $0) }
        #expect(perRound.reduce(0) { $0 + $1.lessonCount } == whole.lessonCount)
        #expect(perRound.reduce(0) { $0 + $1.praiseCount } == whole.praiseCount)
        // And the round's own number is free to leave the whole game's behind, which is the
        // point of asking for it.
        #expect(perRound.map(\.accuracy).contains { $0 != whole.accuracy })
    }
}

@Suite struct SecondLooks {
    /// The same game read back twice reads the same way. The second look samples the hands
    /// it could not see, and the number that comes out is what the daily ladder ranks people
    /// by, so it is seeded from the game itself rather than from the clock.
    @Test func aGameIsReviewedTheSameWayEveryTime() async throws {
        let session = try await playGame(seats: 2, seed: 11) { Rules.automaticMove(in: $0)! }
        let record = await session.record
        #expect(Reviewer.review(record).moves == Reviewer.review(record).moves)
        #expect(record.signature == record.signature)
    }

    /// A whole game played by the hard bot comes back all but spotless.
    ///
    /// Not literally spotless: the review samples the hidden hands and so did the bot, and
    /// two honest samplings of the same position can land a little apart. What matters is
    /// the size of it: a careless game earns dozens of lessons and a well-played one earns
    /// one or two. Being told off for a move a better player would have made is the one
    /// thing a review must not do.
    @Test func aGamePlayedByTheHardBotIsAllButSpotless() async throws {
        var rng = SeededGenerator(seed: 4)
        let session = try await playGame(seats: 2, seed: 6) { state in
            Bot(level: .hard).move(for: state.view(forSeat: state.round!.turnSeat), using: &rng)!
        }
        let review = Reviewer.review(await session.record)
        for seat in 0..<2 {
            let summary = review.summary(forSeat: seat)
            #expect(summary.lessonCount <= 1, "the hard bot was given \(summary.lessonCount) lessons")
            #expect(summary.accuracy >= 98, "the hard bot was marked at \(summary.accuracy)%")
        }
    }

    /// The number has to agree with the page it sits on. A game with nothing to teach about
    /// came out at 97% under a heading that said every move was the one to make, because
    /// every lesson the search let off was priced at the very top of the near-miss band
    /// whatever the search had actually said about it.
    @Test func aGameWithNothingToTeachReadsLikeOne() async throws {
        var rng = SeededGenerator(seed: 4)
        let session = try await playGame(seats: 2, seed: 6) { state in
            Bot(level: .hard).move(for: state.view(forSeat: state.round!.turnSeat), using: &rng)!
        }
        let review = Reviewer.review(await session.record)
        let spotless = (0..<2).map { review.summary(forSeat: $0) }.filter { $0.lessons.isEmpty }
        #expect(!spotless.isEmpty)
        for summary in spotless {
            #expect(summary.accuracy >= 99, "a game with no lessons in it was marked at \(summary.accuracy)%")
        }
    }
}

@Suite struct DailyDeals {
    @Test func theSameDayDealsTheSameDeck() {
        var a = DailyDeal.generator(for: "2026-09-08")
        var b = DailyDeal.generator(for: "2026-09-08")
        var c = DailyDeal.generator(for: "2026-09-09")
        #expect(Rules.shuffledDeck(using: &a) == Rules.shuffledDeck(using: &b))
        #expect(Rules.shuffledDeck(using: &a) != Rules.shuffledDeck(using: &c))
    }

    @Test func theDayIsNamedInThePlayersCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 0, minute: 30))!
        #expect(DailyDeal.day(for: date, calendar: calendar) == "2026-09-08")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(DailyDeal.day(for: date, calendar: utc) == "2026-09-07")
    }
}

@Suite struct Rankings {
    @Test func aRatingReadsAsALeagueAndADivision() {
        #expect(Ranking.standing(for: 0).title == "Bronze III")
        #expect(Ranking.standing(for: 250).title == "Bronze I")
        #expect(Ranking.standing(for: 300).title == "Silver III")
        #expect(Ranking.standing(for: 1799).title == "Maestro I")
        #expect(Ranking.standing(for: 5000).title == "Maestro I")
        #expect(Ranking.standing(for: 420).progress == 20)
    }

    @Test func winsPayByWhoWasBeaten() {
        #expect(Ranking.points(won: true, opponentAbove: 2, in: .gold) == 30)
        #expect(Ranking.points(won: true, opponentAbove: 0, in: .gold) == 20)
        #expect(Ranking.points(won: true, opponentAbove: -3, in: .gold) == 5)
        #expect(Ranking.points(won: false, opponentAbove: 0, in: .gold) == -12)
        #expect(Ranking.points(won: false, opponentAbove: 0, in: .bronze) == -6)
        #expect(Ranking.points(won: false, opponentAbove: -1, in: .platinum) == -20)
    }

    @Test func aLeagueReachedIsAFloor() {
        let (rating, floor) = Ranking.apply(20, to: 290, floor: 0)
        #expect(rating == 310 && floor == 300)
        let (dropped, kept) = Ranking.apply(-50, to: rating, floor: floor)
        #expect(dropped == 300 && kept == 300)
    }

    @Test func aWinnerCollectsFromEveryLoser() {
        #expect(Ranking.change(for: 100, others: [100, 100, 100], won: true, winner: nil) == 40)
        #expect(Ranking.change(for: 100, others: [400], won: false, winner: 400) == -2)
    }

    @Test func fiveEvenWinsAreADivision() {
        var rating = 600, floor = 600
        for _ in 0..<5 {
            (rating, floor) = Ranking.apply(Ranking.change(for: rating, others: [rating], won: true, winner: nil),
                                            to: rating, floor: floor)
        }
        #expect(Ranking.standing(for: rating).title == "Gold II")
        #expect(rating == 700)
    }

    @Test func aRunPaysOnTopOfTheTable() {
        #expect(Ranking.streakBonus(after: 0) == 0)
        #expect(Ranking.streakBonus(after: 1) == 2)
        #expect(Ranking.streakBonus(after: 4) == 8)
        // It stops climbing, so a long run is a bonus and not a ladder of its own.
        #expect(Ranking.streakBonus(after: 5) == 10)
        #expect(Ranking.streakBonus(after: 40) == 10)
        // Paid over the table's own cap, and only to the winner.
        #expect(Ranking.change(for: 100, others: [100, 100, 100], won: true, winner: nil, streak: 3) == 46)
        #expect(Ranking.change(for: 100, others: [400], won: false, winner: 400, streak: 3) == -2)
    }

    @Test func aRunEndsOnALoss() {
        #expect(Ranking.streak(after: true, from: 0) == 1)
        #expect(Ranking.streak(after: true, from: 4) == 5)
        #expect(Ranking.streak(after: false, from: 9) == 0)
    }

    /// Five in a row is a division and change: the run is what pays the "and change".
    @Test func aRunClimbsFasterThanTheSameWinsScattered() {
        func climb(streaking: Bool) -> Int {
            var rating = 600, floor = 600, streak = 0
            for _ in 0..<5 {
                let change = Ranking.change(for: rating, others: [rating], won: true, winner: nil, streak: streak)
                (rating, floor) = Ranking.apply(change, to: rating, floor: floor)
                streak = streaking ? streak + 1 : 0
            }
            return rating
        }
        #expect(climb(streaking: false) == 700)
        #expect(climb(streaking: true) == 720)
    }
}
