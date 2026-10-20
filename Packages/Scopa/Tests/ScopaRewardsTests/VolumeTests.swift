import Testing
import ScopaCore
@testable import ScopaRewards

@Suite struct Volumes {
    private func full() -> Album {
        var album = Album()
        _ = album.open(Pack(cards: Deck.standard))
        return album
    }

    @Test func aNewPlayerCollectsTheFirstVolumeAndNoOther() {
        let albums: (Volume) -> Album = { _ in Album() }
        #expect(Volume.open(given: albums) == .riviera)
        #expect(Volume.riviera.isOpen(given: albums))
        #expect(!Volume.napoli.isOpen(given: albums))
        #expect(!Volume.notturna.isOpen(given: albums))
        #expect(!Volume.maiolica.isOpen(given: albums))
        #expect(!Volume.mosaico.isOpen(given: albums))
        #expect(!Volume.intarsio.isOpen(given: albums))
        #expect(!Volume.tarocchi.isOpen(given: albums))
    }

    /// The last card of one volume is what opens the next, and packs follow it there.
    @Test func finishingAVolumeOpensTheNextOne() {
        let first = full()
        let albums: (Volume) -> Album = { $0 == .riviera ? first : Album() }
        #expect(Volume.open(given: albums) == .napoli)
        #expect(Volume.riviera.isOpen(given: albums))
        #expect(Volume.napoli.isOpen(given: albums))
        #expect(!Volume.pergamena.isOpen(given: albums))
    }

    /// Once every volume is full there is nowhere new for a pack to go, so it goes to the
    /// last one and is spares, which is what a finished album always did.
    @Test func withEveryVolumeFullPacksGoToTheLast() {
        let album = full()
        #expect(Volume.open(given: { _ in album }) == .tarocchi)
    }

    /// Maiolica arrived after some players had filled all four, their packs going to
    /// Notturna as spares. Their next pack starts the fifth instead.
    @Test func aFifthVolumeOpensForWhoeverFilledTheFirstFour() {
        let album = full()
        let albums: (Volume) -> Album = { $0 >= .maiolica ? Album() : album }
        #expect(Volume.open(given: albums) == .maiolica)
        #expect(Volume.maiolica.isOpen(given: albums))
        #expect(Volume.notturna.isOpen(given: albums))
        #expect(!Volume.mosaico.isOpen(given: albums))
    }

    /// Nobody reaches the fifth by skipping the fourth.
    @Test func theFifthWaitsForTheFourth() {
        let album = full()
        let albums: (Volume) -> Album = { $0 >= .notturna ? Album() : album }
        #expect(Volume.open(given: albums) == .notturna)
        #expect(!Volume.maiolica.isOpen(given: albums))
    }

    /// Mosaico came after Maiolica, so whoever had filled five starts the sixth, and
    /// nobody reaches it with the fifth unfinished.
    @Test func theSixthOpensOnlyBehindTheFifth() {
        let album = full()
        let five: (Volume) -> Album = { $0 >= .mosaico ? Album() : album }
        #expect(Volume.open(given: five) == .mosaico)
        let four: (Volume) -> Album = { $0 >= .maiolica ? Album() : album }
        #expect(!Volume.mosaico.isOpen(given: four))
    }

    /// Carnevale and Intarsio follow in order like the rest: six filled opens the seventh,
    /// and the eighth waits for it.
    @Test func theSeventhAndEighthOpenInTurn() {
        let album = full()
        let six: (Volume) -> Album = { $0 >= .carnevale ? Album() : album }
        #expect(Volume.open(given: six) == .carnevale)
        #expect(!Volume.intarsio.isOpen(given: six))
        let seven: (Volume) -> Album = { $0 == .intarsio ? Album() : album }
        #expect(Volume.open(given: seven) == .intarsio)
        #expect(Volume(rawValue: "carnevale") == .carnevale)
        #expect(Volume(rawValue: "intarsio") == .intarsio)
    }

    /// Merletto and Tarocchi the same: eight filled opens the ninth, and the tenth waits.
    @Test func theNinthAndTenthOpenInTurn() {
        let album = full()
        let eight: (Volume) -> Album = { $0 >= .merletto ? Album() : album }
        #expect(Volume.open(given: eight) == .merletto)
        #expect(!Volume.tarocchi.isOpen(given: eight))
        let nine: (Volume) -> Album = { $0 == .tarocchi ? Album() : album }
        #expect(Volume.open(given: nine) == .tarocchi)
        #expect(Volume(rawValue: "merletto") == .merletto)
        #expect(Volume(rawValue: "tarocchi") == .tarocchi)
    }

    /// The raw value names a volume's cards on the phone ("album.maiolica.cards"), in the
    /// synced profile ("maiolica/7d") and in the ledger's departures, so it never changes.
    @Test func theFifthIsStoredUnderItsOwnName() {
        #expect(Volume(rawValue: "maiolica") == .maiolica)
        #expect(Volume(rawValue: "mosaico") == .mosaico)
        let key = Departures.giftKey(Card(.seven, of: .cups), from: .maiolica, day: "2026-10-16", id: "a")
        #expect(key == "album/out/maiolica/7c/gift/2026-10-16/a")
        #expect(Departures(keys: [key]).count(of: Card(.seven, of: .cups), in: .maiolica) == 1)
        #expect(Departures(keys: [key]).count(of: Card(.seven, of: .cups), in: .notturna) == 0)
    }

    /// Two devices can disagree while they are apart. Whatever arrives, packs go to the first
    /// gap in the order, never past one.
    @Test func packsGoToTheFirstGapEvenIfALaterVolumeIsFull() {
        let album = full()
        let albums: (Volume) -> Album = { $0 == .napoli ? album : Album() }
        #expect(Volume.open(given: albums) == .riviera)
    }

