import Testing
@testable import ScopaRewards

@Suite struct Levels {
    @Test func aPhoneThatHasNeverPlayedIsLevelOne() {
        let level = Level.reached(with: 0)
        #expect(level.number == 1)
        #expect(level.progress == 0)
        #expect(level.cost == Level.first)
    }

    @Test func aLevelIsReachedAtItsCostAndNotABeforeIt() {
        #expect(Level.reached(with: Level.first - 1).number == 1)
        #expect(Level.reached(with: Level.first).number == 2)
        #expect(Level.reached(with: Level.first).progress == 0)
    }

    @Test func everyLevelCostsMoreThanTheOneBelowIt() {
        for number in 1..<30 {
            #expect(Level.cost(of: number + 1) > Level.cost(of: number))
        }
    }

    /// The bar and the number have to agree: what is left of a level plus what has been
    /// earned into it is the whole level, at every total.
    @Test func progressAndWhatIsLeftMakeUpTheLevel() {
        for total in stride(from: 0, through: 4_000, by: 37) {
            let level = Level.reached(with: total)
            #expect(level.progress + level.toGo == level.cost)
            #expect(level.progress < level.cost)
            #expect(0...1 ~= level.fraction)
        }
    }

    /// Climbing is one-way: more play never puts anybody lower than they were.
    @Test func moreExperienceIsNeverALowerLevel() {
        var highest = 0
        for total in stride(from: 0, through: 6_000, by: 13) {
            let number = Level.reached(with: total).number
            #expect(number >= highest)
            highest = number
        }
    }

    /// A number pulled out of the machine's own arithmetic is worth nothing as a test, so
    /// this one is counted by hand: 100 + 125 + 150 is level 4 at exactly 375.
    @Test func theThirdClimbLandsWhereTheAdditionSaysItDoes() {
        #expect(Level.reached(with: 375).number == 4)
        #expect(Level.reached(with: 374).number == 3)
        #expect(Level.reached(with: 374).toGo == 1)
    }

    @Test func aGameFinishedIsWorthSomethingWhoeverWon() {
        #expect(Earning.lostGame.experience > 0)
        #expect(Earning.wonGame.experience > Earning.lostGame.experience)
    }

    @Test func everyLevelPaysAndTheNextPaysMore() {
        for number in 2..<40 {
            #expect(Level.denari(reaching: number).isCredit)
            #expect(Level.denari(reaching: number + 1) > Level.denari(reaching: number))
        }
    }

    @Test func everyTenthLevelBringsAPackAndNoOtherDoes() {
        let milestones = (1...40).filter(Level.isMilestone)
        #expect(milestones == [10, 20, 30, 40])
    }

    @Test func theMilestonePackIsBetterThanTheOneGamesEarn() {
        #expect(Level.milestonePack.shelf == .album)
        #expect(Level.milestonePack.cards > PackTier.mazzetto.cards)
    }
}
