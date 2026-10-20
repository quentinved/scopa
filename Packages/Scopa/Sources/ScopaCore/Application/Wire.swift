import Foundation

/// JSON on the wire. Kept in one place so every adapter agrees.
public enum Wire {
    public static func encode(_ envelope: Envelope) throws -> Data {
        try JSONEncoder().encode(envelope)
    }

    public static func decode(_ data: Data) throws -> Envelope {
        try JSONDecoder().decode(Envelope.self, from: data)
    }

    /// The most an envelope can weigh and go out as it is. The Worker refuses a frame over
    /// 64 KB and Game Center a reliable message over about 87; a room's frame carries the
    /// envelope as an escaped string, which grows it by about a fifth.
    public static let plainLimit = 40_000

    /// The finished game as it goes on the wire: plain while it fits, which is every game an
    /// older build has ever been sent, and compressed once a long game would not.
    public static func message(for record: GameRecord, from sender: PlayerID) -> GameMessage {
        let plain = GameMessage.record(record)
        guard let size = try? encode(Envelope(from: sender, message: plain)).count, size > plainLimit,
              let json = try? JSONEncoder().encode(record),
              let packed = try? (json as NSData).compressed(using: .zlib) as Data else { return plain }
        return .packedRecord(packed)
    }

    /// The record inside `packedRecord`, or nil if it does not read.
    public static func unpack(_ packed: Data) -> GameRecord? {
        guard let json = try? (packed as NSData).decompressed(using: .zlib) as Data else { return nil }
        return try? JSONDecoder().decode(GameRecord.self, from: json)
    }
}
