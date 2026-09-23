import Foundation

/// JSON on the wire. Kept in one place so every adapter agrees.
public enum Wire {
    public static func encode(_ envelope: Envelope) throws -> Data {
        try JSONEncoder().encode(envelope)
    }

    public static func decode(_ data: Data) throws -> Envelope {
        try JSONDecoder().decode(Envelope.self, from: data)
    }
}
