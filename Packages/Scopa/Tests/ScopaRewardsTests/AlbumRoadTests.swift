import Testing
@testable import ScopaRewards

@Suite struct TheAlbumRoad {
    @Test func aStopEveryTenCardsToTheEndOfTheLastVolume() {
        #expect(AlbumRoad.stops.first == 10)
        #expect(AlbumRoad.stops.last == AlbumRoad.length)
        #expect(AlbumRoad.stops.count == AlbumRoad.length / 10)
        #expect(AlbumRoad.length == Volume.allCases.count * Album.size)
    }

    @Test func eachVolumeWalksThreeCoinsAndAPack() {
        #expect(AlbumRoad.prize(at: 10) == .denari(25))
        #expect(AlbumRoad.prize(at: 20) == .denari(50))
        #expect(AlbumRoad.prize(at: 30) == .denari(100))
        #expect(AlbumRoad.prize(at: 40) == .pack(.bottega))
        #expect(AlbumRoad.prize(at: 70) == .denari(100))
        #expect(AlbumRoad.prize(at: 80) == .pack(.bottega))
    }

    /// Nothing is left to open a pack into once every volume is full.
    @Test func theEndOfTheRoadPaysThePackInDenari() {
        let price = PackTier.bottega.price
        #expect(AlbumRoad.prize(at: AlbumRoad.length) == .denari(price ?? 0))
    }

    /// The fourth volume's last card used to be the end of the road. With six more volumes
    /// behind it, it and every later volume's last card are each a Bottega to start the
    /// next like any other's, and the end moves on to the tenth.
    @Test func theRoadRunsOnThroughTheLaterVolumes() {
        #expect(AlbumRoad.length == 400)
        for stop in [160, 200, 240, 280, 320, 360] {
            #expect(AlbumRoad.prize(at: stop) == .pack(.bottega))
        }
        #expect(AlbumRoad.prize(at: 400) == .denari(PackTier.bottega.price ?? 0))
        #expect(AlbumRoad.next(after: 360) == 370)
    }

    /// Somebody paid the old end of the road is not paid for it again, or for anything
    /// behind it, when the road gets longer.
    @Test func theOldEndOfTheRoadStaysPaid() {
        let paid = Set(AlbumRoad.stops.filter { $0 <= 160 })
        let owed = AlbumRoad.owed(found: 165, paid: paid)
        #expect(owed.stop == nil)
        #expect(owed.waived.isEmpty)
    }

    @Test func theRoadIsSmallBesideWhatAVolumeTakes() {
        let volume = AlbumRoad.stops.prefix(4).reduce(0) { total, stop in
            switch AlbumRoad.prize(at: stop) {
            case .denari(let amount): total + amount.coins
            case .pack(let tier): total + (tier.price?.coins ?? 0)
            }
        }
        // About 475 since packs doubled, against the thousands a volume's packs cost.
        #expect(volume <= 500)
    }

    @Test func keysNameTheirStop() {
        #expect(AlbumRoad.key(for: 30) == "album/milestone/30")
        #expect(AlbumRoad.stop(forKey: "album/milestone/30") == 30)
        #expect(AlbumRoad.stop(forKey: "level/30") == nil)
    }

    @Test func oneStopReachedIsPaid() {
        let owed = AlbumRoad.owed(found: 21, paid: [10])
        #expect(owed.stop == 20)
        #expect(!owed.isCatchUp)
        #expect(AlbumRoad.owed(found: 29, paid: [10, 20]).stop == nil)
    }

    /// An album older than the road pays the furthest stop it has passed, not all of them.
    @Test func anOldAlbumIsPaidItsFurthestStopOnly() {
        let owed = AlbumRoad.owed(found: 95, paid: [])
        #expect(owed.stop == 90)
        #expect(owed.waived == [10, 20, 30, 40, 50, 60, 70, 80])
        #expect(owed.isCatchUp)
        #expect(AlbumRoad.owed(found: 95, paid: Set(AlbumRoad.stops.prefix(9))).stop == nil)
    }

    @Test func theNextStopIsAhead() {
        #expect(AlbumRoad.next(after: 0) == 10)
        #expect(AlbumRoad.next(after: 10) == 20)
        #expect(AlbumRoad.next(after: AlbumRoad.length) == nil)
    }
}
