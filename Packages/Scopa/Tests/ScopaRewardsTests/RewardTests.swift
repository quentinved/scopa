import Foundation
import Testing
import ScopaCore
@testable import ScopaRewards

private func table(_ names: String...) throws -> GameConfiguration {
    try GameConfiguration(players: names.map { Player(id: PlayerID(rawValue: $0), name: $0) })
}

/// A round ending with everything on one side, which is a cappotto by definition.
private func cleanSweep(by side: Int, sides: Int = 2) -> GameEvent {
    var captures = Array(repeating: [Card](), count: sides)
    captures[side] = Deck.standard
    return .roundEnded(Scoring.score(captures: captures, scope: Array(repeating: 0, count: sides)))
}

/// A round where `side` takes the seven of coins but little else.
private func settebelloRound(to side: Int, sides: Int = 2) -> GameEvent {
    var captures = Array(repeating: [Card](), count: sides)
    captures[side] = [.settebello]
    captures[(side + 1) % sides] = Deck.standard.filter { $0 != .settebello }
    return .roundEnded(Scoring.score(captures: captures, scope: Array(repeating: 0, count: sides)))
}

@Suite struct Tallying {
    @Test func nothingIsPaidUntilTheGameEnds() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .multipeer(players: 2))
        tally.observe([.scopa(seat: 0), .scopa(seat: 0), cleanSweep(by: 0)])

        #expect(!tally.isSettled)
        #expect(tally.awards(firstOfDay: true).isEmpty)
        #expect(tally.entries(firstOfDay: true).isEmpty)
    }

    @Test func theMomentsAreCountedAlongsideTheWin() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .multipeer(players: 2))
        tally.observe([
            .scopa(seat: 0), .scopa(seat: 1), .scopa(seat: 0),
            cleanSweep(by: 0),
            .gameEnded(winnerSide: 0),
        ])

        let awards = tally.awards(firstOfDay: false)
        #expect(awards.map(\.earning) == [.wonGame, .scopa, .settebello, .cappotto])
        #expect(awards.first { $0.earning == .scopa }?.count == 2)
        // 25 won + 2 scope at 3 + settebello 5 + cappotto 15.
        #expect(awards.reduce(Denari.zero) { $0 + $1.value } == 51)
    }

    @Test func losingStillPays() throws {
        var tally = RewardTally(side: 1, configuration: try table("a", "b"), mode: .multipeer(players: 2))
        tally.observe([.gameEnded(winnerSide: 0)])

        #expect(tally.awards(firstOfDay: false) == [Award(.lostGame)])
    }

    @Test func settebelloWithoutTheRestIsNotACappotto() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .multipeer(players: 2))
        tally.observe([settebelloRound(to: 0), .gameEnded(winnerSide: 0)])

        #expect(tally.settebelli == 1)
        #expect(tally.cappotti == 0)
    }

    @Test func partnersShareASide() throws {
        let configuration = try GameConfiguration(
            players: ["a", "b", "c", "d"].map { Player(id: PlayerID(rawValue: $0), name: $0) },
            teams: true
        )
        var tally = RewardTally(side: 0, configuration: configuration, mode: .multipeer(players: 4))
        // Seats 0 and 2 are partners; seat 1 is an opponent.
        tally.observe([.scopa(seat: 0), .scopa(seat: 2), .scopa(seat: 1), .gameEnded(winnerSide: 0)])

        #expect(tally.scope == 2)
    }

    @Test func theFirstOfTheDayIsAnExtraLine() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .hotSeat(seats: 2))
        tally.observe([.gameEnded(winnerSide: 0)])

        #expect(tally.awards(firstOfDay: true).map(\.earning) == [.wonGame, .firstOfDay])
        #expect(tally.awards(firstOfDay: false).map(\.earning) == [.wonGame])
    }

    /// One round is the whole game, more points than the bot wins it, and the day rather
    /// than the game names the keys, so a second go at the same deck pays nothing.
    @Test func aDailyDealSettlesOnItsOnlyRound() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .dailyDeal(day: "2026-09-08"))
        #expect(tally.awards(firstOfDay: true).isEmpty)
        tally.observe([.scopa(seat: 0), cleanSweep(by: 0)])
        #expect(tally.isSettled)
        #expect(tally.awards(firstOfDay: true).map(\.earning) == [.dailyDeal, .dailyDealWon, .scopa, .settebello, .cappotto])

        var again = RewardTally(side: 0, configuration: try table("a", "b"), mode: .dailyDeal(day: "2026-09-08"))
        again.observe([cleanSweep(by: 0)])
        #expect(Set(again.entries(firstOfDay: false).map(\.key)).isSubset(of: Set(tally.entries(firstOfDay: false).map(\.key))))

        // The seven alone is one point against three: a loss, and still paid for playing.
        var lost = RewardTally(side: 0, configuration: try table("a", "b"), mode: .dailyDeal(day: "2026-09-08"))
        lost.observe([settebelloRound(to: 0)])
        #expect(lost.awards(firstOfDay: false).map(\.earning) == [.dailyDeal, .settebello])
    }

    @Test func entriesCarryTheModeTheyWereEarnedIn() throws {
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .hotSeat(seats: 2))
        tally.observe([.gameEnded(winnerSide: 0)])

        #expect(tally.entries(firstOfDay: false).allSatisfy { $0.mode == .hotSeat(seats: 2) })
    }
}

