import Foundation
import Testing
@testable import ScopaCore

private func player(_ name: String) -> Player { Player(id: .init(rawValue: name.lowercased()), name: name) }

/// Collects one stream's updates, so a test can wait for one without a fixed sleep.
private actor Heard {
    private var updates: [TableUpdate] = []
    private var task: Task<Void, Never>?

    func listen(_ stream: AsyncStream<TableUpdate>) {
        task = Task { for await update in stream { self.updates.append(update) } }
    }

    /// Waits by the clock rather than by counting yields: on a busy machine the host's actor
    /// can be a long way behind a few hundred yields.
    func first(within limit: Duration = .seconds(3), where match: @Sendable (TableUpdate) -> Bool) async -> TableUpdate? {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if let hit = updates.first(where: match) { return hit }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return updates.first(where: match)
    }

    func forget() { updates = [] }
}

private func isReturn(of id: PlayerID) -> @Sendable (TableUpdate) -> Bool {
    { if case .playerReturned(let who) = $0 { who == id } else { false } }
}

/// A host and the named guests on one loopback network, every guest seated and the game dealt.
private func dealtTable(_ names: [String]) async throws -> (LoopbackNetwork, HostCoordinator, Heard, [Heard]) {
    let network = LoopbackNetwork()
    let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero,
                               rng: SeededGenerator(seed: 11))
    let hostHeard = Heard()
    await hostHeard.listen(host.updates)
    await host.start()
    var heard: [Heard] = []
    for name in names {
        let guest = GuestClient(transport: network.transport(for: player(name)))
        let ears = Heard()
        await ears.listen(guest.updates)
        await guest.start()
        try await guest.join()
        heard.append(ears)
    }
    _ = await hostHeard.first { if case .lobby(let lobby) = $0 { lobby.players.count == names.count + 1 } else { false } }
    try await host.startGame()
    return (network, host, hostHeard, heard)
}

@Suite struct ComingBack {
    @Test func everyoneHearsWhenAPlayerIsBack() async throws {
        let (network, host, hostHeard, heard) = try await dealtTable(["Bea", "Cleo"])
        network.disconnect(player("Bea").id)
        _ = await hostHeard.first { if case .playerLeft = $0 { true } else { false } }

        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        let beaHeard = Heard()
        await beaHeard.listen(bea.updates)
        await bea.start()
        try await bea.join()

        #expect(await hostHeard.first(where: isReturn(of: player("Bea").id)) != nil)
        #expect(await heard[1].first(where: isReturn(of: player("Bea").id)) != nil)
        #expect(await beaHeard.first { if case .view(let view) = $0 { view.seat == 1 } else { false } } != nil)
        await host.stop()
    }

    /// A connection that blips without the table noticing is not a return worth announcing.
    @Test func aJoinFromSomebodyNeverGoneIsOnlyACatchUp() async throws {
        let (network, host, hostHeard, _) = try await dealtTable(["Bea"])
        let again = GuestClient(transport: network.transport(for: player("Bea")))
        let againHeard = Heard()
        await againHeard.listen(again.updates)
        await again.start()
        try await again.join()

        #expect(await againHeard.first { if case .view = $0 { true } else { false } } != nil)
        #expect(await hostHeard.first(within: .milliseconds(300), where: isReturn(of: player("Bea").id)) == nil)
        await host.stop()
    }

