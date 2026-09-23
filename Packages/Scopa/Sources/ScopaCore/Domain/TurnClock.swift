/// How long a player gets before the table plays for them. Chosen by the host.
public enum TurnClock: String, CaseIterable, Codable, Sendable, Hashable {
    case off, relaxed, brisk

    public static let `default` = TurnClock.off

    public var seconds: Int? {
        switch self {
        case .off: nil
        case .relaxed: 30
        case .brisk: 15
        }
    }

    public var title: String {
        switch self {
        case .off: "No clock"
        case .relaxed: "30 seconds"
        case .brisk: "15 seconds"
        }
    }

    public var detail: String {
        switch self {
        case .off: "Take as long as you like"
        case .relaxed: "Enough time to count, but the game keeps moving"
        case .brisk: "Think fast"
        }
    }
}
