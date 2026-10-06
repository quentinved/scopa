import Foundation
import Testing
@testable import ScopaCore

@Suite struct PlayerOnTheWire {
    @Test func aSeatCarriesItsFlourish() throws {
        let player = Player(id: .init(rawValue: "a"), name: "A", flourish: "coriandoli")
        let back = try JSONDecoder().decode(Player.self, from: try JSONEncoder().encode(player))
        #expect(back.flourish == "coriandoli")
    }

    @Test func aPlainSeatSendsNoFlourish() throws {
        let data = try JSONEncoder().encode(Player(id: .init(rawValue: "a"), name: "A"))
        #expect(!String(decoding: data, as: UTF8.self).contains("flourish"))
    }
}
