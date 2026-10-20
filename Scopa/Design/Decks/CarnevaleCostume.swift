import SwiftUI

// Masks, hats and cloth for the Carnevale court, each in its own unit rect.

extension Carnevale {
    /// A tricorn from the front: two upturned wings and the point dipping over the brow.
    struct Tricorn: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.00, 0.40))
            p.addQuadCurve(to: at(0.30, 0.10), control: at(0.08, 0.08))
            p.addQuadCurve(to: at(0.70, 0.10), control: at(0.50, -0.08))
            p.addQuadCurve(to: at(1.00, 0.40), control: at(0.92, 0.08))
            p.addQuadCurve(to: at(0.50, 1.00), control: at(0.78, 0.90))
            p.addQuadCurve(to: at(0.00, 0.40), control: at(0.22, 0.90))
            p.closeSubpath()
            return p
        }
    }

    /// The gold braid just inside a tricorn's brim.
    struct TricornBraid: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.07, 0.44))
            p.addQuadCurve(to: at(0.50, 0.86), control: at(0.26, 0.80))
            p.addQuadCurve(to: at(0.93, 0.44), control: at(0.74, 0.80))
            return p
        }
    }

    /// A bauta from the front: domed brow, straight cheeks and the broad jaw that juts out
    /// so the wearer can eat and talk behind it.
    struct Bauta: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.50, 0.00))
            p.addQuadCurve(to: at(0.08, 0.30), control: at(0.10, 0.02))
            p.addQuadCurve(to: at(0.12, 0.62), control: at(0.03, 0.48))
            p.addQuadCurve(to: at(0.02, 1.00), control: at(0.10, 0.82))
            p.addQuadCurve(to: at(0.98, 1.00), control: at(0.50, 0.90))
            p.addQuadCurve(to: at(0.88, 0.62), control: at(0.90, 0.82))
            p.addQuadCurve(to: at(0.92, 0.30), control: at(0.97, 0.48))
            p.addQuadCurve(to: at(0.50, 0.00), control: at(0.90, 0.02))
            p.closeSubpath()
            return p
        }
    }

    /// A colombina: a half mask over the eyes, its outer corners swept up into points.
    struct Colombina: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.50, 0.24))
            p.addQuadCurve(to: at(0.00, 0.00), control: at(0.20, 0.22))
            p.addQuadCurve(to: at(0.10, 0.76), control: at(0.00, 0.46))
            p.addQuadCurve(to: at(0.42, 0.98), control: at(0.20, 1.00))
            p.addQuadCurve(to: at(0.50, 0.72), control: at(0.46, 0.80))
            p.addQuadCurve(to: at(0.58, 0.98), control: at(0.54, 0.80))
            p.addQuadCurve(to: at(0.90, 0.76), control: at(0.80, 1.00))
            p.addQuadCurve(to: at(1.00, 0.00), control: at(1.00, 0.46))
            p.addQuadCurve(to: at(0.50, 0.24), control: at(0.80, 0.22))
            p.closeSubpath()
            return p
        }
    }

    /// A volto: the whole face, smooth and calm, narrowing to the chin.
    struct Volto: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.50, 0.00))
            p.addQuadCurve(to: at(0.04, 0.38), control: at(0.06, 0.02))
            p.addQuadCurve(to: at(0.24, 0.88), control: at(0.04, 0.72))
            p.addQuadCurve(to: at(0.50, 1.00), control: at(0.36, 1.00))
            p.addQuadCurve(to: at(0.76, 0.88), control: at(0.64, 1.00))
            p.addQuadCurve(to: at(0.96, 0.38), control: at(0.96, 0.72))
            p.addQuadCurve(to: at(0.50, 0.00), control: at(0.94, 0.02))
            p.closeSubpath()
            return p
        }
    }

    /// A hood round the head, falling to the shoulders: the black frame behind a mask.
    struct Hood: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.50, 0.00))
            p.addQuadCurve(to: at(0.13, 0.36), control: at(0.13, 0.00))
            p.addQuadCurve(to: at(0.00, 1.00), control: at(0.11, 0.78))
            p.addQuadCurve(to: at(1.00, 1.00), control: at(0.50, 0.88))
            p.addQuadCurve(to: at(0.87, 0.36), control: at(0.89, 0.78))
            p.addQuadCurve(to: at(0.50, 0.00), control: at(0.87, 0.00))
            p.closeSubpath()
            return p
        }
    }

    /// A lace jabot at the throat, three scallops at its foot.
    struct Jabot: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.32, 0.00))
            p.addLine(to: at(0.68, 0.00))
            p.addQuadCurve(to: at(0.94, 0.66), control: at(0.82, 0.28))
            p.addQuadCurve(to: at(0.64, 0.76), control: at(0.82, 1.06))
            p.addQuadCurve(to: at(0.36, 0.76), control: at(0.50, 1.10))
            p.addQuadCurve(to: at(0.06, 0.66), control: at(0.18, 1.06))
            p.addQuadCurve(to: at(0.32, 0.00), control: at(0.18, 0.28))
            p.closeSubpath()
            return p
        }
    }

    /// A broad lace collar over the shoulders: a scalloped half ellipse with a notch for the neck.
    struct LaceCollar: Shape {
        var count: Int

        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            func rim(_ theta: Double, _ reach: CGFloat) -> CGPoint {
                at(0.5 - 0.5 * reach * CGFloat(cos(theta)), reach * CGFloat(sin(theta)))
            }
            var p = Path()
            p.move(to: at(0, 0))
            for index in 0..<count {
                let a0 = Double(index) / Double(count) * .pi
                let a1 = Double(index + 1) / Double(count) * .pi
                p.addQuadCurve(to: rim(a1, 1), control: rim((a0 + a1) / 2, 1.22))
            }
            p.addLine(to: at(0.64, 0))
            p.addQuadCurve(to: at(0.36, 0), control: at(0.50, 0.50))
            p.closeSubpath()
            return p
        }
    }

    /// The holes worked into `LaceCollar`, one under each scallop.
    struct CollarHoles: Shape {
        var count: Int

        func path(in r: CGRect) -> Path {
            var p = Path()
            let d = min(r.width, r.height) * 0.07
            for index in 0..<count {
                let theta = (Double(index) + 0.5) / Double(count) * .pi
                let x = r.minX + r.width * (0.5 - 0.40 * CGFloat(cos(theta)))
                let y = r.minY + r.height * 0.80 * CGFloat(sin(theta))
                p.addEllipse(in: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d))
            }
            return p
        }
    }

    /// The left half of a cape, open down the front. The collar is at the top right corner,
    /// the outer edge falls to the bottom left. Mirror it for the right half.
    struct CapeHalf: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(1.00, 0.00))
            p.addQuadCurve(to: at(0.30, 0.06), control: at(0.62, 0.00))
            p.addQuadCurve(to: at(0.00, 1.00), control: at(0.06, 0.40))
            p.addQuadCurve(to: at(0.62, 0.98), control: at(0.30, 1.03))
            p.addQuadCurve(to: at(0.86, 0.12), control: at(0.66, 0.40))
            p.addQuadCurve(to: at(1.00, 0.00), control: at(0.92, 0.04))
            p.closeSubpath()
            return p
        }
    }

    /// The gold border down the front edge and along the hem of `CapeHalf`.
    struct CapeTrim: Shape {
        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.86, 0.12))
            p.addQuadCurve(to: at(0.62, 0.98), control: at(0.66, 0.40))
            p.addQuadCurve(to: at(0.01, 0.99), control: at(0.30, 1.03))
            return p
        }
    }

    /// A parade horse's caparison, in `HorseArt`'s own unit box: over the back from withers
    /// to croup and hanging in dags just below the belly, short enough to show the legs. `lift` raises the hem, so a lifted
    /// copy drawn over the full one leaves a border.
    struct Caparison: Shape {
        var lift: CGFloat = 0

        func path(in r: CGRect) -> Path {
            let at = Carnevale.unit(r)
            var p = Path()
            p.move(to: at(0.42, 0.28))
            p.addQuadCurve(to: at(0.72, 0.27), control: at(0.58, 0.34))
            p.addQuadCurve(to: at(0.90, 0.33), control: at(0.83, 0.22))
            p.addQuadCurve(to: at(0.91, 0.62 - lift), control: at(0.95, 0.48))
            let dags = 6
            for index in 1...(dags * 2) {
                let x = 0.91 - 0.53 * CGFloat(index) / CGFloat(dags * 2)
                let y = (index.isMultiple(of: 2) ? 0.62 : 0.67) - lift
                p.addLine(to: at(x, y))
            }
            p.addQuadCurve(to: at(0.37, 0.42), control: at(0.34, 0.52))
            p.addQuadCurve(to: at(0.42, 0.28), control: at(0.38, 0.32))
            p.closeSubpath()
            return p
        }
    }
}
