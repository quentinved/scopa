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
        #expect(Volume.open(given: { _ in album }) == .notturna)
    }

    /// Two devices can disagree while they are apart. Whatever arrives, packs go to the first
    /// gap in the order, never past one.
    @Test func packsGoToTheFirstGapEvenIfALaterVolumeIsFull() {
        let album = full()
        let albums: (Volume) -> Album = { $0 == .napoli ? album : Album() }
        #expect(Volume.open(given: albums) == .riviera)
    }

    @Test func volumesAreCountedFromOneInOrder() {
        #expect(Volume.allCases.map(\.number) == [1, 2, 3, 4])
        #expect(Volume.riviera.previous == nil)
        #expect(Volume.pergamena.previous == .napoli)
        #expect(Volume.napoli < .notturna)
    }
}
