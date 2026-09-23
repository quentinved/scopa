/// What a category the sides end level on is worth: nothing (the rulebook) or a point each.
public enum TieRule: String, CaseIterable, Codable, Sendable, Hashable {
    case classic, shared

    public static let `default` = TieRule.classic

    public var title: String {
        switch self {
        case .classic: "Regular"
        case .shared: "Tim"
        }
    }

    public var detail: String {
        switch self {
        case .classic: "A category you end level on is nobody's point"
        case .shared: "A category you end level on is a point each"
        }
    }
}
