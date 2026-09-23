import SwiftUI

/// The state an animal is drawn from: how big it is, and where it is in a poke or a stir.
///
/// One value rather than four parameters, so each animal below takes a single input and
/// `CompanionView` keeps the state and the timing.
struct AnimalPose: Equatable {
    /// A poke, in the three beats every animal here takes it in: it gathers, it goes off,
    /// it comes back down. The species differ in what "goes off" means.
    enum Poke { case gather, spring, settle }

    var size: CGFloat
    var poke: Poke?
    /// Mid-stir: the tail is round, the bird is up, the tortoise has its neck out.
    var stirs: Bool
    /// The table has the player's attention, so the animal has its eyes open.
    var isAwake: Bool

    /// The moment of the poke everything funny hangs on.
    var isPoked: Bool { poke == .spring }

    /// Shut is a line, open is a dot, and a poked animal is all pupil.
    @ViewBuilder func eye(wide: Bool = false) -> some View {
        if wide {
            Circle().fill(Palette.ink).frame(width: size * 0.11, height: size * 0.11)
        } else if isAwake {
            Circle().fill(Palette.ink).frame(width: size * 0.06, height: size * 0.06)
        } else {
            Capsule().fill(Palette.ink).frame(width: size * 0.09, height: size * 0.025)
        }
    }
}

// MARK: The cat

/// Curled, tail round the front, head to the left where the cards are. The tail is a
/// stroked arc, which is what a cat's tail looks like from across a table.
struct CatArt: View {
    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }

    var body: some View {
        ZStack {
            tail
            Ellipse()
                .fill(Palette.terracotta)
                .frame(width: size * 0.72, height: size * 0.46)
                .offset(y: size * 0.16)
            head
        }
    }

    /// The only thing on a curled cat that moves: it sweeps once round the body and comes
    /// back. Poked, it goes the other way and doubles in thickness.
    private var tail: some View {
        Arc(from: 200, to: 20, radius: 0.30)
            .stroke(Palette.terracotta,
                    style: StrokeStyle(lineWidth: size * (isPoked ? 0.17 : 0.10), lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isPoked ? -78 : stirs ? -30 : 0), anchor: .bottomLeading)
            .offset(x: size * 0.20, y: size * 0.12)
    }

    private var head: some View {
        ZStack {
            ear(at: -1)
            ear(at: 1)
            Circle()
                .fill(Palette.terracotta)
                .frame(width: size * 0.42, height: size * 0.42)
            HStack(spacing: size * 0.10) {
                pose.eye(wide: isPoked)
                pose.eye(wide: isPoked)
            }
            .offset(y: -size * 0.02)
            // The muzzle, which is the difference between a cat and a brown circle. It
            // opens when the cat is poked.
            Ellipse()
                .fill(Palette.cream.opacity(0.85))
                .frame(width: size * (isPoked ? 0.11 : 0.14), height: size * (isPoked ? 0.11 : 0.09))
                .offset(y: size * 0.10)
        }
        .offset(x: -size * 0.18, y: -size * 0.04)
    }

    /// Only the far ear twitches with the tail: two ears turning together is a rabbit
    /// listening. Poked, both lie flat the same way, because two standing apart are horns.
    private func ear(at side: CGFloat) -> some View {
        Triangle()
            .fill(Palette.terracotta)
            .frame(width: size * 0.20, height: size * 0.19)
            .rotationEffect(.degrees(isPoked ? 68 : side < 0 && stirs ? -34 : 0), anchor: .bottom)
            .offset(x: side * size * 0.15, y: -size * 0.21)
    }
}

// MARK: The goldfinch

