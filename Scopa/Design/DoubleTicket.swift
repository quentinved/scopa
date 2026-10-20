import SwiftUI
import ScopaRewards

/// The doubled-winnings mark: the game's own coin with a second one tucked behind it, and
/// "×2" stamped across the pair, so it reads as the same denari twice before a word is read.
struct DoubleMark: View {
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            DenariMark(size: size * 0.7)
                .offset(x: size * 0.14, y: -size * 0.14)
            DenariMark(size: size * 0.7)
                .offset(x: -size * 0.1, y: size * 0.05)
            DoubleStamp(size: size * 0.38)
                .offset(x: size * 0.2, y: size * 0.31)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "×2" in cream on an ink tab, set a little askew like a rubber stamp. Alone, it marks a
/// payout line as the double; on `DoubleMark` it is what the coins are stamped with.
struct DoubleStamp: View {
    var size: CGFloat = 10

    var body: some View {
        Text(verbatim: "×2")
            .font(.display(size))
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, size * 0.3)
            .padding(.vertical, size * 0.02)
            .background(Capsule().fill(Palette.ink))
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }
}

/// A ticket: a rounded card with a half moon bitten from its top and bottom edges where
/// the stub tears off.
struct TicketShape: InsettableShape {
    /// Where the stub tears off, from the leading edge.
    var stub: CGFloat
    var radius: CGFloat = 14
    var notch: CGFloat = 6
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let tear = rect.minX + stub
        let box = rect.insetBy(dx: inset, dy: inset)
        let corner = max(0, radius - inset), bite = notch
        var path = Path()
        path.move(to: CGPoint(x: box.minX + corner, y: box.minY))
        path.addLine(to: CGPoint(x: tear - bite, y: box.minY))
        path.addRelativeArc(center: CGPoint(x: tear, y: box.minY), radius: bite,
                            startAngle: .degrees(180), delta: .degrees(-180))
        path.addArc(tangent1End: CGPoint(x: box.maxX, y: box.minY),
                    tangent2End: CGPoint(x: box.maxX, y: box.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: box.maxX, y: box.maxY),
                    tangent2End: CGPoint(x: box.minX, y: box.maxY), radius: corner)
        path.addLine(to: CGPoint(x: tear + bite, y: box.maxY))
        path.addRelativeArc(center: CGPoint(x: tear, y: box.maxY), radius: bite,
                            startAngle: .degrees(0), delta: .degrees(-180))
        path.addArc(tangent1End: CGPoint(x: box.minX, y: box.maxY),
                    tangent2End: CGPoint(x: box.minX, y: box.minY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: box.minX, y: box.minY),
                    tangent2End: CGPoint(x: box.maxX, y: box.minY), radius: corner)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> TicketShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

/// The dotted line the stub tears along, from one bite to the other.
private struct TicketPerforation: Shape {
    let stub: CGFloat
    let notch: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + stub, y: rect.minY + notch + 3))
            path.addLine(to: CGPoint(x: rect.minX + stub, y: rect.maxY - notch - 3))
        }
    }
}

extension View {
    /// Lays the view on a ticket: the paper, a gold edge and the stub's perforation. The
    /// paper is the caller's, since the felt and the summary's card stock want different ones.
    /// `lifted` lays it on the cloth with a shadow under the paper alone, not its lettering.
    func ticket(stub: CGFloat, paper: Color, edge: Color = Palette.gold, notch: CGFloat = 6,
                lifted: Bool = false) -> some View {
        let shape = TicketShape(stub: stub, notch: notch)
        return background {
            shape.fill(paper)
                .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 5, y: 2)
                .overlay { shape.strokeBorder(edge, lineWidth: 1.2) }
                .overlay {
                    TicketPerforation(stub: stub, notch: notch)
                        .stroke(edge.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 4]))
                }
        }
        .contentShape(shape)
    }
}

/// A run's games as ten coins on the ticket, spent from the right as they are played, with
/// the count of any bought beyond them. The coins drop in once, when it first shows.
struct BoostPips: View {
    let left: Int
    var size: CGFloat = 10

    @State private var shown = false

    var body: some View {
        HStack(spacing: size * 0.35) {
            ForEach(0..<Boost.games, id: \.self) { index in
                pip(filled: shown && index < left)
                    .animation(.spring(duration: 0.3, bounce: 0.45).delay(Double(index) * 0.04),
                               value: shown && index < left)
            }
            if left > Boost.games {
                Text(verbatim: "+\(left - Boost.games)")
                    .font(.system(size: size * 1.15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldDeep)
                    .padding(.leading, size * 0.2)
            }
        }
        .onAppear { shown = true }
        .accessibilityHidden(true)
    }

    private func pip(filled: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(Palette.ink.opacity(0.22), lineWidth: 1)
            DenariMark(size: size)
                .scaleEffect(filled ? 1 : 0.3)
                .opacity(filled ? 1 : 0)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 24) {
        DoubleMark(size: 44)
        HStack { DoubleStamp(); Text(verbatim: "Double winnings") }
        BoostPips(left: 7, size: 12)
        BoostPips(left: 17, size: 12)
        Text(verbatim: "Your next 10 games pay double")
            .padding(.leading, 70).padding(20)
            .ticket(stub: 56, paper: Palette.stock)
    }
    .padding(30)
    .background(TableGround())
}
