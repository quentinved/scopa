import Testing
import ScopaCore
@testable import ScopaRewards

/// What a pack of each tier is made of, and what it promises.
///
/// The promises are the point. A tier that says "a court or better among them" is a
/// sentence printed in the shop next to a price, and these are the tests that make it true
/// rather than aspirational.
@Suite struct Packs {
    @Test func everyBoughtTierHasAPriceAndTheEarnedOneDoesNot() {
        #expect(PackTier.mazzetto.price == nil)
        for shelf in PackTier.Shelf.allCases {
            for tier in PackTier.forSale(on: shelf) {
                #expect(tier.price != nil)
            }
            // Dearest last, which is the order the shelf shows them in.
            let prices = PackTier.forSale(on: shelf).compactMap { $0.price?.coins }
            #expect(prices == prices.sorted())
        }
        // Every tier is on exactly one shelf, and no shelf is empty.
        #expect(PackTier.Shelf.allCases.flatMap(PackTier.on).count == PackTier.allCases.count)
        for shelf in PackTier.Shelf.allCases {
            #expect(!PackTier.forSale(on: shelf).isEmpty)
        }
    }

    /// Each tier up is at least as good as the one below it on every axis at once, so
    /// nothing on a shelf is ever a worse deal than the thing beneath it.
    ///
    /// Within a shelf, never across the two: a `forziere` holds no cards at all and is not
    /// thereby worse than a `reliquia`. They are different things to want, and the only
    /// ladder a player ever reads is the one page they are standing on.
    @Test func eachTierBeatsTheOneBelowItOnEveryAxis() {
        for shelf in PackTier.Shelf.allCases {
            let ladder = PackTier.on(shelf)
            for (lower, higher) in zip(ladder, ladder.dropFirst()) {
                #expect(higher.cards >= lower.cards)
                #expect(higher.cosmetics >= lower.cosmetics)
                #expect(higher.luck >= lower.luck)
                #expect(higher.floorGrade >= lower.floorGrade)
            }
        }
    }

    // MARK: The shop's shelf

    /// A pack bought in the shop is made of what the shop sells and nothing else. If one
    /// ever started handing over cards it would be competing with the album's own shelf,
    /// which is the one thing the two shelves exist to avoid.
    @Test func aShopPackIsAllShelvesAndNoCards() {
        var generator = SeededGenerator(seed: 20_260_928)
        let shop = PackTier.on(.shop)
        #expect(!shop.isEmpty)
        for tier in shop {
            #expect(tier.isCosmeticOnly)
            #expect(tier.cards == 0)
            #expect(tier.floorCard == nil)
            #expect(tier.cosmetics >= 2)
            // Nothing common: the cheapest of them still promises better than the shelves' floor.
            #expect(tier.floorGrade >= .raro)
            for _ in 0..<50 {
                let pack = Pack.draw(tier, using: &generator)
                #expect(pack.cards.isEmpty)
                #expect(pack.cosmetics.count == tier.cosmetics)
            }
        }
        // And the album's own shelf is all cards, so `isCosmeticOnly` really does split them.
        for tier in PackTier.on(.album) {
            #expect(!tier.isCosmeticOnly)
        }
    }

    /// The shop's packs are priced off what they promise, so opening one and getting
    /// exactly the floor is breaking even rather than being taken. What is paid for is the
    /// chance of better; what is given up is the choosing.
    @Test func aShopPackCostsAboutWhatItPromises() {
        for tier in PackTier.on(.shop) {
            guard let price = tier.price else { continue }
            let floor = Grade.denari(for: tier.floorGrade) * tier.cosmetics
            #expect(price <= floor)
            // And not a giveaway: never less than three-quarters of it.
            #expect(price.coins * 4 >= floor.coins * 3)
        }
    }

