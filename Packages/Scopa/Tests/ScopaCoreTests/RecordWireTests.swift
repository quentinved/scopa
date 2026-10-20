import Foundation
import Testing
@testable import ScopaCore

private func player(_ name: String) -> Player { Player(id: .init(rawValue: "gc:T\(name.lowercased())0123456789"), name: name) }

/// A whole game played out by the automatic move, for a record as long as a real one.
private func playedRecord(seats: Int, to target: Int) async throws -> GameRecord {
    let players = ["Ada", "Bea", "Cleo", "Dino"].prefix(seats).map(player)
    let configuration = try GameConfiguration(players: Array(players), teams: seats == 4, targetScore: target)
    let session = GameSession(configuration: configuration, rng: SeededGenerator(seed: 5))
    _ = await session.startRound()
    while await !session.state.isFinished {
        let state = await session.state
        if state.phase != .playing { _ = await session.startRound(); continue }
        _ = try await session.play(try #require(Rules.automaticMove(in: state)))
    }
    return await session.record
}

/// What a room's frame weighs: the envelope as an escaped string inside the Worker's own JSON.
private func roomFrameSize(_ message: GameMessage, from sender: PlayerID) throws -> Int {
    struct Outbound: Encodable { let to: String; let data: String }
    let sealed = try #require(String(data: try Wire.encode(Envelope(from: sender, message: message)), encoding: .utf8))
    return try JSONEncoder().encode(Outbound(to: "all", data: sealed)).count
}

@Suite struct LongRecords {
    /// A game to fifty-one is past the Worker's 64 KB and Game Center's 87 KB as it is.
    @Test func aGameToFiftyOneFitsEveryCarrierAndReadsBack() async throws {
        for seats in [2, 4] {
            let record = try await playedRecord(seats: seats, to: 51)
            let sender = player("Ada").id
            let message = Wire.message(for: record, from: sender)
            guard case .packedRecord(let packed) = message else {
                Issue.record("A game to 51 went out plain")
                continue
            }
            #expect(try roomFrameSize(message, from: sender) < 64 * 1024)
            #expect(try Wire.encode(Envelope(from: sender, message: message)).count < 87 * 1024)
            #expect(Wire.unpack(packed) == record)
        }
    }

    /// A game an older build could always read still goes out the way it always did.
    @Test func anOrdinaryGameGoesOutPlain() async throws {
        let record = try await playedRecord(seats: 2, to: 11)
        #expect(Wire.message(for: record, from: player("Ada").id) == .record(record))
    }

    @Test func aGuestReadsAPackedRecordAsTheRecord() async throws {
        let record = try await playedRecord(seats: 2, to: 51)
        let network = LoopbackNetwork()
        let host = network.transport(for: player("Ada"))
        let guest = GuestClient(transport: network.transport(for: player("Bea")))
        var heard = await guest.updates.makeAsyncIterator()
        await guest.start()
        try await host.send(Wire.message(for: record, from: host.localPlayer.id), to: .all)
        #expect(await heard.next() == .record(record))
        await guest.stop()
    }

    /// The new messages survive the wire, and a reply nobody understands is not a crash.
    @Test func theNewMessagesSurviveTheWire() throws {
        for message in [GameMessage.forfeit, .packedRecord(Data([1, 2, 3]))] {
            let envelope = Envelope(from: player("Bea").id, message: message)
            #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
        }
        #expect(Wire.unpack(Data([1, 2, 3])) == nil)
    }
}
