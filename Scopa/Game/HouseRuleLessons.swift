import Foundation
import ScopaCore

/// Which house rules this phone has been taught, so the campaign teaches each one once:
/// the first time a table brings it in, before the cards go out.
enum HouseRuleLessons {
    private static let key = "houseRules.learned"

    static var learned: Set<HouseRule> {
        let names = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(names.compactMap(HouseRule.init(rawValue:)))
    }

    /// The rules of `house` still to be taught, in the order the lesson shows them.
    static func unlearned(in house: Set<HouseRule>) -> [HouseRule] {
        let known = learned
        return HouseRule.allCases.filter { house.contains($0) && !known.contains($0) }
    }

    static func learn(_ rules: some Sequence<HouseRule>) {
        let all = learned.union(rules)
        UserDefaults.standard.set(all.map(\.rawValue).sorted(), forKey: key)
    }
}
