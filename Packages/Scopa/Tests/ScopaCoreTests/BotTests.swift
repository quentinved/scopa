import Testing
@testable import ScopaCore

private func c(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(rank, of: suit) }

/// A view of a two-handed table with the given hand and table, on turn unless said otherwise.
private func view(hand: [Card], table: [Card], stock: Int = 20, turnSeat: Int = 0) -> PlayerView {
    let players = [Player(id: PlayerID(rawValue: "a"), name: "A"),
                   Player(id: PlayerID(rawValue: "b"), name: "B")]
    let configuration = try! GameConfiguration(players: players)
    return PlayerView(
        seat: 0, hand: hand, table: table,
        opponents: [.init(seat: 1, player: players[1], cardsInHand: 3)],
        stockCount: stock, captureCounts: [0, 0], captures: [], capturedBySide: [[], []],
        scope: [0, 0], scores: [0, 0],
        turnSeat: turnSeat, phase: .playing, roundNumber: 1, configuration: configuration
    )
}

private func move(_ view: PlayerView, level: BotLevel = .normal, seed: UInt64 = 7) -> Move? {
    var rng = SeededGenerator(seed: seed)
    return Bot(level: level).move(for: view, using: &rng)
}

@Suite struct BotChoices {
    @Test func takesTheSweepOverTheBiggerPile() {
        let table = [c(.four), c(.three)]
        let chosen = move(view(hand: [c(.seven, .cups), c(.four, .cups)], table: table))
        #expect(chosen?.card == c(.seven, .cups))
        #expect(Set(chosen?.captures ?? []) == Set(table))
    }

    @Test func takesTheSettebelloWhenItCan() {
        let chosen = move(view(hand: [c(.seven, .cups), c(.king)],
                               table: [.settebello, c(.king, .cups), c(.two)]))
        #expect(chosen?.captures == [.settebello])
    }

    @Test func alwaysPrefersATakeToALay() {
        let chosen = move(view(hand: [c(.ace), c(.king)], table: [c(.ace, .cups)]))
        #expect(chosen?.captures.isEmpty == false)
    }

    /// The primiera pays for sevens, sixes and aces, so the court card is the one to give up.
    @Test func laysACourtCardAndKeepsTheSeven() {
        let chosen = move(view(hand: [.settebello, c(.king), c(.six, .cups)], table: [c(.two)]))
        #expect(chosen?.card == c(.king))
        #expect(chosen?.captures.isEmpty == true)
    }

    /// Both cards have to be laid, but only one of them leaves a table anybody can sweep.
    @Test func doesNotLayIntoASweep() {
        let chosen = move(view(hand: [c(.ace, .swords), c(.knight, .swords)], table: [c(.four), c(.five)]))
        #expect(chosen?.card == c(.knight, .swords))
    }

    @Test func passesWhenItIsNotItsTurn() {
        #expect(move(view(hand: [c(.ace)], table: [], turnSeat: 1)) == nil)
    }
}

@Suite struct BotGames {
    /// Plays a whole game out between bots and returns the winning side, moving only through
    /// `Rules`, so a bot that ever chose an illegal move would throw here.
    private func winner(seats: Int, seed: UInt64) -> Int? {
        var rng = SeededGenerator(seed: seed)
        let players = (0..<seats).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
        var state = GameState(configuration: try! GameConfiguration(players: players))
        let bot = Bot()

        for _ in 0..<2_000 {
            switch state.phase {
            case .awaitingDeal, .roundOver:
                (state, _) = Rules.startRound(state, using: &rng)
            case .playing:
                let seat = state.round!.turnSeat
                guard let move = bot.move(for: state.view(forSeat: seat), using: &rng) else { return nil }
                state = try! Rules.apply(move, to: state).0
            case .finished(let side):
                return side
            }
        }
        return nil
    }

