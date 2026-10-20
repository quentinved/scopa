import ScopaCore
import SwiftUI

/// What goes round every card: a thin border of bole, then the leaf. A court is gilded
/// right to the bole; a numeral's gesso lies inside a punched band of gold, and the
/// settebello's vermilion inside a wider band, ring-punched, and a fillet of ultramarine.
struct TarocchiFrame {
    let panel: TarocchiPanel
    let card: Card

    private var w: CGFloat { panel.w }
    private var settebello: Bool { card == .settebello }

    /// The bole's width, in card widths.
    static let bole: CGFloat = 0.034

    /// Where the field starts, in card widths in from the edge.
    static func field(_ card: Card) -> CGFloat {
        card.rank.isFace ? bole : card == .settebello ? 0.106 : 0.088
    }

    func paint() {
        panel.context.fill(Path(CGRect(x: 0, y: 0, width: w, height: w * 1.5)), with: .color(Tempera.bole))
        if card.rank.isFace { gilded() } else { banded() }
    }

    /// A court's ground: leaf to the bole, a punched row and an incised line round its edge.
    private func gilded() {
        let field = panel.rounded(Self.bole)
        panel.gild(field)
        if panel.fine {
            panel.punchRow(panel.rounded(Self.bole + 0.017), radius: w * 0.0058, pitch: w * 0.019)
            panel.stroke(panel.rounded(Self.bole + 0.03), Tempera.tool, 0.0035)
        }
        panel.context.stroke(field, with: .color(Tempera.ink), lineWidth: panel.hair)
    }

    /// The band of leaf round a numeral's field, and the field.
    private func banded() {
        let inner = Self.field(card)
        panel.context.fill(panel.rounded(Self.bole), with: .color(Tempera.gold))
        if panel.fine {
            if settebello { ringed(band: inner - 0.012) } else { tooled(inner) }
        }
        if settebello {
            panel.context.fill(panel.rounded(inner - 0.012), with: .color(TarocchiPigment.ultramarine.body))
            panel.sgraffito(panel.rounded(inner))
        } else {
            panel.context.fill(panel.rounded(inner), with: .color(Tempera.gesso))
        }
        panel.context.stroke(panel.rounded(Self.bole), with: .color(Tempera.ink), lineWidth: panel.hair)
        panel.context.stroke(panel.rounded(inner), with: .color(Tempera.ink), lineWidth: panel.hair)
    }

    /// A row of punches between two incised lines.
    private func tooled(_ inner: CGFloat) {
        panel.stroke(panel.rounded(Self.bole + 0.009), Tempera.tool, 0.0035)
        panel.stroke(panel.rounded(inner - 0.009), Tempera.tool, 0.0035)
        panel.punchRow(panel.rounded((Self.bole + inner) / 2), radius: w * 0.0078, pitch: w * 0.0225)
    }

    /// The settebello's: ring punches between two rows of dots, inside incised lines.
    private func ringed(band: CGFloat) {
        let outer = Self.bole
        panel.stroke(panel.rounded(outer + 0.007), Tempera.tool, 0.0035)
        panel.stroke(panel.rounded(band - 0.007), Tempera.tool, 0.0035)
        panel.punchRow(panel.rounded(outer + 0.0145), radius: w * 0.0042, pitch: w * 0.0135)
        panel.punchRow(panel.rounded(band - 0.0145), radius: w * 0.0042, pitch: w * 0.0135)
        panel.ringRow(panel.rounded((outer + band) / 2), radius: w * 0.0085, pitch: w * 0.025)
    }

    // MARK: Cartellini

    /// The paper labels a court's index is written on, so the figure passes behind the
    /// number rather than through it.
    func cartellini() {
        let size = Self.cartellino(card.rank)
        let box = CGRect(x: Self.cartellinoInset * w, y: Self.cartellinoInset * w,
                         width: size.width * w, height: size.height * w)
        let turned = CGRect(x: w - box.maxX, y: w * 1.5 - box.maxY, width: box.width, height: box.height)
        for rect in [box, turned] {
            panel.paint(RoundedRectangle(cornerRadius: w * 0.024).path(in: rect), Tempera.gesso)
            guard panel.fine else { continue }
            let rule = RoundedRectangle(cornerRadius: w * 0.014).path(in: rect.insetBy(dx: w * 0.013, dy: w * 0.013))
            panel.stroke(rule, Tempera.sinopia.opacity(0.45), 0.0032)
        }
    }

    static let cartellinoInset: CGFloat = 0.066

    /// A cartellino's size in card widths: wider for the king's two figures, taller for the
    /// knight's rule.
    static func cartellino(_ rank: Rank) -> CGSize {
        CGSize(width: rank == .king ? 0.30 : 0.205, height: rank == .knight ? 0.30 : 0.265)
    }
}