/// A songbird perched, facing left at the cards.
///
/// The head overlaps the body so the two read as one teardrop leaning forward, and the
/// tail is long and angled down and back. Without either it draws as a duck.
struct FinchArt: View {
    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }

    var body: some View {
        ZStack {
            // Everything above the legs hops, the feet stay on the table.
            ZStack {
                tail
                // The body, leaning forward the way a perched bird does.
                Ellipse()
                    .fill(Palette.linen)
                    .frame(width: size * 0.38, height: size * 0.46)
                    .rotationEffect(.degrees(28))
                    .offset(x: size * 0.03, y: size * 0.08)
                wing
                head
            }
            .offset(y: isPoked ? -size * 0.24 : stirs ? -size * 0.20 : 0)
            feet
        }
    }

    /// Long, angled down and back, in two feathers so it forks. The fork opens on a poke.
    private var tail: some View {
        ZStack {
            Capsule()
                .fill(Palette.ink)
                .frame(width: size * 0.09, height: size * 0.34)
                .rotationEffect(.degrees(isPoked ? -52 : -34))
            Capsule()
                .fill(Palette.inkSoft)
                .frame(width: size * 0.08, height: size * 0.30)
                .rotationEffect(.degrees(isPoked ? -6 : -20))
        }
        .offset(x: size * 0.19, y: size * 0.24)
    }

    /// The folded wing, with the gold bar along its lower edge. A hairline rather than a
    /// blaze: a bright yellow shape on a pale breast reads as an open bill. It unfolds on
    /// a poke, which is when the bar shows.
    private var wing: some View {
        ZStack {
            Ellipse()
                .fill(Palette.linenDeep)
                .frame(width: size * 0.17, height: size * (isPoked ? 0.36 : 0.28))
            Capsule()
                .fill(Palette.gold)
                .frame(width: size * 0.045, height: size * (isPoked ? 0.26 : 0.19))
                .offset(x: size * 0.05, y: size * 0.02)
        }
        .rotationEffect(.degrees(isPoked ? -20 : 26))
        .offset(x: size * (isPoked ? 0.11 : 0.06), y: size * (isPoked ? 0.02 : 0.10))
    }

    /// Head, black cap, red face and beak, set into the shoulder rather than above it.
    private var head: some View {
        ZStack {
            Circle()
                .fill(Palette.ink)
                .frame(width: size * 0.30, height: size * 0.30)
            Circle()
                .fill(Palette.terracotta)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.035, y: size * 0.035)
            pose.eye(wide: isPoked).offset(x: -size * 0.05, y: -size * 0.01)
            // A short cone on the front of the face, tipped up when it has something to
            // sing about.
            Triangle()
                .fill(Palette.goldDeep)
                .frame(width: size * 0.085, height: size * 0.12)
                .rotationEffect(.degrees(isPoked ? -118 : -96))
                .offset(x: -size * 0.17, y: size * (isPoked ? 0.01 : 0.04))
        }
        .offset(x: -size * 0.11, y: -size * 0.13)
    }

    /// Two twigs of legs, which is what says the bird is standing on something.
    private var feet: some View {
        HStack(spacing: size * 0.07) {
            Capsule().fill(Palette.goldDeep).frame(width: size * 0.03, height: size * 0.09)
            Capsule().fill(Palette.goldDeep).frame(width: size * 0.03, height: size * 0.09)
        }
        .offset(x: -size * 0.01, y: size * 0.31)
    }
}

// MARK: The hedgehog

/// Spines drawn the way `BroomMark` draws straw: one capsule per slat, hinged at the body
/// and fanned. Seventeen of them, and dark, because a sparse pale fan reads as a mouse.
struct HedgehogArt: View {
    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            spines
            // The body under them, only just showing: a dome, not an ellipse sticking out
            // from under a fringe.
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(Palette.inkSoft)
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(y: size * 0.17)
            snout
        }
        .animation(.spring(duration: 0.5, bounce: 0.5), value: isAwake)
    }

    private var spines: some View {
        ZStack {
            ForEach(0..<17, id: \.self) { index in
                let position = Double(index) / 16 * 2 - 1
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Palette.ink : Palette.inkSoft)
                    .frame(width: size * 0.065, height: size * spineLength)
                    .offset(y: -size * 0.09)
                    .rotationEffect(.degrees(position * spineSpread), anchor: .bottom)
            }
        }
        .offset(y: size * 0.14)
    }

    /// The one pale thing on it, and the part that goes away when it balls up.
    private var snout: some View {
        ZStack {
            Ellipse()
                .fill(Palette.linen)
                .frame(width: size * 0.30, height: size * 0.19)
            Circle()
                .fill(Palette.ink)
                .frame(width: size * 0.075, height: size * 0.075)
                .offset(x: -size * 0.11)
            pose.eye(wide: false).offset(x: size * 0.03, y: -size * 0.03)
        }
        .scaleEffect(isPoked ? 0.4 : 1, anchor: .trailing)
        .opacity(isPoked ? 0 : 1)
        .offset(x: -size * (isPoked ? 0.12 : 0.26), y: size * 0.17)
    }

    /// Longest at the moment of a poke: every spine it owns, at once.
    private var spineLength: CGFloat {
        if isPoked { return 0.56 }
        if isAwake { return 0.44 }
        return stirs ? 0.45 : 0.38
    }

    private var spineSpread: Double {
        if isPoked { return 98 }
        return stirs ? 88 : 76
    }
}

