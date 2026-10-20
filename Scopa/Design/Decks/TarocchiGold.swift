import SwiftUI

/// Gold leaf and what the gilder does to it. The leaf is laid flat in one warm colour; all
/// its life is in the tooling: lines incised with a stylus, punches struck into it.
extension TarocchiPanel {
    /// Leaf over `field`, incised in a lozenge diaper, a punch struck at every crossing and
    /// a ring with a dot at its heart in every lozenge.
    func gild(_ field: Path) {
        context.fill(field, with: .color(Tempera.gold))
        guard fine else { return }
        within(field).diaper(in: field.boundingRect)
    }

    private func diaper(in box: CGRect) {
        let across = w * 0.16, down = w * 0.22
        let centre = CGPoint(x: w / 2, y: w * 0.75)
        context.stroke(lattice(across, down, centre, reach: box.width + box.height),
                       with: .color(Tempera.tool), lineWidth: max(0.3, w * 0.0032))
        var crossings: [CGPoint] = [], hearts: [CGPoint] = []
        let columns = Int(box.width / across) + 1, rows = Int(box.height / down) + 1
        for m in -columns...columns {
            for n in -rows...rows {
                let point = CGPoint(x: centre.x + CGFloat(m) * across / 2, y: centre.y + CGFloat(n) * down / 2)
                guard box.contains(point) else { continue }
                if (m + n).isMultiple(of: 2) { crossings.append(point) } else { hearts.append(point) }
            }
        }
        punch(crossings, radius: w * 0.0085)
        punch(hearts, radius: w * 0.015)
        punch(hearts, radius: w * 0.0085, Tempera.gold)
        punch(hearts, radius: w * 0.0032)
    }

    /// Two families of diagonals through the crossings, so they cut lozenges `across` by `down`.
    private func lattice(_ across: CGFloat, _ down: CGFloat, _ centre: CGPoint, reach: CGFloat) -> Path {
        var lines = Path()
        let slope = down / across
        let count = Int(reach / across) + 1
        for k in -count...count {
            let x = centre.x + CGFloat(k) * across
            for rise in [slope, -slope] {
                lines.move(to: CGPoint(x: x - reach, y: centre.y - rise * reach))
                lines.addLine(to: CGPoint(x: x + reach, y: centre.y + rise * reach))
            }
        }
        return lines
    }

    // MARK: Sgraffito

    /// The settebello's field: vermilion laid over the leaf and scratched back to it in the
    /// ogee lattice of a Milanese velvet, a pomegranate in every ogee.
    func sgraffito(_ field: Path) {
        context.fill(field, with: .color(TarocchiPigment.vermilion.body))
        guard fine else { return }
        let box = field.boundingRect
        let across: CGFloat = 0.20, tall: CGFloat = 0.25
        var lines = Path(), fruit: [CGPoint] = []
        for k in -3...3 {
            let x = 0.5 + CGFloat(k) * across
            // Each column a chain of lenses, the next set half a lens down, so they touch.
            let phase: CGFloat = k.isMultiple(of: 2) ? 0 : .pi / 2
            for side in [1, -1] as [CGFloat] {
                let spine = (0...36).map { step -> (CGFloat, CGFloat) in
                    let y = -0.05 + CGFloat(step) * 0.045
                    return (x + side * across * 0.71 * sin(y / tall * .pi + phase), y)
                }
                lines.addPath(curve(spine))
            }
            var y: CGFloat = k.isMultiple(of: 2) ? tall / 2 : 0
            while y < 1.55 { fruit.append(p(x, y)); y += tall }
        }
        let inside = within(field)
        inside.stroke(lines, Tempera.gold, 0.0055)
        inside.pomegranates(fruit.filter { box.insetBy(dx: -w * 0.03, dy: -w * 0.03).contains($0) })
    }

    /// A small gold pomegranate: a fruit, its crown, and a leaf either side.
    private func pomegranates(_ centres: [CGPoint]) {
        var gold = Path()
        let fruit = Leaf().path(in: CGRect(x: -w * 0.026, y: -w * 0.03, width: w * 0.052, height: w * 0.06))
        let leaf = Leaf().path(in: CGRect(x: -w * 0.009, y: -w * 0.034, width: w * 0.018, height: w * 0.034))
        for c in centres {
            gold.addPath(fruit, transform: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: c.x, ty: c.y))
            for side in [-1, 1] as [CGFloat] {
                gold.addPath(leaf, transform: CGAffineTransform(rotationAngle: side * 1.2)
                    .concatenating(CGAffineTransform(translationX: c.x + side * w * 0.012, y: c.y + w * 0.022)))
            }
            gold.addEllipse(in: CGRect(x: c.x - w * 0.008, y: c.y - w * 0.05, width: w * 0.016, height: w * 0.016))
        }
        context.fill(gold, with: .color(Tempera.gold))
    }
}
