import Foundation
import Testing
@testable import ScopaCore

private func player(_ name: String) -> Player { Player(id: .init(rawValue: name.lowercased()), name: name) }

/// The house at a ranked table is decided once, by the phone that plays it, and every phone
/// reads that one decision: two friends in a duo once saw the same two bots as Diamond on one
/// phone and Bronze on the other, each worked out from that phone's own rank.
@Suite struct HouseStep {
    /// The strongest player at the table sets it, so a pair never meets an easier house by
    /// letting the weaker friend lead.
    @Test func theStrongestPlayerAtTheTableSetsTheHouse() {
        #expect(Ranking.houseStep(among: [2, 13]) == 13)
        #expect(Ranking.houseStep(among: [13, 2]) == 13)
        #expect(Ranking.houseStep(among: []) == 0)
        #expect(Ranking.houseStep(among: [-4]) == 0)
        #expect(Ranking.houseStep(among: [40]) == BotStrength.topStep)
    }

    /// The league drawn over a house chair is the division its bot plays at, whatever points
    /// into the division the chair is given to tell two chairs apart.
    @Test func aHouseChairWearsTheLeagueItPlaysAt() {
        for step in 0...BotStrength.topStep {
            for jitter in [0, 37, 99, 100, 250, -3] {
                let worn = Ranking.standing(for: Ranking.houseRating(atStep: step, jitter: jitter))
                #expect(worn.step == step, "step \(step), jitter \(jitter) wore \(worn.title)")
                #expect(BotStrength.house(atStep: worn.step) == BotStrength.house(atStep: step))
            }
        }
    }

    @Test func theLobbyCarriesTheHouseStep() throws {
        let lobby = Lobby(host: player("A"), players: [player("A"), player("B")], houseStep: 12)
        let envelope = Envelope(from: player("A").id, message: .lobby(lobby))
        #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
    }

    /// A lobby from a build that never named the house still reads, with nothing named.
    @Test func anOlderLobbyNamesNoHouse() throws {
        let old = #"{"host":{"id":"a","name":"A"},"players":[{"id":"a","name":"A"}],"teams":false}"#
        let lobby = try JSONDecoder().decode(Lobby.self, from: Data(old.utf8))
        #expect(lobby.houseStep == nil)
    }

    /// The host names the step once: the guest reads it off the lobby, and the bots the host
    /// plays are the house at that very step.
    @Test func theHostNamesTheHouseAndItsBotsPlayAtIt() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), strength: BotLevel.hard.strength)
        await host.start()
        let guest = GuestClient(transport: network.transport(for: player("Bea")))
        let updates = await guest.updates
        let lobbies = Task { () -> Lobby? in
            for await update in updates {
                if case .lobby(let lobby) = update, lobby.houseStep != nil { return lobby }
            }
            return nil
        }
        await guest.start()
        try await guest.join()
        await host.addBots(upTo: 4, names: ["Hugo", "Lucas"])
        await host.setHouseStep(12)

        #expect(await host.botStrength == BotStrength.house(atStep: 12))
        #expect(await host.lobby.houseStep == 12)
        #expect(await lobbies.value?.houseStep == 12)
        await host.stop()
    }

    /// Once the cards are out the house cannot be changed under the players.
    @Test func theHouseIsNamedBeforeTheDealOnly() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero)
        await host.start()
        await host.addBots(upTo: 2, names: ["Hugo"])
        await host.setHouseStep(3)
        try await host.startGame()
        await host.setHouseStep(15)
        #expect(await host.botStrength == BotStrength.house(atStep: 3))
        #expect(await host.lobby.houseStep == 3)
        await host.stop()
    }
}

/// The day's ration of house games, which the Worker holds too (`HOUSE_GAMES_PER_DAY`).
@Suite struct HouseRation {
    @Test func fifteenHouseGamesCountADay() {
        #expect(Ranking.houseGamesPerDay == 15)
        // Won out from a standing start, the run included: about five divisions, as the
        // Worker's own test has it.
        let day = (0..<Ranking.houseGamesPerDay).reduce(0) { $0 + Ranking.houseChange(won: true, streak: $1) }
        #expect(day == 495)
    }
}