    @Test func everyTableSizePlaysLegallyToTheEnd() {
        for seats in 2...4 {
            for seed in UInt64(1)...10 {
                #expect(winner(seats: seats, seed: seed) != nil, "\(seats) seats, seed \(seed)")
            }
        }
    }

    /// The deal decides a great deal, but a bot that plays the table should not lose to one
    /// that only ever takes the biggest pile in front of it.
    @Test func holdsItsOwnAgainstThePlainGreedyMove() {
        var wins = 0
        for seed in UInt64(1)...80 {
            var rng = SeededGenerator(seed: seed)
            let players = (0..<2).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
            var state = GameState(configuration: try! GameConfiguration(players: players))
            let botSeat = Int(seed % 2)

            while !state.isFinished {
                if state.phase == .playing, let seat = state.round?.turnSeat {
                    let view = state.view(forSeat: seat)
                    let move = seat == botSeat ? Bot().move(for: view, using: &rng) : Rules.automaticMove(for: view)
                    guard let move else { break }
                    state = try! Rules.apply(move, to: state).0
                } else {
                    (state, _) = Rules.startRound(state, using: &rng)
                }
            }
            if case .finished(let side) = state.phase, side == botSeat { wins += 1 }
        }
        #expect(wins >= 30, "won only \(wins) of 80")
    }
}

@Suite struct BotSeats {
    @Test func aBotSeatPlaysItselfAndNeverShowsItsHand() async throws {
        let players = [Player(id: PlayerID(rawValue: "me"), name: "Me"),
                       Player(id: PlayerID(rawValue: "bot"), name: "Bot")]
        let table = HotSeatTable(configuration: try GameConfiguration(players: players),
                                 bots: [1], pace: .zero, rng: SeededGenerator(seed: 4))
        let updates = await table.updates
        await table.deal()

        var seen = 0
        for await update in updates {
            guard case .view(let view) = update else { continue }
            #expect(view.seat == 0, "the phone showed the bot's hand")
            seen += 1
            if seen == 1 {
                let state = await table.state
                let card = state.round!.hands[0][0]
                try await table.play(card, capturing: Rules.captureOptions(for: card, on: state.round!.table).first ?? [])
            }
            if seen >= 3 { break }
        }
        // The player played one card, and the turn came back round, so the bot played too.
        let state = await table.state
        #expect(state.round!.hands[1].count < GameConfiguration.handSize)
        await table.stop()
    }

    @Test func aTableOfPeopleStillFollowsTheTurnRound() async throws {
        let players = (0..<3).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
        let table = HotSeatTable(configuration: try GameConfiguration(players: players), pace: .zero)
        let updates = await table.updates
        await table.deal()

        var seats: [Int] = []
        for await update in updates {
            guard case .view(let view) = update else { continue }
            seats.append(view.seat)
            if seats.count == 2 { break }
            let state = await table.state
            let card = state.round!.hands[view.seat][0]
            try await table.play(card, capturing: Rules.captureOptions(for: card, on: state.round!.table).first ?? [])
        }
        // The deal starts on the seat after the dealer, and moves on from there.
        #expect(seats == [1, 2])
        await table.stop()
    }
}

/// One game between two strengths. `first` sits in the seat named by the seed, so neither
/// side always deals and neither always leads.
private func winner(_ first: BotStrength, _ second: BotStrength, seed: UInt64) -> Int? {
    var rng = SeededGenerator(seed: seed)
    let players = (0..<2).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
    var state = GameState(configuration: try! GameConfiguration(players: players))
    let firstSeat = Int(seed % 2)
    let bots = [Bot(strength: firstSeat == 0 ? first : second), Bot(strength: firstSeat == 0 ? second : first)]

    while !state.isFinished {
        if state.phase == .playing, let seat = state.round?.turnSeat {
            guard let move = bots[seat].move(for: state.view(forSeat: seat), using: &rng) else { return nil }
            // Through the rules, so a strength that ever offered an illegal move throws here.
            state = try! Rules.apply(move, to: state).0
        } else {
            (state, _) = Rules.startRound(state, using: &rng)
        }
    }
    guard case .finished(let side) = state.phase else { return nil }
    return side == firstSeat ? 0 : 1
}