    @Test func volumesAreCountedFromOneInOrder() {
        #expect(Volume.allCases.map(\.number) == Array(1...10))
        #expect(Volume.riviera.previous == nil)
        #expect(Volume.pergamena.previous == .napoli)
        #expect(Volume.maiolica.previous == .notturna)
        #expect(Volume.mosaico.previous == .maiolica)
        #expect(Volume.napoli < .notturna)
        #expect(Volume.notturna < .maiolica)
        #expect(Volume.maiolica < .mosaico)
        #expect(Volume.carnevale.previous == .mosaico)
        #expect(Volume.intarsio.previous == .carnevale)
        #expect(Volume.merletto.previous == .intarsio)
        #expect(Volume.tarocchi.previous == .merletto)
    }

    // MARK: Scarcity

    /// The first six hold their cards at the deck's own odds; after them each holds back
    /// harder than the last, numerals untouched.
    @Test func onlyTheLaterVolumesAreScarcer() {
        for volume in Volume.allCases where volume <= .mosaico {
            #expect(volume.scarcity == 1)
        }
        #expect(Volume.carnevale.scarcity > Volume.mosaico.scarcity)
        #expect(Volume.intarsio.scarcity > Volume.carnevale.scarcity)
        #expect(Volume.merletto.scarcity > Volume.intarsio.scarcity)
        #expect(Volume.tarocchi.scarcity > Volume.merletto.scarcity)
        for tier in PackTier.on(.album) {
            #expect(Pack.chance(of: .court, in: tier, volume: .tarocchi)
                    < Pack.chance(of: .court, in: tier, volume: .merletto))
            #expect(Pack.chance(of: .court, in: tier, volume: .merletto)
                    < Pack.chance(of: .court, in: tier, volume: .intarsio))
            #expect(Pack.chance(of: .court, in: tier, volume: .intarsio)
                    < Pack.chance(of: .court, in: tier, volume: .carnevale))
            #expect(Pack.chance(of: .plain, in: tier, volume: .carnevale)
                    > Pack.chance(of: .plain, in: tier, volume: .mosaico))
        }
    }

    /// The day's card goes into the open volume at that volume's odds.
    @Test func theDaysCardIsScarcerInALaterVolume() {
        for won in [false, true] {
            #expect(DailyCard.chance(ofAtLeast: .court, won: won, volume: .tarocchi)
                    < DailyCard.chance(ofAtLeast: .court, won: won, volume: .intarsio))
            #expect(DailyCard.chance(ofAtLeast: .court, won: won, volume: .intarsio)
                    < DailyCard.chance(ofAtLeast: .court, won: won, volume: .mosaico))
            #expect(DailyCard.chance(ofAtLeast: .court, won: won, volume: .mosaico)
                    == DailyCard.chance(ofAtLeast: .court, won: won))
        }
    }

    /// What the scarcity was set by: a player filling a volume from empty on earned packs,
    /// trading whenever a trade is on. Over 3,000 players each, at the trade prices of
    /// 2026-10-18 (sevens out of the trade), the median was 120 packs for Mosaico, 158 for
    /// Carnevale (1.3 times), 194 for Intarsio (1.6), 230 for Merletto (1.9) and 266 for
    /// Tarocchi (2.2), and the averages kept the same ratios. A smaller crowd here so the
    /// suite stays quick, and its average, which is the steadier figure over a crowd this size.
    @Test func laterVolumesTakeLonger() {
        // The same crowd for every volume, each player on their own seed, so the volumes are
        // told apart by their scarcity rather than by whose luck was in.
        let average = { (volume: Volume) -> Double in
            let packs = (1...120).map { player in
                var generator = SeededGenerator(seed: UInt64(player))
                return Collector.packs(toFill: volume, using: &generator)
            }
            return Double(packs.reduce(0, +)) / Double(packs.count)
        }
        let mosaico = average(.mosaico), carnevale = average(.carnevale), intarsio = average(.intarsio)
        let merletto = average(.merletto), tarocchi = average(.tarocchi)
        #expect(mosaico < carnevale && carnevale < intarsio)
        #expect(intarsio < merletto && merletto < tarocchi)
        #expect((1.2...1.45).contains(carnevale / mosaico))
        #expect((1.45...1.75).contains(intarsio / mosaico))
        #expect((1.75...2.1).contains(merletto / mosaico))
        #expect((1.95...2.35).contains(tarocchi / mosaico))
    }
}

/// One player filling one volume: an earned pack at a time, then every trade the spares
/// allow, the rarest card first, the way the album offers them.
private enum Collector {
    static func packs(toFill volume: Volume, using generator: inout SeededGenerator) -> Int {
        var album = Album()
        var packs = 0
        while !album.isComplete {
            packs += 1
            let found = album.open(Pack.draw(.mazzetto, volume: volume, using: &generator)).found
            // Only a spare can make a trade possible, so the album is only asked after one.
            guard found.contains(where: { !$0.isNew }),
                  Scambio.packsOpened(into: album) >= Scambio.packsBeforeTrading else { continue }
            while let offer = firstOffer(in: album) { album = traded(album, offer) }
        }
        return packs
    }

    /// `Scambio.offers(in:).first`, worked out only as far as the first one found.
    private static func firstOffer(in album: Album) -> Scambio.Offer? {
        Deck.standard.filter { !album.has($0) }
            .sorted { $0.rarity > $1.rarity }
            .lazy.compactMap { Scambio.offer(for: $0, in: album) }
            .first
    }

    private static func traded(_ album: Album, _ offer: Scambio.Offer) -> Album {
        var counts = album.counts
        for (card, count) in offer.spares { counts[card, default: 0] -= count }
        counts[offer.card] = 1
        return Album(counts: counts)
    }
}