@Suite struct Purses {
    private let felt = ShopItem(id: "felt.verde", kind: .felt, title: "Verde", detail: "", price: 40)

    @Test func balanceAndOwnershipBothFoldFromTheEntries() {
        let purse = Purse(entries: [
            LedgerEntry(date: .now, amount: 100, reason: .granted("welcome"), key: "welcome"),
            LedgerEntry(date: .now, amount: -40, reason: .bought(felt.id), key: "buy/felt.verde"),
        ])

        #expect(purse.balance == 60)
        #expect(purse.owns(felt))
        #expect(!purse.owns(ShopItem.ID("felt.rosso")))
    }

    @Test func aDayIsOnlyCountedFromFinishedGames() throws {
        let calendar = Calendar(identifier: .gregorian)
        let monday = Date(timeIntervalSince1970: 1_757_000_000)
        let tuesday = monday.addingTimeInterval(60 * 60 * 24)

        let purse = Purse(entries: [
            LedgerEntry(date: monday, amount: 25, reason: .earned(Award(.wonGame)), key: "a"),
            // A purchase later the same day must not stand in for a game.
            LedgerEntry(date: tuesday, amount: -40, reason: .bought(felt.id), key: "b"),
        ])

        #expect(!purse.isFirstGame(of: monday, calendar: calendar))
        #expect(purse.isFirstGame(of: tuesday, calendar: calendar))
        #expect(Purse().isFirstGame(of: monday, calendar: calendar))
    }
}

@Suite struct Wallets {
    private let felt = ShopItem(id: "felt.verde", kind: .felt, title: "Verde", detail: "", price: 40)

    @Test func settlingTheSameGameTwiceCreditsNothing() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        var tally = RewardTally(side: 0, configuration: try table("a", "b"), mode: .multipeer(players: 2))
        tally.observe([.scopa(seat: 0), .gameEnded(winnerSide: 0)])

        let first = try await wallet.settle(tally)
        let again = try await wallet.settle(tally)

