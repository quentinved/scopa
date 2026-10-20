import Foundation

/// Denari sold for real money, in three bags.
///
/// Each is a consumable on the App Store: bought as often as wanted and never restored by
/// Apple. So what a bag paid lives only in the ledger, keyed on the App Store's transaction,
/// and travels to the player's other devices like any other entry.
public enum DenariBag: String, CaseIterable, Identifiable, Sendable {
    case mancia, borsellino, tesoretto

    public var id: String { rawValue }

    /// Must match the products made by Tools/seed-denari.sh.
    public var productID: String { "com.quentinvedrenne.scopa.denari.\(rawValue)" }

    /// Named like the packs, in Italian, and never translated.
    public var title: String { rawValue.capitalized }

    public var denari: Denari {
        switch self {
        case .mancia: 2_500
        case .borsellino: 12_000
        case .tesoretto: 30_000
        }
    }

    public init?(productID: String) {
        guard let bag = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = bag
    }

    public static let note = "bought"

    /// One App Store transaction pays once, whichever launch or device hands it over.
    public static func key(transaction: UInt64) -> String { "denari.buy/\(transaction)" }

    /// Belgium and the Netherlands treat a random pack paid for with bought currency as
    /// gambling, so denari are not sold there. App Store Connect leaves them out too; this
    /// is the app's own word on it. ISO 3166 alpha-3, as `Storefront.countryCode` gives it.
    public static let withheldStorefronts: Set<String> = ["BEL", "NLD"]

    /// Unknown counts as sold: the App Store's own availability still decides then.
    public static func isSold(in storefront: String?) -> Bool {
        guard let storefront else { return true }
        return !withheldStorefronts.contains(storefront.uppercased())
    }
}
