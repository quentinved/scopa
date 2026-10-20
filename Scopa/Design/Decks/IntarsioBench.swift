import ScopaCore
import SwiftUI

#if DEBUG
/// `DeckBench` for the drafts: every face of each draft deck rendered off screen and
/// rasterised the way `CardView` does it, at the table's size and the hand's, twice. Shown
/// by `-deckDraft intarsio -deckBench`, before Intarsio is a `CardStyle` the other can time.
struct IntarsioBench: View {
    @State private var lines: [String] = ["Timing…"]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines, id: \.self) { line in
                Text(verbatim: line)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.onTable)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            lines = DeckDraft.allCases.flatMap { draft in Self.widths.map { Self.line(draft, width: $0) } }
        }
    }

    private static let widths: [CGFloat] = [62, 96]

    private static func line(_ draft: DeckDraft, width: CGFloat) -> String {
        let first = times(draft, width: width)
        let again = times(draft, width: width)
        return String(format: "%@ %3.0fpt first %5.1f again %5.1f worst %5.1f ms",
                      draft.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0),
                      width, mean(first), mean(again), again.max() ?? 0)
    }

    private static func mean(_ costs: [Double]) -> Double { costs.reduce(0, +) / Double(max(costs.count, 1)) }

    @MainActor private static func times(_ draft: DeckDraft, width: CGFloat) -> [Double] {
        Deck.standard.map { card in
            let start = Date.now
            let renderer = ImageRenderer(content: draft.face(card, width: width).drawingGroup())
            renderer.scale = 3
            _ = renderer.cgImage
            return Date.now.timeIntervalSince(start) * 1000
        }
    }
}
#endif
