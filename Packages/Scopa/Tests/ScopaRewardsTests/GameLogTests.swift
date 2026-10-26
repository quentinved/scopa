import Foundation
import Testing
import ScopaCore
@testable import ScopaRewards

private typealias Seat = LoggedGame.Seat

private let you = Seat(name: "Quentin", isBot: false, side: 0, isYou: true)

private func person(_ name: String, side: Int = 1, id: String? = nil) -> Seat {
    Seat(name: name, isBot: false, playerID: id, side: side)
}

private func bot(_ name: String, side: Int = 1) -> Seat {
    Seat(name: name, isBot: true, side: side)
}

/// A game finished `day` days into the log, won by `winner`'s side. You sit on side 0.
private func game(_ seats: [Seat], scores: [Int], winner: Int, table: LoggedGame.Table = .nearby,
                  day: Int = 0, scope: Int = 0, settebelli: Int = 0, teams: Bool = false) -> LoggedGame {
    LoggedGame(id: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400),
               table: table, seats: [you] + seats, teams: teams, scores: scores, yourSide: 0, winner: winner,
               won: winner == 0, scope: scope, settebelli: settebelli)
}

private let marco = person("Marco", id: "gc:marco")

@Suite struct Logging {
    @Test func aSummaryDrawnTwiceIsOneGame() {
        var log = GameLog()
        let played = game([marco], scores: [11, 7], winner: 0)

        let first = log.add(played), second = log.add(played)

        #expect(first)
        #expect(!second)
        #expect(log.games.count == 1)
        #expect(log.totals.logged == WonLost(won: 1, lost: 0))
        #expect(log.totals.rivals["id:gc:marco"]?.record.played == 1)
    }

    @Test func theOldestFallOffButTheTotalsKeepCounting() {
        var log = GameLog()
        let games = (0..<(GameLog.kept + 5)).map { game([bot("Hugo")], scores: [11, 3], winner: $0 % 2, day: $0) }
        for played in games { log.add(played) }

        #expect(log.games.count == GameLog.kept)
        #expect(log.games.first?.id == games[5].id)
        #expect(log.totals.logged.played == GameLog.kept + 5)
        #expect(log.totals.bots["Hugo"]?.played == GameLog.kept + 5)
        #expect(log.totals.since == games[0].date)
    }

    @Test func whatCameBeforeCountsInTheShareButInNoGroup() {
        var log = GameLog(totals: RecordTotals(before: WonLost(won: 10, lost: 5), scope: 30))
        log.add(game([bot("Hugo")], scores: [11, 4], winner: 0, table: .quick, scope: 2))

        #expect(log.totals.all == WonLost(won: 11, lost: 5))
        #expect(log.totals.all.percentWon == 69)
        #expect(log.totals.groups == [.bots: WonLost(won: 1, lost: 0)])
        #expect(log.totals.allScope == 32)
        #expect(!log.isEmpty)
    }

    @Test func aNewPhoneHasNothingToShow() {
        #expect(GameLog().isEmpty)
        #expect(WonLost().percentWon == nil)
    }

    @Test func tablesFallIntoTheirGroups() {
        #expect(game([marco], scores: [11, 2], winner: 0, table: .rankedHouse).group == .ranked)
        #expect(game([bot("Hugo")], scores: [11, 2], winner: 0, table: .campaign).group == .campaign)
        #expect(game([marco], scores: [11, 2], winner: 0, table: .passThePhone).group == .people)
        #expect(game([bot("Hugo")], scores: [11, 2], winner: 0, table: .wager).group == .bots)
        #expect(game([marco, bot("Hugo", side: 2)], scores: [11, 2, 3], winner: 0, table: .wager).group == .people)
    }

    @Test func anOldLogReadsBackAndATableItDoesNotKnowIsAGame() throws {
        var log = GameLog()
        log.add(game([marco], scores: [11, 7], winner: 0, table: .room))
        let data = try JSONEncoder().encode(log)
        #expect(try JSONDecoder().decode(GameLog.self, from: data) == log)

        let text = try #require(String(data: data, encoding: .utf8)).replacingOccurrences(of: "\"room\"", with: "\"tavern\"")
        let read = try JSONDecoder().decode(GameLog.self, from: Data(text.utf8))
        #expect(read.games.first?.table == .quick)
    }
}

@Suite struct HeadToHead {
    @Test func atTwoSidesItIsTheGame() {
        var log = GameLog()
        log.add(game([marco], scores: [11, 7], winner: 0, day: 0))
        log.add(game([marco], scores: [11, 9], winner: 0, day: 1))
        let last = game([marco], scores: [6, 11], winner: 1, day: 2)
        log.add(last)

        let rival = log.standing(after: last.id)
        #expect(rival?.name == "Marco")
        #expect(rival?.record == WonLost(won: 2, lost: 1))
        #expect(rival?.lastWon == false)
        #expect(rival?.lastFaced == last.date)
        #expect(rival?.lastPlayed == last.date)
    }

    @Test func atFourTheWinnerBeatsEverybodyAndThePointsDecideTheRest() {
        let giulia = person("Giulia", side: 2, id: "gc:giulia")
        let played = game([person("Marco", side: 1, id: "gc:marco"), giulia, bot("Hugo", side: 3)],
                          scores: [8, 6, 11, 9], winner: 2)

        #expect(played.result(against: giulia) == false)
        #expect(played.result(against: played.seats[1]) == true)
        #expect(played.result(against: played.seats[3]) == false)
    }

