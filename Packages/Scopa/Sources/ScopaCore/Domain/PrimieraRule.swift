/// How the primiera point is settled: the classic sum of each side's best card per suit,
/// or a plain count of sevens as many home tables play it.
public enum PrimieraRule: String, CaseIterable, Codable, Sendable, Hashable {
    case classic, mostSevens

    public static let `default` = PrimieraRule.mostSevens

    public var title: String {
        switch self {
        case .classic: "Classic"
        case .mostSevens: "Most sevens"
        }
    }

    public var detail: String {
        switch self {
        case .classic: "Your best card in each suit, added up: 7 is best, then 6, then the ace"
        case .mostSevens: "Whoever took more sevens. Level is nobody's point"
        }
    }
}
