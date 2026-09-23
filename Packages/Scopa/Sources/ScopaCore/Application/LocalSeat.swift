/// A chair at a table played on one phone: either somebody who takes the phone when their
/// turn comes round, or a bot that plays itself.
public enum LocalSeat: Hashable, Sendable {
    case person(name: String)
    case bot(name: String)

    public var name: String {
        switch self {
        case .person(let name), .bot(let name): name
        }
    }

    public var isBot: Bool {
        if case .bot = self { true } else { false }
    }

    /// The seated players and the bot seats among them, in seat order. Seat identifiers are
    /// positional because nothing here crosses a network: the phone is the whole table.
    public static func table(_ seats: [LocalSeat]) -> (players: [Player], bots: Set<Int>) {
        let players = seats.enumerated().map {
            Player(id: PlayerID(rawValue: "seat-\($0.offset)"), name: $0.element.name, isBot: $0.element.isBot)
        }
        let bots = seats.indices.filter { seats[$0].isBot }
        return (players, Set(bots))
    }
}