    @Test func levelBetweenTwoWhoDidNotWinIsInNeitherColumn() {
        var log = GameLog()
        let played = game([marco, person("Giulia", side: 2, id: "gc:giulia")], scores: [7, 7, 11], winner: 2)
        log.add(played)

        #expect(log.totals.rivals["id:gc:marco"]?.record == WonLost())
        #expect(log.totals.rivals["id:gc:marco"]?.lastWon == nil)
        #expect(log.totals.rivals["id:gc:giulia"]?.record == WonLost(won: 0, lost: 1))
        #expect(log.standing(after: played.id)?.name == "Giulia")
    }

    @Test func aPartnerIsMetButNeverBeaten() {
        var log = GameLog()
        let partner = person("Marco", side: 0, id: "gc:marco")
        let played = game([person("Giulia", side: 1, id: "gc:giulia"), partner, bot("Hugo", side: 1)],
                          scores: [11, 5], winner: 0, teams: true)
        log.add(played)

        let marco = log.totals.rivals["id:gc:marco"]
        #expect(marco?.partnered == 1)
        #expect(marco?.record.played == 0)
        #expect(marco?.lastFaced == nil)
        #expect(log.standing(after: played.id)?.name == "Giulia")
        #expect(log.rivals().map(\.name).sorted() == ["Giulia", "Marco"])
    }

    @Test func thePersonPlayedMostIsTheOneOnTheSummary() {
        var log = GameLog()
        let giulia = person("Giulia", side: 1, id: "gc:giulia")
        log.add(game([marco], scores: [11, 2], winner: 0, day: 0))
        log.add(game([marco], scores: [11, 2], winner: 0, day: 1))
        let played = game([giulia, person("Marco", side: 1, id: "gc:marco")], scores: [3, 11], winner: 1,
                          day: 2, teams: true)
        log.add(played)

        #expect(log.standing(after: played.id)?.name == "Marco")
        #expect(log.standing(after: played.id)?.record == WonLost(won: 2, lost: 1))
        #expect(log.rivals().first?.name == "Marco")
    }

    @Test func aPhonePassedRoundKnowsPeopleByName() {
        var log = GameLog()
        log.add(game([person("Marco")], scores: [11, 2], winner: 0, table: .passThePhone, day: 0))
        log.add(game([person(" marco")], scores: [2, 11], winner: 1, table: .passThePhone, day: 1))

        #expect(log.totals.rivals.count == 1)
        #expect(log.totals.rivals["name:marco"]?.record == WonLost(won: 1, lost: 1))
    }

    @Test func anIdKeepsSomebodyWhoChangedTheirName() {
        var log = GameLog()
        log.add(game([marco], scores: [11, 2], winner: 0, day: 0))
        log.add(game([person("Marco P.", id: "gc:marco")], scores: [11, 2], winner: 0, day: 1))

        #expect(log.rivals().count == 1)
        #expect(log.rivals().first?.name == "Marco P.")
    }

    @Test func botsAreKeptApartAndNeverOnTheSummary() {
        var log = GameLog()
        let played = game([bot("Hugo")], scores: [4, 11], winner: 1, table: .quick)
        log.add(played)

        #expect(log.totals.bots == ["Hugo": WonLost(won: 0, lost: 1)])
        #expect(log.totals.rivals.isEmpty)
        #expect(log.standing(after: played.id) == nil)
    }
}

@Suite struct Keepsakes {
    @Test func theBestsAreTheBestEver() {
        var log = GameLog()
        log.add(game([bot("Laurence")], scores: [11, 1], winner: 0, day: 0, scope: 1))
        log.add(game([bot("Hugo")], scores: [11, 6], winner: 0, day: 1, scope: 4))
        log.add(game([bot("Hugo")], scores: [0, 11], winner: 1, day: 2, scope: 6))
        log.add(game([bot("Hugo")], scores: [11, 9], winner: 0, day: 3))

        let totals = log.totals
        #expect(totals.biggestWin?.value == 10)
        #expect(totals.biggestWin?.against == "Laurence")
        #expect(totals.biggestWin?.score == [11, 1])
        // Scope count whoever won.
        #expect(totals.mostScope?.value == 6)
        #expect(totals.longestRun?.value == 2)
        #expect(totals.run == 1)
    }

    @Test func aLossIsNeverTheBiggestWin() {
        var log = GameLog()
        log.add(game([bot("Hugo")], scores: [2, 11], winner: 1))

        #expect(log.totals.biggestWin == nil)
        #expect(log.totals.longestRun == nil)
    }
}

@Suite struct PrimieraTally {
    /// Everything to side 0, which takes the primiera with the rest.
    private func cleanSweep() -> GameEvent {
        .roundEnded(Scoring.score(captures: [Deck.standard, []], scope: [0, 0]))
    }

    private func configuration() throws -> GameConfiguration {
        try GameConfiguration(players: [Player(id: PlayerID(rawValue: "a"), name: "a"),
                                        Player(id: PlayerID(rawValue: "b"), name: "b")])
    }

    @Test func roundsWonOnThePrimieraAreCounted() throws {
        var mine = RewardTally(side: 0, configuration: try configuration(), mode: .multipeer(players: 2))
        var theirs = RewardTally(side: 1, configuration: try configuration(), mode: .multipeer(players: 2))
        for _ in 0..<2 {
            mine.observe(cleanSweep())
            theirs.observe(cleanSweep())
        }

        #expect(mine.primiere == 2)
        #expect(theirs.primiere == 0)
    }

    @Test func aTallySavedBeforeItWasCountedSaysItDoesNotKnow() throws {
        var tally = RewardTally(side: 0, configuration: try configuration(), mode: .multipeer(players: 2))
        let data = try JSONEncoder().encode(tally)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["primiere"] = nil
        tally = try JSONDecoder().decode(RewardTally.self, from: try JSONSerialization.data(withJSONObject: object))
        tally.observe(cleanSweep())

        #expect(tally.primiere == nil)
        #expect(tally.settebelli == 1)
    }
}
