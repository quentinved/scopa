import Foundation
import Testing
import ScopaCore
@testable import ScopaRelay

@Suite struct RejoinTickets {
    private let seat = RejoinTicket(code: "K7QX", player: Player(id: PlayerID(rawValue: "gc:A1"), name: "Bea"),
                                    hostName: "Marco", ranked: true, format: "headsUp",
                                    seatedAt: Date(timeIntervalSince1970: 1_000_000))

    @Test func aSeatIsOfferedForAGamesLengthAndNoLonger() {
        let sat = seat.seatedAt
        #expect(seat.isFresh(at: sat.addingTimeInterval(40 * 60)))
        #expect(!seat.isFresh(at: sat.addingTimeInterval(RejoinTicket.shelfLife + 1)))
    }

    @Test func aClockGoneBackwardsIsNotASeatFromTheFuture() {
        #expect(!seat.isFresh(at: seat.seatedAt.addingTimeInterval(-3600)))
    }

    /// The id is the seat: a ticket read back has to ask for exactly the chair it left.
    @Test func theSeatSurvivesBeingWrittenDown() throws {
        let back = try JSONDecoder().decode(RejoinTicket.self, from: JSONEncoder().encode(seat))
        #expect(back == seat)
        #expect(back.player.id.rawValue == "gc:A1")
    }
}

@Suite struct ComingBackToARoom {
    /// A host back from a drop learns which guests went meanwhile, or it waits for good on a
    /// turn nobody is playing.
    @Test func aGuestWhoWentWhileTheHostWasAwayIsReported() {
        let gone = RelaySession.leftMeanwhile(known: ["bea", "cleo"], present: ["cleo"], host: "marco", me: "marco")
        #expect(gone == ["bea"])
    }

    /// A guest is told the host went even if it never heard from them on this socket.
    @Test func aMissingHostIsReportedWhetherOrNotItWasHeardFrom() {
        let gone = RelaySession.leftMeanwhile(known: [], present: ["cleo"], host: "marco", me: "bea")
        #expect(gone == ["marco"])
    }

    @Test func everybodyStillThereIsNews() {
        #expect(RelaySession.leftMeanwhile(known: ["bea"], present: ["bea"], host: "marco", me: "marco").isEmpty)
    }
}
