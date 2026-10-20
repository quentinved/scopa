import SwiftUI

/// How much of a portrait lobby the masthead takes: the lockup and the air round it, eased
/// between snug and roomy by the height the rest of the column leaves.
///
/// The header was squeezed to its snug size on 2026-10-13 so a full column cleared the
/// banner, and on most visits that left a strip of empty cloth at the foot instead of round
/// the name. The column is a different height on different days — a saved game adds a
/// door, the first deal ever a whole row — so the header takes the slack when there is
/// some and gives it back when there is not. Below snug the lobby scrolls, as it always did.
struct MastheadRoom: Equatable {
    /// 0 is snug, the sizes a full column keeps; 1 is roomy.
    private(set) var growth: CGFloat = 0
    /// Measured at least once. The first answer is laid out as it is, not grown into.
    private(set) var isSettled = false

    /// Over the lockup. The fan leans up out of its frame, so most of the snug figure is the
    /// fan's own; the rest is the air between it and the chips.
    func top(_ lift: CGFloat) -> CGFloat { (12 + 16 * growth) * lift }
    /// Between the lockup and the album pill under it.
    func under(_ lift: CGFloat) -> CGFloat { (10 + 5 * growth) * lift }
    /// Between the album pill and the day's goals, where the header ends.
    func after(_ lift: CGFloat) -> CGFloat { (12 + 10 * growth) * lift }
    /// How far the coins either side of a grown lockup reach into the column's margins, and
    /// how close they stand to it. Together they keep each coin the width it had beside the
    /// snug lockup, which is what "Sans pub" needs to be read whole.
    func bleed(_ lift: CGFloat) -> CGFloat { 11 * growth * lift }
    func coinGap(_ lift: CGFloat) -> CGFloat { (6 - 2 * growth) * lift }

    /// Everything that grows, at a given growth.
    private static func elastic(_ growth: CGFloat, lift: CGFloat) -> CGFloat {
        let room = MastheadRoom(growth: growth)
        return room.top(lift) + BrandLockup.rowHeight(growth: growth) * lift + room.under(lift) + room.after(lift)
    }

    /// Grows into, or gives back, what the column leaves of the height on screen. `column`
    /// was measured at the current growth, so what it holds besides the elastic part is the
    /// rest of the lobby. Answers whether anything changed.
    mutating func settle(column: CGFloat, viewport: CGFloat, lift: CGFloat) -> Bool {
        guard column > 0, viewport > 0 else { return false }
        let rest = column - Self.elastic(growth, lift: lift)
        let snug = Self.elastic(0, lift: lift)
        let roomy = Self.elastic(1, lift: lift)
        let next = min(max((viewport - rest - snug) / (roomy - snug), 0), 1)
        defer { isSettled = true }
        guard abs(next - growth) > 0.02 else { return !isSettled }
        growth = next
        return true
    }
}