    @Test func aTierHandsOverExactlyAsManyCardsAsItSays() {
        var generator = SeededGenerator(seed: 20_260_922)
        for tier in PackTier.allCases {
            for _ in 0..<50 {
                let pack = Pack.draw(tier, using: &generator)
                #expect(pack.cards.count == tier.cards)
                #expect(pack.cosmetics.count == tier.cosmetics)
                #expect(pack.tier == tier)
            }
        }
    }

    /// The guarantee, which is the sentence the shop prints.
    @Test func aTierWithAFloorAlwaysKeepsIt() {
        var generator = SeededGenerator(seed: 20_260_923)
        for tier in PackTier.allCases {
            guard let floor = tier.floorCard else { continue }
            for _ in 0..<300 {
                let pack = Pack.draw(tier, using: &generator)
                #expect(pack.cards.contains { $0.rarity >= floor })
            }
        }
    }

    /// The earned pack makes no promise at all, and must not quietly start keeping one:
    /// a mazzetto that always held a court would make the shelf pointless.
    @Test func theEarnedPackPromisesNothing() {
        #expect(PackTier.mazzetto.floorCard == nil)
        var generator = SeededGenerator(seed: 20_260_924)
        let plainOnly = (0..<400)
            .map { _ in Pack.draw(.mazzetto, using: &generator) }
            .contains { pack in pack.cards.allSatisfy { $0.rarity == .plain } }
        #expect(plainOnly)
    }

    /// Luck bends the odds and the printed figures follow it, so the shop is never quoting
    /// numbers the draw does not use.
    @Test func aDearerPackReallyDoesTurnUpBetterCards() {
        var generator = SeededGenerator(seed: 20_260_925)
        func sevens(_ tier: PackTier, packs: Int = 1_500) -> Int {
            (0..<packs).reduce(0) { total, _ in
                total + Pack.draw(tier, using: &generator).cards.count { $0.rarity >= .prime }
            }
        }
        #expect(sevens(.reliquia) > sevens(.mazzetto))
        // Up the album's own ladder. The shop's packs hold no cards and bend nothing, so
        // they are not part of this comparison.
        let ladder = PackTier.on(.album)
        for (lower, higher) in zip(ladder, ladder.dropFirst()) {
            #expect(Pack.chance(of: .settebello, in: higher) >= Pack.chance(of: .settebello, in: lower))
        }
    }

    @Test func thePrintedOddsAreProbabilities() {
        for tier in PackTier.allCases {
            let total = Rarity.allCases.reduce(0.0) { $0 + Pack.chance(of: $1, in: tier) }
            #expect(abs(total - 1) < 0.000_001)
            for rarity in Rarity.allCases {
                let chance = Pack.packChance(ofAtLeast: rarity, in: tier)
                #expect(chance >= 0 && chance <= 1)
            }
            // Anything the tier guarantees reads as certain.
            if let floor = tier.floorCard {
                #expect(Pack.packChance(ofAtLeast: floor, in: tier) == 1)
            }
        }
    }

    /// A settebello is meant to be the thing somebody is still short of a season in. Held
    /// to a band rather than a number so the weights can be tuned without rewriting this,
    /// but not so loosely that it could silently become common or unreachable.
    @Test func theSettebelloStaysScarceInTheEarnedPack() {
        let chance = Pack.packChance(ofAtLeast: .settebello, in: .mazzetto)
        #expect(chance > 0.005)
        #expect(chance < 0.03)
        // And the dearest pack is a real answer to that scarcity, not a rounding error.
        #expect(Pack.packChance(ofAtLeast: .settebello, in: .reliquia) > chance * 3)
        // Even the dearest pack is a chase rather than a purchase. A tier that handed the
        // seven of coins over every few packs would finish the album's one open question.
        for tier in PackTier.on(.album) {
            #expect(Pack.packChance(ofAtLeast: .settebello, in: tier) < 0.12)
        }
    }

