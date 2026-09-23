import SwiftUI

/// The pattern printed on the back of every card.
///
/// Chosen separately from `CardTheme` so any back works with any deck. The colours still
/// come from the deck, so only the ruling changes.
enum CardBackPattern: String, CaseIterable, Identifiable {
    case lattice, chevron, rosette, weave, stars

    var id: String { rawValue }

    /// Where the phone keeps its owner's choice.
    static let stored = "cardBack"

    /// The house ruling, and the only one that costs nothing.
    static let free: CardBackPattern = .lattice

    var name: String {
        switch self {
        case .lattice: String(localized: "Lattice")
        case .chevron: String(localized: "Chevron")
        case .rosette: String(localized: "Rosette")
        case .weave: String(localized: "Weave")
        case .stars: String(localized: "Stars")
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .lattice: "The house ruling, crossed fine"
        case .chevron: "Ranks of arrows, close set"
        case .rosette: "The coin's own flower, repeated"
        case .weave: "Squared off, like linen"
        case .stars: "Small points, scattered even"
        }
    }
}

/// Every back pattern as one shape, so a card draws exactly one path whichever is chosen.
///
/// All line work: a fill at card size turns into a smudge.
struct BackPattern: Shape {
    var pattern: CardBackPattern
    var step: CGFloat

    func path(in rect: CGRect) -> Path {
        switch pattern {
        case .lattice: lattice(in: rect)
        case .chevron: chevron(in: rect)
        case .rosette: rosette(in: rect)
        case .weave: weave(in: rect)
        case .stars: stars(in: rect)
        }
    }

    /// Diagonals both ways.
    private func lattice(in rect: CGRect) -> Path {
        var path = Path()
        let span = rect.width + rect.height
        var offset = -rect.height
        while offset < rect.width {
            path.move(to: CGPoint(x: offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.minY))
            path.move(to: CGPoint(x: span - offset - rect.height, y: rect.maxY))
            path.addLine(to: CGPoint(x: span - offset - rect.height * 2, y: rect.minY))
            offset += step
        }
        return path
    }

    /// Rows of arrows, every row pointing the same way.
    private func chevron(in rect: CGRect) -> Path {
        var path = Path()
        let width = step * 0.9
        var y = rect.minY
        while y < rect.maxY + step {
            var x = rect.minX - width
            while x < rect.maxX + width {
                path.move(to: CGPoint(x: x, y: y + step * 0.45))
                path.addLine(to: CGPoint(x: x + width / 2, y: y))
                path.addLine(to: CGPoint(x: x + width, y: y + step * 0.45))
                x += width
            }
            y += step * 0.75
        }
        return path
    }

    /// The rosette off the coins suit, small and repeated.
    private func rosette(in rect: CGRect) -> Path {
        var path = Path()
        let radius = step * 0.3
        var y = rect.minY + step * 0.5
        var row = 0
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? step * 0.5 : step)
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2))
                for petal in 0..<4 {
                    let angle = Double(petal) * .pi / 2
                    path.move(to: CGPoint(x: x + cos(angle) * radius, y: y + sin(angle) * radius))
                    path.addLine(to: CGPoint(x: x + cos(angle) * radius * 1.75,
                                             y: y + sin(angle) * radius * 1.75))
                }
                x += step
            }
            y += step
            row += 1
        }
        return path
    }

    /// Squares, ruled both ways.
    private func weave(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y < rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return path
    }

    /// Four-pointed stars on an offset grid.
    private func stars(in rect: CGRect) -> Path {
        var path = Path()
        let reach = step * 0.34
        var y = rect.minY + step * 0.5
        var row = 0
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? step * 0.5 : step)
            while x < rect.maxX {
                path.move(to: CGPoint(x: x - reach, y: y))
                path.addLine(to: CGPoint(x: x + reach, y: y))
                path.move(to: CGPoint(x: x, y: y - reach))
                path.addLine(to: CGPoint(x: x, y: y + reach))
                let corner = reach * 0.45
                path.move(to: CGPoint(x: x - corner, y: y - corner))
                path.addLine(to: CGPoint(x: x + corner, y: y + corner))
                path.move(to: CGPoint(x: x + corner, y: y - corner))
                path.addLine(to: CGPoint(x: x - corner, y: y + corner))
                x += step
            }
            y += step
            row += 1
        }
        return path
    }
}

extension EnvironmentValues {
    /// Read by the card views, so nothing in between has to carry it.
    @Entry var cardBack: CardBackPattern = .lattice
}