// MARK: The tortoise

/// The shell is horn rather than green, which is invisible on a green table. A real
/// tortoise is amber anyway: it is the head and feet that are olive.
struct TortoiseArt: View {
    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            HStack(spacing: size * 0.26) {
                foot
                foot
            }
            .offset(y: size * (pose.isPoked ? 0.19 : 0.24))
            shell
            neck
        }
        .animation(.spring(duration: 0.6, bounce: 0.3), value: isAwake)
    }

    private var shell: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(Palette.goldDeep)
                .frame(width: size * 0.72, height: size * 0.72)
            // Three plates, in the pale horn the rim of a shell actually is.
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Palette.linen.opacity(0.85), lineWidth: size * 0.028)
                    .frame(width: size * 0.17, height: size * 0.17)
                    .offset(x: CGFloat(index - 1) * size * 0.19, y: -size * 0.10)
            }
            // The rim along the bottom of the shell.
            Capsule()
                .fill(Palette.linenDeep)
                .frame(width: size * 0.72, height: size * 0.06)
                .offset(y: -size * 0.01)
        }
        .offset(y: size * 0.18)
    }

    /// The one part of a tortoise with any hurry in it, and only when a finger arrives.
    private var neck: some View {
        ZStack {
            Capsule()
                .fill(Palette.tableLight)
                .frame(width: size * 0.30, height: size * 0.19)
            pose.eye(wide: pose.poke == .settle).offset(x: -size * 0.05, y: -size * 0.02)
        }
        .scaleEffect(x: isHiding ? 0.05 : 1, anchor: .trailing)
        .offset(x: -size * neckReach, y: size * (isAwake || pose.poke != nil ? 0.09 : 0.17))
    }

    /// In the shell, and staying there for the length of the poke.
    private var isHiding: Bool { pose.poke == .gather || pose.poke == .spring }

    /// How far the neck is out. Furthest on the way back from a poke, to have a look at
    /// whoever did that.
    private var neckReach: CGFloat {
        switch pose.poke {
        case .gather, .spring: 0.18
        case .settle: 0.50
        case .none: stirs ? 0.46 : 0.32
        }
    }

    private var foot: some View {
        Capsule()
            .fill(Palette.green)
            .frame(width: size * 0.16, height: size * 0.10)
    }
}

// MARK: The duck

/// Ferdinand: a plush duckling, sat facing the room rather than the cards.
///
/// Every other companion is a side view looking left at the table, because a cat or a
/// tortoise from the front is a shape with no animal in it. A duckling is the opposite:
/// what makes him a duckling is the pair of eyes over a wide flat bill, the tuft, and two
/// enormous feet pointing at you, none of which survives being turned sideways.
///
/// Toy proportions throughout: the head is nearly as wide as the body and sits low on it,
/// with no neck between them. Everything is a circle or a capsule except the bill.
struct DuckArt: View {
    let pose: AnimalPose

