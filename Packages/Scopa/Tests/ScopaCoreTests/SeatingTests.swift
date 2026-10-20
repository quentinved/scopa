import Testing
@testable import ScopaCore

private func id(_ raw: String) -> PlayerID { PlayerID(rawValue: raw) }

@Suite struct WhoHosts {
    /// An invitation names its sender, and every phone deals with that name whatever it sees.
    @Test func aNamedHostIsTheHostWhateverTheIds() {
        #expect(TableHost.elect(declared: id("gc:Z"), local: id("gc:A"), others: [id("gc:Z")]) == id("gc:Z"))
        #expect(TableHost.elect(declared: id("gc:Z"), local: id("gc:Z"), others: [id("gc:A")]) == id("gc:Z"))
    }

    /// Two phones at the same table, each working it out for itself, agree.
    @Test func everyPhoneAtTheSameTableElectsTheSameHost() {
        let table = [id("gc:7"), id("gc:3"), id("gc:9")]
        let answers = table.map { me in TableHost.elect(declared: nil, local: me, others: table.filter { $0 != me }) }
        #expect(Set(answers) == [id("gc:3")])
    }

    /// A phone that has nobody else in view yet hosts itself: why a host is decided once, from
    /// a full match, and never again from whoever happens to be connected.
    @Test func aPhoneAloneElectsItself() {
        #expect(TableHost.elect(declared: nil, local: id("gc:9"), others: []) == id("gc:9"))
    }
}

@Suite struct WalkingOut {
    private func table(teams: Bool, seats: Int) throws -> GameConfiguration {
        try GameConfiguration(players: (0..<seats).map { Player(id: id("p\($0)"), name: "P\($0)") }, teams: teams)
    }

    /// A partner walking out loses the game for this side too, so the side named the winner is
    /// the other one, whichever partner is asking.
    @Test func theSideAcrossFromAPartnerIsTheOtherPair() throws {
        let four = try table(teams: true, seats: 4)
        for seat in 0..<4 {
            let winner = try #require(four.seat(across: seat))
            #expect(four.side(ofSeat: winner) != four.side(ofSeat: seat))
        }
    }

    @Test func headsUpTheOtherChairWins() throws {
        let two = try table(teams: false, seats: 2)
        #expect(two.seat(across: 0) == 1)
        #expect(two.seat(across: 1) == 0)
    }
}

@Suite struct PartnerFollowing {
    @Test func aPairingIsSatAtWhenever() {
        #expect(DuoFollow.verdict(paired: true, leaderLeftBeforeAsking: true, leaderLeftNow: true) == .sitDown)
        #expect(DuoFollow.verdict(paired: true, leaderLeftBeforeAsking: false, leaderLeftNow: false) == .sitDown)
    }

    /// The leader left while this phone's question was already on its way: the answer was
    /// asked before the pairing existed, so the partner asks again rather than giving up.
    @Test func anAnswerAlreadyOnItsWayWhenTheLeaderLeftSaysNothing() {
        #expect(DuoFollow.verdict(paired: false, leaderLeftBeforeAsking: false, leaderLeftNow: true) == .keepFollowing)
    }

    @Test func noPairingAfterTheLeaderLeftIsTheEnd() {
        #expect(DuoFollow.verdict(paired: false, leaderLeftBeforeAsking: true, leaderLeftNow: true) == .abandon)
    }

    @Test func aLeaderStillThereIsFollowed() {
        #expect(DuoFollow.verdict(paired: false, leaderLeftBeforeAsking: false, leaderLeftNow: false) == .keepFollowing)
    }
}

@Suite struct WhenSomebodyGoes {
    private func verdict(hostWent: Bool = true, hosts: Bool = false, heldDuo: Bool = false, dealt: Bool = true,
                         finished: Bool = false, watched: Bool = true) -> Departure {
        Departure.of(hostWent: hostWent, thisPhoneHosts: hosts, heldDuo: heldDuo, dealt: dealt, finished: finished,
                     watched: watched)
    }

    @Test func aHostGoneMidGameIsWaitedFor() {
        #expect(verdict() == .waitForHost)
    }

    /// The waiting room has nothing to keep: a host gone before the deal ends the table.
    @Test func aHostGoneBeforeTheDealSendsTheGuestHome() {
        #expect(verdict(dealt: false) == .leave)
        #expect(verdict(watched: false) == .leave)
    }

    @Test func aFinishedGameKeepsItsSummary() {
        #expect(verdict(finished: true) == .coverSeat)
    }

    @Test func aGuestGoneIsTheHousesChair() {
        #expect(verdict(hostWent: false) == .coverSeat)
        #expect(verdict(hostWent: false, hosts: true) == .coverSeat)
    }

    /// A duo still looking for a pair breaks whoever went; once dealt it is any other table.
    @Test func aHeldDuoBreaksOnlyBeforeTheDeal() {
        #expect(verdict(hostWent: false, heldDuo: true, dealt: false) == .pairBroke)
        #expect(verdict(heldDuo: true, dealt: true) == .waitForHost)
    }
}