        let purse = try await wallet.purse()
        #expect(first.count == 3)  // won, scopa, first of the day
        #expect(again.isEmpty)
        #expect(purse.balance == 48)
    }

    @Test func twoGamesInADayPayTheBonusOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        let configuration = try table("a", "b")
        let noon = Date(timeIntervalSince1970: 1_757_000_000)

        for _ in 0..<2 {
            var tally = RewardTally(side: 0, configuration: configuration, mode: .multipeer(players: 2))
            tally.observe([.gameEnded(winnerSide: 0)])
            _ = try await wallet.settle(tally, on: noon)
        }

        // 20 + 25 + 25, with the daily bonus paid only on the first.
        let purse = try await wallet.purse()
        #expect(purse.balance == 70)
    }

    @Test func buyingSpendsOnceAndOwnsForever() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(100, note: "welcome", key: "welcome")

        let purse = try await wallet.buy(felt)
        #expect(purse.balance == 60)
        #expect(purse.owns(felt))

        await #expect(throws: PurchaseError.alreadyOwned) { try await wallet.buy(felt) }
        let unchanged = try await wallet.purse()
        #expect(unchanged.balance == 60)
    }

    @Test func whatYouCannotAffordSaysHowShortYouAre() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(15, note: "welcome", key: "welcome")

        await #expect(throws: PurchaseError.tooDear(short: 25)) { try await wallet.buy(felt) }
    }

    @Test func aGrantIsOnlyEverHandedOutOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(100, note: "welcome", key: "welcome")
        try await wallet.grant(100, note: "welcome", key: "welcome")

        let purse = try await wallet.purse()
        #expect(purse.balance == 100)
    }

    @Test func whatWasAlreadyInUseIsHandedOverFree() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        let purse = try await wallet.grandfather(felt)

        #expect(purse.owns(felt))
        #expect(purse.balance == .zero)
    }

    @Test func grandfatheringSomethingAlreadyBoughtIsNotASecondCopy() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(100, note: "welcome", key: "welcome")
        _ = try await wallet.buy(felt)

        let purse = try await wallet.grandfather(felt)
        #expect(purse.balance == 60)
        #expect(purse.entries.count == 2)
    }

    @Test func aSweptTableOpensEveryShelfAtOnce() async throws {
        let deck = ShopItem(id: "deck.antica", kind: .cardTheme, title: "Antica", detail: "", price: 350)
        let wallet = Wallet(store: MemoryLedgerStore())

        let purse = try await wallet.unlockEverything(in: Catalogue([felt, deck]), note: "balai")
        #expect(purse.owns(felt))
        #expect(purse.owns(deck))
        #expect(purse.balance == .zero)
    }

    @Test func sweepingATableThatIsAlreadySweptCostsNothingAndAddsNothing() async throws {
        let catalogue = Catalogue([felt])
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(100, note: "welcome", key: "welcome")
        _ = try await wallet.buy(felt)

        let purse = try await wallet.unlockEverything(in: catalogue, note: "balai")
        #expect(purse.balance == 60)
        #expect(purse.entries.count == 2)
    }

    @Test func aWalletPicksUpWhereTheLedgerLeftOff() async throws {
        let store = MemoryLedgerStore([
            LedgerEntry(date: .now, amount: 100, reason: .granted("welcome"), key: "welcome")
        ])
        let wallet = Wallet(store: store)

        let purse = try await wallet.purse()  // the ledger is read on first ask
        #expect(purse.balance == 100)
        _ = try await wallet.buy(felt)
        let saved = try await store.load()
        #expect(saved.count == 2)
    }
}

@Suite struct Files {
    @Test func aLedgerSurvivesBeingClosedAndOpened() async throws {
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let wallet = Wallet(store: FileLedgerStore(url: url, device: "device-1"))
        try await wallet.grant(75, note: "welcome", key: "welcome")

        let reopened = try await Wallet(store: FileLedgerStore(url: url, device: "device-1")).purse()
        #expect(reopened.balance == 75)
    }

    @Test func anAbsentFileIsAnEmptyLedgerRatherThanAnError() async throws {
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        #expect(try await FileLedgerStore(url: url, device: "device-1").load().isEmpty)
    }

    @Test func aFileFromALaterVersionIsRefusedRatherThanOverwritten() async throws {
        let url = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let future = #"{"version":99,"device":"device-1","entries":[]}"#
        try Data(future.utf8).write(to: url)

        await #expect(throws: LedgerFileError.unknownVersion(99)) {
            try await FileLedgerStore(url: url, device: "device-1").load()
        }
    }
}

@Suite struct Wagers {
    @Test func theStakeGoesDownOnceAndThePotComesBackOnce() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(300, note: "test", key: "t")
        let game = UUID()
        try await wallet.stake(.medium, gameID: game)
        try await wallet.stake(.medium, gameID: game)
        #expect(try await wallet.purse().balance == 100)

        let paid = try await wallet.payOut(.medium, gameID: game)
        #expect(paid.map(\.amount) == [500])
        #expect(try await wallet.payOut(.medium, gameID: game).isEmpty)
        #expect(try await wallet.purse().balance == 600)
    }

    @Test func aShortPurseCannotSitDown() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        try await wallet.grant(120, note: "test", key: "t")
        await #expect(throws: WagerError.short(80)) { try await wallet.stake(.medium, gameID: UUID()) }
        #expect(try await wallet.purse().balance == 120)
    }

    @Test func nothingIsPaidForAGameThatWasNeverStaked() async throws {
        let wallet = Wallet(store: MemoryLedgerStore())
        #expect(try await wallet.payOut(.large, gameID: UUID()).isEmpty)
    }

    @Test func thePotIsTwoStakesAndAHalf() {
        #expect(Stake.medium.payout == 500)
        #expect(Stake.small.payout == 125)
        #expect(Stake.large.payout == 1250)
    }

    @Test func thePotGrowsWithTheTable() {
        #expect(Stake.medium.payout(players: 4) == 1000)
        #expect(Stake.medium.payout(players: 3) == 750)
        #expect(Stake.small.payout(players: 4) == 250)
    }
}
