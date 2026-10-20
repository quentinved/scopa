import ScopaCore
import SwiftUI

#if DEBUG
/// What one face costs to draw, in each drawing at the table's size and the hand's: every
/// card of the deck rendered off screen the way `CardView` rasterises it, twice. The first
/// pass includes whatever a deck sets up once (Mosaico's tesserae), the second is what any
/// later draw costs. A debug build, so only the drawings against each other mean anything.
struct DeckBench: View {
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
            lines = Self.styles.flatMap { style in Self.widths.map { Self.line(style, width: $0) } }
        }
    }

    private static let styles: [CardStyle] = [.classica, .litografia, .maiolica, .mosaico, .carnevale, .intarsio,
                                              .merletto, .tarocchi]
    private static let widths: [CGFloat] = [62, 96]

    private static func line(_ style: CardStyle, width: CGFloat) -> String {
        let first = times(style, width: width)
        let again = times(style, width: width)
        return String(format: "%@ %3.0fpt first %5.1f again %5.1f worst %5.1f ms",
                      style.title.padding(toLength: 10, withPad: " ", startingAt: 0),
                      width, mean(first), mean(again), again.max() ?? 0)
    }

    private static func mean(_ costs: [Double]) -> Double { costs.reduce(0, +) / Double(max(costs.count, 1)) }

    @MainActor private static func times(_ style: CardStyle, width: CGFloat) -> [Double] {
        Deck.standard.map { card in
            let start = Date.now
            let renderer = ImageRenderer(content: CardView(card: card, width: width)
                .environment(\.cardTheme, CardTheme(style: style, skin: .riviera)))
            renderer.scale = 3
            _ = renderer.cgImage
            return Date.now.timeIntervalSince(start) * 1000
        }
    }
}
#endif