private func duel(_ first: BotStrength, _ second: BotStrength, games: Int) -> Int {
    (1...UInt64(games)).count { winner(first, second, seed: $0) == 0 }
}

private func duel(_ first: BotLevel, _ second: BotLevel, games: Int) -> Int {
    duel(first.strength, second.strength, games: games)
}

/// One round on a deck given to it, seat 0 played by `zero` and seat 1 by `one`. The
/// target is out of reach on purpose: what is being measured is the round, not the game.
private func round(deck: [Card], zero: BotStrength, one: BotStrength, seed: UInt64) -> [Int] {
    var rng = SeededGenerator(seed: seed)
    let players = (0..<2).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
    var state = GameState(configuration: try! GameConfiguration(players: players, targetScore: 999))
    (state, _) = Rules.deal(deck, into: state)
    let bots = [Bot(strength: zero), Bot(strength: one)]
    while state.phase == .playing {
        let seat = state.round!.turnSeat
        guard let move = bots[seat].move(for: state.view(forSeat: seat), using: &rng) else { break }
        state = try! Rules.apply(move, to: state).0
    }
    return state.scores
}

/// Every deal played twice, once from each side, and both bots' points added up.
///
/// Counting won games is close to useless as a measure here: Scopa is dealt more than it
/// is played, and a fistful of games says more about the shuffles than about either bot.
/// Playing the same deck from both sides takes the deal out of it, since whatever luck one
/// bot had the other had too, so a handful of hands is enough to show a real edge.
private func duplicate(_ a: BotStrength, _ b: BotStrength, deals: Int) -> (a: Int, b: Int) {
    var aTotal = 0, bTotal = 0
    for seed in UInt64(1)...UInt64(deals) {
        var shuffle = SeededGenerator(seed: seed &* 7919)
        let deck = Rules.shuffledDeck(using: &shuffle)
        let first = round(deck: deck, zero: a, one: b, seed: seed)
        aTotal += first[0]
        bTotal += first[1]
        let second = round(deck: deck, zero: b, one: a, seed: seed &+ 1000)
        bTotal += second[0]
        aTotal += second[1]
    }
    return (aTotal, bTotal)
}

private func duplicate(_ a: BotLevel, _ b: BotLevel, deals: Int) -> (a: Int, b: Int) {
    duplicate(a.strength, b.strength, deals: deals)
}

/// The three levels, and what actually separates them.
///
/// Everything in here plays whole games rather than positions, because a card game is
/// decided over a round and not over a move: a bot that scores every position beautifully
/// and cannot see the end of a hand loses to one that can.
@Suite struct BotLevels {
    /// The whole point of the level, measured the only way that means anything over a few
    /// hands: the same cards, played by both. Four deals rather than forty because the
    /// search is by a distance the slowest thing in this package.
    @Test func hardOutplaysNormalOnTheSameCards() {
        let points = duplicate(.hard, .normal, deals: 4)
        #expect(points.a >= points.b + 5, "hard \(points.a) – \(points.b) normal over eight rounds")
    }

    @Test func normalOutplaysEasy() {
        let wins = duel(.normal, .easy, games: 40)
        #expect(wins >= 24, "the normal bot won only \(wins) of 40")
    }

    /// The tactics the weighing already got right have to survive the search replacing it.
    @Test func theHardBotStillTakesTheObviousThings() {
        let table = [c(.four), c(.three)]
        let sweep = move(view(hand: [c(.seven, .cups), c(.four, .cups)], table: table), level: .hard)
        #expect(Set(sweep?.captures ?? []) == Set(table))

        let seven = move(view(hand: [c(.seven, .cups), c(.king)],
                              table: [.settebello, c(.king, .cups), c(.two)]), level: .hard)
        #expect(seven?.captures == [.settebello])
    }