    /// A join asked again before the deal, because the first answer was slow, keeps the chair.
    @Test func aSecondJoinBeforeTheDealIsAnsweredNotRefused() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero)
        let hostHeard = Heard()
        await hostHeard.listen(host.updates)
        await host.start()
        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        let beaHeard = Heard()
        await beaHeard.listen(bea.updates)
        await bea.start()
        try await bea.join()
        try await bea.join()

        #expect(await beaHeard.first { if case .lobby(let lobby) = $0 { lobby.players.count == 2 } else { false } } != nil)
        #expect(await beaHeard.first(within: .milliseconds(300)) { $0 == .joinRefused } == nil)
        #expect(await host.lobby.players.count == 2)
        await host.stop()
    }

    @Test func theHostCatchesEveryGuestUpAfterItsOwnDrop() async throws {
        let (_, host, _, heard) = try await dealtTable(["Bea"])
        _ = await heard[0].first { if case .view = $0 { true } else { false } }
        await heard[0].forget()

        await host.catchUp()
        #expect(await heard[0].first { if case .lobby = $0 { true } else { false } } != nil)
        #expect(await heard[0].first { if case .view(let view) = $0 { view.seat == 1 } else { false } } != nil)
        await host.stop()
    }

    @Test func aHostWalkingOutSaysSo() async throws {
        let (_, host, _, heard) = try await dealtTable(["Bea", "Cleo"])
        await host.closeTable()
        for ears in heard {
            #expect(await ears.first { $0 == .tableClosed } != nil)
        }
        await host.stop()
    }

    /// A guest walking out says so, and the host hears who: what lets it report the walk-out.
    @Test func aGuestWalkingOutSaysSo() async throws {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero,
                                   rng: SeededGenerator(seed: 11))
        let hostHeard = Heard()
        await hostHeard.listen(host.updates)
        await host.start()
        let bea = GuestClient(transport: network.transport(for: player("Bea")))
        await bea.start()
        try await bea.join()
        _ = await hostHeard.first { if case .lobby(let lobby) = $0 { lobby.players.count == 2 } else { false } }

        // Before the deal there is no game to walk out of.
        try await bea.forfeit()
        #expect(await hostHeard.first(within: .milliseconds(300)) { $0 == .forfeited(player("Bea").id) } == nil)

        try await host.startGame()
        try await bea.forfeit()
        #expect(await hostHeard.first { $0 == .forfeited(player("Bea").id) } != nil)
        await host.stop()
    }

    /// Guests read off the lobby whether the host will report their walking out too.
    @Test func aHostSaysItTakesForfeitsAndAnOlderOneSaysNothing() async throws {
        let (_, host, _, _) = try await dealtTable(["Bea"])
        #expect(await host.lobby.takesForfeits == true)
        let older = #"{"host":{"id":"h","name":"H"},"players":[{"id":"h","name":"H"}],"teams":false}"#
        #expect(try JSONDecoder().decode(Lobby.self, from: Data(older.utf8)).takesForfeits == nil)
        await host.stop()
    }

    @Test func theNewMessagesSurviveTheWire() throws {
        for message in [GameMessage.playerReturned(player("Bea").id), .tableClosed] {
            let envelope = Envelope(from: player("Host").id, message: message)
            #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
        }
    }
}

@Suite struct LinkStates {
    @Test func aRoomWaitsForItsHostAndCanBeWaitedOnAgain() {
        var link = TableLink(carrier: .relay)
        link.apply(.hostLeft("Marco"))
        #expect(link.state == .hostAway("Marco"))
        link.apply(.waitedOut)
        #expect(link.state == .hostGone("Marco"))
        link.apply(.keepWaiting)
        #expect(link.state == .hostAway("Marco"))
        link.apply(.hostBack)
        #expect(link.state == .steady)
    }

    @Test func gameCenterWaitsOnlyAtATableOfTwo() {
        var two = TableLink(carrier: .gameCenter(phones: 2))
        two.apply(.hostLeft("Marco"))
        #expect(two.state == .hostAway("Marco"))
        #expect(two.hostPatience == .seconds(20))

        var four = TableLink(carrier: .gameCenter(phones: 4))
        four.apply(.hostLeft("Marco"))
        #expect(four.state == .hostGone("Marco"))
        four.apply(.keepWaiting)
        #expect(four.state == .hostGone("Marco"))
    }

    /// How long a host is waited for is the table's size when they drop, not when it was sat at.
    @Test func gameCenterCountsThePhonesAtTheDrop() {
        var grown = TableLink(carrier: .gameCenter(phones: 2))
        grown.count(phones: 3)
        grown.apply(.hostLeft("Marco"))
        #expect(grown.state == .hostGone("Marco"))

        var shrunk = TableLink(carrier: .gameCenter(phones: 3))
        shrunk.count(phones: 2)
        shrunk.apply(.hostLeft("Marco"))
        #expect(shrunk.state == .hostAway("Marco"))

        var room = TableLink(carrier: .relay)
        room.count(phones: 4)
        #expect(room.carrier == .relay)
    }

    @Test func nearbyNeverWaitsAndNeverReconnects() {
        var link = TableLink(carrier: .nearby)
        #expect(!link.canReconnect)
        link.apply(.dropped)
        #expect(link.state == .steady)
        link.apply(.hostLeft("Marco"))
        #expect(link.state == .hostGone("Marco"))
    }

    @Test func aRoomsOwnLineDropsMendsAndCanBeGivenUpOn() {
        var link = TableLink(carrier: .relay)
        link.apply(.dropped)
        #expect(link.state == .reconnecting)
        link.apply(.restored)
        #expect(link.state == .steady)
        link.apply(.dropped)
        link.apply(.gaveUp)
        #expect(link.state == .lost)
        link.apply(.restored)
        #expect(link.state == .steady)
    }

