import ScopaCore
import SwiftUI

/// The app's name and tagline.
enum Brand {
    static let title = "SCOPA"
    static let tagline = "at the table"
}

/// The broom on its glass coin with three cards of the deck in use fanned behind it, and
/// the wordmark.
///
/// Side by side and small at the top of a portrait lobby: stacked, it stood 160 points tall
/// and pushed the last row of the lobby under the banner on every visit, not just the first.
/// Stacked on the left half of a landscape lobby, where height is not what is short.
struct BrandLockup: View {
    @Environment(\.lift) private var lift
    var stacked = false
    /// How far a side-by-side lockup has grown into the room the lobby leaves it: 0 is the
    /// snug size a full column keeps, 1 the roomy one. See `MastheadRoom`.
    var growth: CGFloat = 0

    /// The roomy lockup against the snug one. The coins either side are what stop it: any
    /// wider and the fan reaches the wheel's.
    static let roomyScale: CGFloat = 1.1

    private static func scale(_ growth: CGFloat) -> CGFloat { 1 + (roomyScale - 1) * growth }

    /// The side-by-side lockup's height before the lift: the crest's frame, which is taller
    /// than the wordmark beside it. The fan leans up out of it.
    static func rowHeight(growth: CGFloat) -> CGFloat { 78 * scale(growth) }

    var body: some View {
        if stacked {
            VStack(spacing: 8 * lift) {
                crest(fan: 38, broom: 34, rise: 20, sink: 12)
                    .frame(height: 92 * lift)
                wordmark(50)
            }
        } else {
            let scale = Self.scale(growth)
            HStack(spacing: 12 * scale * lift) {
                crest(fan: 36 * scale, broom: 28 * scale, rise: 14 * scale, sink: 12 * scale)
                    .frame(width: 76 * scale * lift, height: Self.rowHeight(growth: growth) * lift)
                wordmark(54 * scale)
            }
        }
    }

    /// The fan leans up out of the frame and the coin sits over its foot.
    private func crest(fan: CGFloat, broom: CGFloat, rise: CGFloat, sink: CGFloat) -> some View {
        ZStack {
            MastheadFan(width: fan * lift)
                .offset(y: -rise * lift)
            BroomMark(size: broom * lift, tint: Palette.goldLight)
                .padding(broom * 0.42 * lift)
                .glass(.riviera(), in: .circle)
                .offset(y: sink * lift)
        }
    }

    private func wordmark(_ size: CGFloat) -> some View {
        Text(Brand.title)
            .font(.display(size * lift))
            .foregroundStyle(Palette.onTable)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}

/// Three cards of the deck in use, fanned behind the broom.
struct MastheadFan: View {
    @Environment(\.lift) private var lift
    let width: CGFloat

    private static let cards = [Card(.ace, of: .clubs), Card.settebello, Card(.knight, of: .cups)]

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            ForEach(Array(Self.cards.enumerated()), id: \.element) { index, card in
                let position = Double(index) - 1
                CardView(card: card, width: width)
                    .rotationEffect(.degrees(position * 18), anchor: .bottom)
                    .offset(x: position * width * 0.34)
            }
        }
        .shadow(color: felt.shade(0.5), radius: 10, y: 6)
    }
}