    /// A view with no piles on it, sent by a build that did not carry them, cannot be
    /// counted, so the search declines it and the weighing answers instead. Silently: a bot
    /// that stopped playing because it could not think as hard as it wanted would be worse
    /// than one that thought less.
    @Test func theSearchDeclinesAViewItCannotCount() {
        var rng = SeededGenerator(seed: 1)
        let uncountable = view(hand: [c(.ace), c(.king)], table: [c(.ace, .cups)])
        #expect(Search.worlds(for: uncountable, using: &rng).isEmpty)
        #expect(Bot(level: .hard).move(for: uncountable, using: &rng) != nil)
    }

    /// Every world is a game this seat could actually be sitting in: its own hand, the table
    /// in front of it and the piles as they are, with the forty cards accounted for exactly
    /// once. Anything else would be the bot thinking about a table nobody is at.
    @Test func everyWorldIsOneThisSeatCouldBeSittingIn() {
        var rng = SeededGenerator(seed: 9)
        let players = (0..<2).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
        var state = GameState(configuration: try! GameConfiguration(players: players))
        (state, _) = Rules.startRound(state, using: &rng)
        // A few moves in, so there are piles to account for as well as hands.
        for _ in 0..<5 {
            let seat = state.round!.turnSeat
            let move = Bot().move(for: state.view(forSeat: seat), using: &rng)!
            state = try! Rules.apply(move, to: state).0
        }

        let seat = state.round!.turnSeat
        let view = state.view(forSeat: seat)
        let worlds = Search.worlds(for: view, using: &rng)
        #expect(!worlds.isEmpty)
        for world in worlds {
            let round = world.round!
            #expect(round.hands[seat] == view.hand)
            #expect(round.table == view.table)
            #expect(round.captures == view.capturedBySide)
            let everything = round.hands.flatMap { $0 } + round.table + round.captures.flatMap { $0 } + round.stock
            #expect(Set(everything).count == Deck.standard.count)
        }
    }

    /// The last hand of a round for two: the stock is empty and the only cards it cannot see
    /// are in one other hand, so that hand *is* the unseen cards and there is nothing left to
    /// guess. One world, and the search plays every card of what remains.
    @Test func theLastHandOfARoundForTwoIsSolvedRatherThanGuessed() {
        var rng = SeededGenerator(seed: 4)
        let players = (0..<2).map { Player(id: PlayerID(rawValue: "s\($0)"), name: "\($0)") }
        var state = GameState(configuration: try! GameConfiguration(players: players))
        (state, _) = Rules.startRound(state, using: &rng)
        while state.phase == .playing, state.round!.stock.count > 0 {
            let seat = state.round!.turnSeat
            let move = Bot().move(for: state.view(forSeat: seat), using: &rng)!
            state = try! Rules.apply(move, to: state).0
        }
        guard state.phase == .playing else { return }

        let view = state.view(forSeat: state.round!.turnSeat)
        #expect(Search.worldCount(for: view) == 1)
        let worlds = Search.worlds(for: view, using: &rng)
        #expect(worlds.count == 1)
        // The one world is the game as it actually stands, hidden hand and all.
        #expect(worlds[0].round?.hands.map(Set.init) == state.round?.hands.map(Set.init))
        // And it is played to the last card rather than cut short.
        #expect(Search.effort(for: view, worlds: 1).depth >= view.stockCount + view.cardsInPlay)
    }
}


/// The house at a ranked table, which is not one of the three levels but a ramp between
/// them: a little harder every division, so nobody is ever told their opponent changed.
@Suite struct HouseLadder {
    private var steps: [Int] { Array(0...BotStrength.topStep) }