    /// Keeping a promise is not how the settebello is found.
    ///
    /// The guaranteed card is drawn from the cards that clear the promise, and for a tier
    /// that promises a seven there are four of those — three sevens and the seven of
    /// coins. Uncapped, that made the promise the likeliest way to get it: a `velluto`
    /// paid it out about one pack in five while the shop printed one in twenty-two.
    @Test func aGuaranteeNeverPaysInTheSettebello() {
        var generator = SeededGenerator(seed: 20_260_929)
        #expect(Rarity.guaranteed < .settebello)
        for tier in PackTier.allCases {
            guard let floor = tier.floorCard else { continue }
            // The promise is still kept: capping the draw trims the top of the deck it
            // draws from and never empties it.
            #expect(floor <= Rarity.guaranteed)
            for _ in 0..<600 {
                let card = Pack.drawOne(atLeast: floor, atMost: Rarity.guaranteed,
                                        luck: tier.luck, using: &generator)
                #expect(card.rarity >= floor)
                #expect(card.rarity != .settebello)
            }
        }
        // And a cap under the floor cannot leave a promise with nothing to keep it with.
        for _ in 0..<200 {
            let card = Pack.drawOne(atLeast: .settebello, atMost: .plain, using: &generator)
            #expect(card.rarity == .settebello)
        }
    }

    /// The odds the shop prints are the odds a player actually gets.
    ///
    /// The printed figure is the draw's own arithmetic and does not know about the swap
    /// that keeps a promise, so this is the test that stops the two drifting apart — which
    /// is exactly what the uncapped guarantee did, and quietly.
    @Test func thePrintedSettebelloOddsAreTheOnesYouLiveWith() {
        var generator = SeededGenerator(seed: 20_260_930)
        let packs = 6_000
        for tier in PackTier.on(.album) {
            let hits = (0..<packs).count { _ in
                Pack.draw(tier, using: &generator).cards.contains { $0.rarity == .settebello }
            }
            let measured = Double(hits) / Double(packs)
            let printed = Pack.packChance(ofAtLeast: .settebello, in: tier)
            #expect(abs(measured - printed) < 0.02)
        }
    }

    // MARK: Grades

    @Test func aCosmeticSlotNeverFallsBelowTheTiersFloor() {
        var generator = SeededGenerator(seed: 20_260_926)
        for tier in PackTier.allCases where tier.cosmetics > 0 {
            for _ in 0..<400 {
                for grade in Pack.draw(tier, using: &generator).cosmetics {
                    #expect(grade >= tier.floorGrade)
                }
            }
        }
    }

    /// A floor raises the odds of everything above it rather than pinning the slot to the
    /// floor itself: the reason to open a reliquia twice is that it can still pay in gold.
    @Test func aFlooredSlotCanStillPayAboveTheFloor() {
        var generator = SeededGenerator(seed: 20_260_927)
        let grades = (0..<600).map { _ in Grade.draw(atLeast: .prezioso, using: &generator) }
        #expect(grades.contains(.leggendario))
        #expect(grades.contains(.prezioso))
        #expect(!grades.contains(.comune))
        #expect(Grade.chance(of: .leggendario, atLeast: .prezioso)
                > Grade.chance(of: .leggendario, atLeast: .comune))
    }

    @Test func thePrintedGradeOddsAreProbabilities() {
        for floor in Grade.allCases {
            let total = Grade.allCases.reduce(0.0) { $0 + Grade.chance(of: $1, atLeast: floor) }
            #expect(abs(total - 1) < 0.000_001)
            #expect(Grade.chance(of: .comune, atLeast: .raro) == 0)
        }
    }

    @Test func theRarerTheGradeTheLessOftenItTurnsUp() {
        for (lower, higher) in zip(Grade.allCases, Grade.allCases.dropFirst()) {
            #expect(higher.weight < lower.weight)
        }
        // A grade can always stand in for itself, and falls through the ones below it.
        #expect(Grade.leggendario.orBelow == [.leggendario, .prezioso, .raro, .comune])
        #expect(Grade.comune.orBelow == [.comune])
    }
}