    /// Plush yellow, and the two oranges of felt bill and felt feet. Kept here rather than
    /// in `Palette`: this is one toy's colouring, not a colour the table uses.
    private static let down = Color(red: 0.973, green: 0.867, blue: 0.353)
    private static let downDeep = Color(red: 0.898, green: 0.773, blue: 0.278)
    private static let webbing = Color(red: 0.965, green: 0.749, blue: 0.459)
    private static let webbingDeep = Color(red: 0.902, green: 0.639, blue: 0.353)

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            feet
            ZStack {
                wing(at: -1)
                wing(at: 1)
                belly
                head
            }
            // The toy lifts off his feet when he goes off, which is the whole of him
            // except the two orange paddles.
            .offset(y: isPoked ? -size * 0.04 : 0)
        }
        .animation(.spring(duration: 0.45, bounce: 0.45), value: isAwake)
    }

    /// Wider at the bottom than the top, the way a soft toy sits down.
    private var belly: some View {
        ZStack {
            Ellipse()
                .fill(Self.down)
                .frame(width: size * 0.64, height: size * 0.50)
            // The seam of paler down up the middle of the breast.
            Ellipse()
                .fill(Palette.cream.opacity(0.22))
                .frame(width: size * 0.30, height: size * 0.32)
                .offset(y: -size * 0.03)
        }
        .offset(y: size * 0.16)
    }

    /// A stub of a wing on each side, held in while he is settled and out when he is not.
    /// They are behind the body, so only the round end of each shows.
    private func wing(at side: CGFloat) -> some View {
        Capsule()
            .fill(Self.downDeep)
            .frame(width: size * 0.19, height: size * (isPoked ? 0.34 : 0.28))
            // Out clear of the body when he goes off, and no further in than the round end
            // the rest of the time: a stub either side is a wing folded, the same shape
            // swung out is a wing. Anything in between is a lump.
            .rotationEffect(.degrees(Double(side) * (isPoked ? 76 : stirs ? 26 : 14)), anchor: .top)
            .offset(x: side * size * (isPoked ? 0.36 : 0.27), y: size * (isPoked ? 0.10 : 0.14))
    }

    /// Head, tuft, eyes and bill. As wide as the body and sat straight on it.
    private var head: some View {
        ZStack {
            tuft
            Circle()
                .fill(Self.down)
                .frame(width: size * 0.54, height: size * 0.54)
            // Beads rather than pinpricks: at this size a plush toy's eyes are half the
            // face. The shared eye is drawn small for animals seen from the side.
            HStack(spacing: size * 0.19) {
                pose.eye(wide: isPoked)
                pose.eye(wide: isPoked)
            }
            .scaleEffect(1.4)
            .offset(y: -size * 0.06)
            bill
        }
        .offset(y: -size * headLift)
    }

    /// The sprig of fluff off the top of his head, which is the one thing on a plush duck
    /// nobody draws and everybody remembers. Three strands, and they part when he is poked.
    private var tuft: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let lean = Double(index - 1)
                Capsule()
                    .fill(Self.down)
                    .frame(width: size * 0.06, height: size * (isPoked ? 0.22 : 0.18))
                    .rotationEffect(.degrees(lean * (isPoked ? 36 : 22)), anchor: .bottom)
            }
        }
        .offset(y: -size * (isPoked ? 0.33 : 0.30))
    }

    /// Wide, soft and slightly wider than it is deep, with the seam across it that a sewn
    /// bill has. It opens on a poke: the lower half drops and there is a mouth behind it.
    private var bill: some View {
        ZStack {
            if isPoked {
                Ellipse()
                    .fill(Palette.terracotta.opacity(0.75))
                    .frame(width: size * 0.20, height: size * 0.13)
                    .offset(y: size * 0.04)
            }
            RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                .fill(Self.webbing)
                .frame(width: size * 0.29, height: size * 0.11)
                .rotationEffect(.degrees(isPoked ? -7 : 0), anchor: .center)
                .offset(y: isPoked ? -size * 0.02 : 0)
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(Self.webbingDeep)
                .frame(width: size * 0.25, height: size * 0.055)
                .offset(y: size * (isPoked ? 0.09 : 0.045))
        }
        .offset(y: size * 0.06)
    }

    /// Two paddles pointing at whoever is looking. They stay on the table while the rest
    /// of him hops, which is what makes the hop funny rather than a whole toy moving.
    private var feet: some View {
        HStack(spacing: size * 0.09) {
            foot(at: -1)
            foot(at: 1)
        }
        .offset(y: size * 0.375)
    }

    private func foot(at side: CGFloat) -> some View {
        Ellipse()
            .fill(Self.webbing)
            .frame(width: size * 0.27, height: size * 0.16)
            .rotationEffect(.degrees(Double(side) * 11))
    }

    /// Sunk into his own breast while nothing is happening, and up when it is your turn.
    private var headLift: CGFloat {
        if isPoked { return 0.14 }
        if isAwake { return 0.11 }
        return stirs ? 0.09 : 0.06
    }
}

// MARK: Shapes

/// A plain triangle pointing up. Ears, beaks and tails, all of them.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A slice of a circle, in degrees clockwise from three o'clock, at a radius given as a
/// fraction of the frame. A tail.
private struct Arc: Shape {
    var from: Double
    var to: Double
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: rect.width * radius,
                    startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
        return path
    }
}
