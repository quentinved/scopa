import SwiftUI

/// The cards on the cloth in one row: side by side while there is room, tucked over each
/// other's right-hand edge once there is not.
///
/// The row tightens and the cards never shrink. `CardArt` is rasterised from its width,
/// so resizing cards as the table filled rebuilt every face on every frame of the spring.
/// Tucking to the right keeps the rank in the top-left corner visible, and the card laid
/// last is drawn on top.
struct OverlapRow: Layout {
    /// The gap between two cards while the row is loose enough to have gaps at all.
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let card = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        let step = step(count: subviews.count, card: card.width, within: proposal.width ?? .infinity)
        return CGSize(width: card.width + step * CGFloat(subviews.count - 1), height: card.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let card = subviews.first?.sizeThatFits(.unspecified) else { return }
        let step = step(count: subviews.count, card: card.width, within: bounds.width)
        var x = bounds.midX - (card.width + step * CGFloat(subviews.count - 1)) / 2
        for view in subviews {
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: .unspecified)
            x += step
        }
    }

    /// The distance from one card to the next: a whole card and a gap while they all fit,
    /// otherwise whatever the width will take. Every card is the same size, so the first
    /// one's width speaks for the lot.
    private func step(count: Int, card: CGFloat, within available: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        let loose = card + spacing
        guard card + loose * CGFloat(count - 1) > available else { return loose }
        return max((available - card) / CGFloat(count - 1), 0)
    }
}