    /// Hearing from the host settles a wait for the host, and nothing else.
    @Test func theHostAnsweringDoesNotHideALostLine() {
        var link = TableLink(carrier: .relay)
        link.apply(.gaveUp)
        link.apply(.hostBack)
        #expect(link.state == .lost)
    }

    /// The line coming back and the host being missing arrive on two streams, in either order.
    /// Heard the other way round, the wait for the host used to vanish with nobody waiting.
    @Test func thisPhonesLineMendingDoesNotEndAWaitForTheHost() {
        var link = TableLink(carrier: .relay)
        link.apply(.hostLeft("Marco"))
        link.apply(.restored)
        #expect(link.state == .hostAway("Marco"))
        link.apply(.waitedOut)
        link.apply(.restored)
        #expect(link.state == .hostGone("Marco"))
    }
}

@Suite struct LeavingEarly {
    private let deal = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func walkingOutIsFreeForTheFirstTwoMinutesOnly() {
        #expect(EarlyExit.isFree(dealtAt: deal, at: deal.addingTimeInterval(5)))
        #expect(EarlyExit.isFree(dealtAt: deal, at: deal.addingTimeInterval(119)))
        #expect(!EarlyExit.isFree(dealtAt: deal, at: deal.addingTimeInterval(120)))
        // A game picked up after a relaunch, whose deal this phone never saw.
        #expect(!EarlyExit.isFree(dealtAt: nil, at: deal))
    }

    /// Judged by the last sign from the chair, not by when its going was heard: a dropped line
    /// can be noticed minutes after it went.
    @Test func aChairIsJudgedByWhenItWasLastSeen() {
        #expect(EarlyExit.callsOff(dealtAt: deal, lastSeen: nil))
        #expect(EarlyExit.callsOff(dealtAt: deal, lastSeen: deal.addingTimeInterval(90)))
        // The allowance covers a guest whose clock started a moment after the host's.
        #expect(EarlyExit.callsOff(dealtAt: deal, lastSeen: deal.addingTimeInterval(125)))
        #expect(!EarlyExit.callsOff(dealtAt: deal, lastSeen: deal.addingTimeInterval(EarlyExit.window + EarlyExit.allowance)))
        #expect(!EarlyExit.callsOff(dealtAt: nil, lastSeen: nil))
    }

    @Test func everyPhoneHearsTheGameCalledOffOnce() async throws {
        let (_, host, hostHeard, heard) = try await dealtTable(["Bea", "Cleo"])
        await host.callOff(leftBy: player("Bea").id)
        // Somebody else going after it does not rename who called it off.
        await host.callOff(leftBy: player("Cleo").id)
        #expect(await host.lobby.leftEarly == player("Bea").id)
        #expect(await hostHeard.first { if case .lobby(let lobby) = $0 { lobby.leftEarly != nil } else { false } } != nil)
        for ears in heard {
            let calledOff = await ears.first { if case .lobby(let lobby) = $0 { lobby.leftEarly != nil } else { false } }
            #expect(calledOff == .lobby(await host.lobby))
        }
        await host.stop()
    }

    @Test func nothingIsCalledOffBeforeTheDeal() async {
        let network = LoopbackNetwork()
        let host = HostCoordinator(transport: network.transport(for: player("Host")), pace: .zero)
        await host.start()
        await host.callOff(leftBy: player("Host").id)
        #expect(await host.lobby.leftEarly == nil)
        await host.stop()
    }

    /// A phone sitting back down reads it off the lobby the host sends it.
    @Test func aPhoneComingBackHearsItWasCalledOff() async throws {
        let (network, host, hostHeard, _) = try await dealtTable(["Bea"])
        network.disconnect(player("Bea").id)
        _ = await hostHeard.first { if case .playerLeft = $0 { true } else { false } }
        await host.callOff(leftBy: player("Bea").id)

        let back = GuestClient(transport: network.transport(for: player("Bea")))
        let ears = Heard()
        await ears.listen(back.updates)
        await back.start()
        try await back.join()
        #expect(await ears.first { if case .lobby(let lobby) = $0 { lobby.leftEarly == player("Bea").id } else { false } } != nil)
        await host.stop()
    }

    @Test func anOlderLobbyNamesNobodyAndTheNameSurvivesTheWire() throws {
        let older = #"{"host":{"id":"h","name":"H"},"players":[{"id":"h","name":"H"}],"teams":false}"#
        #expect(try JSONDecoder().decode(Lobby.self, from: Data(older.utf8)).leftEarly == nil)
        var lobby = Lobby(host: player("Host"))
        lobby.leftEarly = player("Bea").id
        let envelope = Envelope(from: player("Host").id, message: .lobby(lobby))
        #expect(try Wire.decode(Wire.encode(envelope)) == envelope)
    }
}
