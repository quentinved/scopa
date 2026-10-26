import Testing
@testable import ScopaCore

/// Past Maestro I the ladder stops counting divisions and starts counting points, the way a
/// ladder's last tier is a number and a place rather than one more rung. The Worker mirrors
/// all of this in ranking.ts.
@Suite struct GranMaestro {
    @Test func maestroOneIsStillTheLastDivision() {
        let maestroOne = Ranking.standing(for: Ranking.grandFloor - 1)
        #expect(maestroOne.title == "Maestro I")
        #expect(maestroOne.progress == 99)
        #expect(maestroOne.points == nil)
    }

    @Test func pastItThePointsHaveNoTop() {
        for points in [0, 1, 99, 100, 340, 12_000] {
            let standing = Ranking.standing(for: Ranking.grandFloor + points)
            #expect(standing.league == .granMaestro)
            #expect(standing.title == "Gran Maestro")
            #expect(standing.points == points)
            #expect(standing.step == Ranking.grandStep)
        }
    }

    /// One step past Maestro I, so a person there is "a division above" a Maestro I at the
    /// table and the people's points read as they always have.
    @Test func granMaestroIsOneStepAboveMaestroOne() {
        let maestroOne = Ranking.standing(for: Ranking.grandFloor - 1)
        #expect(Ranking.grandStep == maestroOne.step + 1)
        #expect(Ranking.change(for: Ranking.grandFloor - 1, others: [Ranking.grandFloor + 400], won: true, winner: nil) == 30)
        #expect(Ranking.change(for: Ranking.grandFloor + 400, others: [Ranking.grandFloor + 10], won: true, winner: nil) == 20)
    }

    /// Reached once, it is the floor for the season, at nought points.
    @Test func itIsAFloorOnceReached() {
        let (rating, floor) = Ranking.apply(25, to: Ranking.grandFloor - 10, floor: Ranking.floor(of: .maestro))
        #expect(rating == Ranking.grandFloor + 15)
        #expect(floor == Ranking.grandFloor)
        #expect(Ranking.apply(-50, to: rating, floor: floor).rating == Ranking.grandFloor)
        #expect(Ranking.floor(of: .granMaestro) == Ranking.grandFloor)
    }

    /// The house pays less and costs more up here, so the points measure how often it is beaten.
    @Test func theHouseIsAMeasureNotAClimb() {
        #expect(Ranking.houseStakes(for: Ranking.grandFloor - 1) == (Ranking.houseWin, Ranking.houseLoss))
        #expect(Ranking.houseStakes(for: Ranking.grandFloor) == (Ranking.grandHouseWin, Ranking.grandHouseLoss))
        #expect(Ranking.houseChange(won: true, streak: 3, rating: Ranking.grandFloor) == Ranking.grandHouseWin + 6)
        #expect(Ranking.houseChange(won: false, rating: Ranking.grandFloor + 80) == Ranking.grandHouseLoss)
        // Better than even against it still climbs: three wins in five, before any run.
        #expect(3 * Ranking.grandHouseWin + 2 * Ranking.grandHouseLoss > 0)
    }

    @Test func theHouseSitsAtGranMaestroAtMost() {
        #expect(Ranking.houseStep(among: [Ranking.grandStep + 5]) == Ranking.grandStep)
        let chair = Ranking.standing(for: Ranking.houseRating(atStep: Ranking.grandStep, jitter: 37))
        #expect(chair.league == .granMaestro)
        #expect(chair.points == 37)
    }

    @Test func campioniAreTheTopTenWithThreeHundredPoints() {
        #expect(Ranking.isCampione(place: 1, points: 300))
        #expect(Ranking.isCampione(place: 10, points: 1_200))
        #expect(!Ranking.isCampione(place: 11, points: 1_200))
        #expect(!Ranking.isCampione(place: 1, points: 299))
        #expect(!Ranking.isCampione(place: nil, points: 900))
    }
}