    /// The whole promise in one line: it never gets easier as you climb. The two dials are
    /// read in the order they matter, so a bot that counts the deck outranks one that does
    /// not, whatever either does with the answer.
    @Test func itNeverGetsEasierAsYouClimb() {
        for step in steps.dropLast() {
            let here = BotStrength.house(atStep: step), next = BotStrength.house(atStep: step + 1)
            #expect(here.searches == next.searches ? next.follows >= here.follows : next.searches,
                    "step \(step) → \(step + 1) went backwards")
        }
    }

    /// And never in a jump anybody could point at. A division is a hundred points and a week
    /// or two of evenings; what it may buy is a few points of how often the house takes its
    /// own best advice, which is under the noise of one game and over the noise of a season.
    @Test func noOneDivisionIsAStepChange() {
        for step in steps.dropLast() {
            let here = BotStrength.house(atStep: step), next = BotStrength.house(atStep: step + 1)
            guard here.searches == next.searches else { continue }
            #expect(next.follows - here.follows <= 0.05,
                    "step \(step) → \(step + 1) jumped \(next.follows - here.follows)")
        }
    }

    /// The bottom of the ladder is gentler than anything the settings offer, because it is
    /// the first ranked game somebody ever plays and a wall is a poor welcome.
    @Test func bronzeIsGentlerThanTheEasyBot() {
        let bronze = BotStrength.house(in: .bronze)
        #expect(!bronze.searches)
        #expect(bronze.follows < BotLevel.easy.strength.follows)
    }

    /// The top of it is not perfect and is not meant to be. The house seat exists because
    /// nobody real turned up; an opponent that never misses is a wall with a rosette over it.
    @Test func theTopOfTheLadderStillMissesThings() {
        let maestro = BotStrength.house(atStep: BotStrength.topStep)
        #expect(maestro.searches)
        #expect(!maestro.isExact)
        #expect(maestro.follows < BotLevel.hard.strength.follows)
    }

    /// Unranked and the bottom of Bronze are the same opponent: a phone that has never
    /// played a ranked game is not owed the hardest bot in the app.
    @Test func theRampIsClampedAtBothEnds() {
        #expect(BotStrength.house(atStep: -3) == BotStrength.house(atStep: 0))
        #expect(BotStrength.house(atStep: 99) == BotStrength.house(atStep: BotStrength.topStep))
    }

    /// The measured version of the first test, on cards rather than on dials: the same deals
    /// played by both ends of the ladder, and the top has to actually win them.
    ///
    /// Twelve deals rather than four. A round of Scopa pays four or five points however well
    /// it was played, so a handful of them is mostly the shuffle even played from both
    /// sides, and the whole ramp is only worth about a point a round. Twelve is where that
    /// stops being noise, and the search is by a distance the slowest thing in this package.
    @Test func theTopOfTheLadderOutplaysTheBottomOnTheSameCards() {
        let points = duplicate(BotStrength.house(atStep: BotStrength.topStep),
                               BotStrength.house(atStep: 0), deals: 12)
        #expect(points.a >= points.b + 10, "Maestro \(points.a) – \(points.b) Bronze over 24 rounds")
    }

    /// The changeover is the one place a ramp can dip, and it did: handed the search early,
    /// while the house still slipped one move in five, it played worse than the plain
    /// weighing it replaced: a search that finds the right line and then plays a different
    /// card is work thrown away. Measured against a fixed opponent over sixteen duplicated
    /// deals, the two come out level around nine follows in ten, so that is where it is
    /// handed over. This is that finding, kept where breaking it is noticed.
    @Test func theSearchIsHandedOverOnlyOnceItPaysForItself() {
        let handover = BotStrength.house(atStep: BotStrength.houseSearchesFrom)
        #expect(handover.searches)
        #expect(handover.follows >= 0.88, "the search arrived at \(handover.follows) follows")
        #expect(!BotStrength.house(atStep: BotStrength.houseSearchesFrom - 1).searches)
    }
}
