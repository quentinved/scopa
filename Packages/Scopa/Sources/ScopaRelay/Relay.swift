import Foundation
import ScopaCore

/// Tables we keep ourselves, on the Worker in `Server/`.
///
/// Game Center can only seat two people who happen to be searching in the same second,
/// which is no use for "open a table, I'll join when I'm off the train". A room is a real
/// thing with a four-letter name: the host opens it, passes the code on however they like,
/// and it sits there until the friend arrives.
///
/// Nobody has to be signed in to anything. The id is the one the phone already uses for
/// tables in the same room, so this works for a player who has never opened Game Center,
/// and it works between a build from Xcode and a build from TestFlight, which Game Center
/// pointedly does not.
public struct Relay: Sendable {
    /// The Worker. The same one that keeps the ladder.
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// A table that has just been opened: what to say down the phone, and what to send.
    public struct Table: Sendable, Hashable {
        public let code: String
        public let link: URL

        /// Spelled out because a public struct's memberwise initialiser is internal, and
        /// the app rebuilds a table whose code it already has, rejoining one it opened
        /// earlier, without going back through `open`.
        public init(code: String, link: URL) {
            self.code = code
            self.link = link
        }
    }

    /// A table somebody else opened, as it looks from outside before joining it.
    public struct Status: Sendable, Hashable, Decodable {
        public let host: String
        public let seated: Int
        public let capacity: Int
        /// Everyone sitting there now, by name.
        public let players: [String]

        public var isFull: Bool { seated >= capacity }
    }

    /// Opens a table and comes back with its code. The player who opens it deals.
    public func open(as player: Player, capacity: Int = GameConfiguration.playerRange.upperBound) async throws -> Table {
        struct Body: Encodable {
            let host: String
            let name: String
            let capacity: Int
        }
        struct Answer: Decodable {
            let code: String
            let link: String
        }
        var request = URLRequest(url: baseURL.appending(path: "v1/rooms"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            Body(host: player.id.rawValue, name: player.name, capacity: capacity)
        )
        // Nothing is being looked for here, so a 404 is the service missing rather than a
        // table missing, and "no table with that code" is nonsense to read while opening one.
        let answer: Answer
        do {
            answer = try await send(request)
        } catch RelayError.noSuchTable {
            throw RelayError.unreachable("The table service is not answering")
        }
        guard let link = URL(string: answer.link) else { throw RelayError.unreachable("The table has no link") }
        return Table(code: answer.code, link: link)
    }

    /// Whether that code is a table, and who is at it. Asked before joining, so a typo is
    /// answered by "no table with that code" rather than by a spinner that never stops.
    public func status(of code: String) async throws -> Status {
        try await send(URLRequest(url: baseURL.appending(path: "v1/rooms/\(Self.tidy(code))")))
    }

    /// The transport for one table. Nothing happens until it is connected.
    public func session(code: String, as player: Player) -> RelaySession {
        RelaySession(baseURL: baseURL, code: Self.tidy(code), localPlayer: player)
    }

    /// The link that seats a friend in one tap.
    public func link(to code: String) -> URL {
        baseURL.appending(path: "j/\(Self.tidy(code))")
    }

    /// A code as the server spells it: upper case, and without the spaces and dashes people
    /// add when they write one down.
    public static func tidy(_ code: String) -> String {
        String(code.uppercased().filter { alphabet.contains($0) }.prefix(length))
    }

    /// Reading a code out loud is half of what it is for, so no O against 0 and no I
    /// against 1. Must match the server's alphabet in `Server/src/room.ts`.
    public static let alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    public static let length = 4

    public static func isCode(_ code: String) -> Bool { tidy(code).count == length }

    /// The four letters folded into a number, so a code can ride inside a Game Center
    /// invitation.
    ///
    /// An invitation carries nothing the receiving app can read except the group it was
    /// made for, which arrives before anything has been accepted.
    /// So the code travels in the group. The top of the range is reserved for it: a group
    /// made from a pool name is a hash and never lands there, and four letters of a
    /// thirty-two letter alphabet are twenty bits, which fits underneath with room to spare.
    public static func inviteGroup(for code: String) -> Int? {
        let code = tidy(code)
        guard isCode(code) else { return nil }
        var value = 0
        for character in code {
            guard let position = alphabet.firstIndex(of: character) else { return nil }
            value = value << 5 | alphabet.distance(from: alphabet.startIndex, to: position)
        }
        return inviteMarker | value
    }

    /// The code inside an invitation's group, or nil when that group is an ordinary
    /// matchmaking pool and has nothing to do with us.
    public static func code(inGroup group: Int) -> String? {
        guard group & ~inviteRoom == inviteMarker else { return nil }
        var value = group & inviteRoom
        var code = ""
        for _ in 0..<length {
            let position = alphabet.index(alphabet.startIndex, offsetBy: value & 0b11111)
            code = String(alphabet[position]) + code
            value >>= 5
        }
        return code
    }

    /// The reserved block, and the twenty bits under it that spell the code out.
    private static let inviteMarker = 0x7F00_0000
    private static let inviteRoom = 0x000F_FFFF

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await withUnreachable { try await URLSession.shared.data(for: request) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            guard let value = try? JSONDecoder().decode(T.self, from: data) else {
                throw RelayError.unreachable("The table service answered something unexpected")
            }
            return value
        case 404: throw RelayError.noSuchTable
        case 409: throw RelayError.tableFull
        default: throw RelayError.unreachable("The table service is having trouble")
        }
    }

    private func withUnreachable<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as URLError {
            throw RelayError.unreachable(error.localizedDescription)
        }
    }
}

public enum RelayError: Error, Sendable, Hashable {
    /// No table with that code: a typo, or a table that has since been packed away.
    case noSuchTable
    case tableFull
    /// The phone could not reach the Worker, or the Worker could not answer.
    case unreachable(String)
    case disconnected
}

extension RelayError {
    /// What to show a player. The underlying text belongs in the log.
    public var explanation: String {
        switch self {
        case .noSuchTable: "No table with that code. Check it, or ask for a new one."
        case .tableFull: "That table is full."
        case .unreachable: "Could not reach the table. Check your connection."
        case .disconnected: "The connection to the table was lost."
        }
    }
}
