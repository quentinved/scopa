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
    /// Mid-stir: the tail swishes, the bird is up, the tortoise has its head out.
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

    /// Both eyes, as beads rather than pinpricks: at this size a plush toy's eyes are half
    /// its face. Wide on a poke unless the animal says otherwise.
    func beads(apart spacing: CGFloat = 0.19, wide: Bool? = nil) -> some View {
        HStack(spacing: size * spacing) {
            eye(wide: wide ?? isPoked)
            eye(wide: wide ?? isPoked)
        }
        .scaleEffect(1.4)
    }
}

// MARK: The cat

/// A plush kitten sat up facing the room, tail up one side, paws together in front.
///
/// Soft ginger rather than the terracotta of the cloth's trim: a toy is a shade paler than
/// the animal. The three stripes on the forehead and the pair of muzzle puffs are what
/// make it a cat and not a bear.
struct CatArt: View {
    private static let fur = Color(red: 0.953, green: 0.667, blue: 0.447)
    private static let furDeep = Color(red: 0.871, green: 0.537, blue: 0.325)
    private static let pink = Color(red: 0.945, green: 0.608, blue: 0.592)

    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            tail
            belly
            paws
            head
        }
        .animation(.spring(duration: 0.45, bounce: 0.45), value: isAwake)
    }

    /// Up the right-hand side from behind, hinged where it leaves the body. Lying along the
    /// table asleep, swishing on a stir, and bolt upright on a poke.
    private var tail: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Self.fur)
            Capsule()
                .fill(Self.furDeep)
                .frame(height: size * 0.12)
        }
        .frame(width: size * 0.12, height: size * (isPoked ? 0.42 : 0.34))
        .rotationEffect(.degrees(tailAngle), anchor: .bottom)
        .offset(x: size * 0.22, y: size * (isPoked ? 0.05 : 0.09))
    }

    private var tailAngle: Double {
        if isPoked { return 8 }
        if stirs { return 34 }
        return isAwake ? 48 : 64
    }

    private var belly: some View {
        ZStack {
            Ellipse()
                .fill(Self.fur)
                .frame(width: size * 0.58, height: size * 0.48)
            Ellipse()
                .fill(Palette.cream.opacity(0.85))
                .frame(width: size * 0.28, height: size * 0.30)
                .offset(y: size * 0.04)
        }
        .offset(y: size * 0.18)
    }

    /// Two cream mittens together at the front, the way a cat sits when it is being good.
    private var paws: some View {
        HStack(spacing: size * 0.02) {
            Ellipse().fill(Palette.cream).frame(width: size * 0.16, height: size * 0.11)
            Ellipse().fill(Palette.cream).frame(width: size * 0.16, height: size * 0.11)
        }
        .offset(y: size * 0.39)
    }

    private var head: some View {
        ZStack {
            ear(at: -1)
            ear(at: 1)
            Circle()
                .fill(Self.fur)
                .frame(width: size * 0.54, height: size * 0.54)
            stripes
            pose.beads().offset(y: -size * 0.03)
            muzzle
        }
        .offset(y: -size * headLift)
    }

    /// Up and a little apart, and flat out sideways on a poke. Only the left one flicks on
    /// a stir: two ears turning together is a rabbit listening.
    private func ear(at side: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Triangle().fill(Self.fur)
            Triangle().fill(Self.pink).frame(width: size * 0.10, height: size * 0.10)
        }
        .frame(width: size * 0.21, height: size * 0.21)
        .rotationEffect(.degrees(Double(side) * earAngle(side)), anchor: .bottom)
        .offset(x: side * size * 0.15, y: -size * 0.20)
    }

    private func earAngle(_ side: CGFloat) -> Double {
        if isPoked { return 62 }
        if stirs, side < 0 { return 34 }
        return 14
    }

    private var stripes: some View {
        HStack(spacing: size * 0.035) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Self.furDeep)
                    .frame(width: size * 0.035, height: size * (index == 1 ? 0.09 : 0.07))
            }
        }
        .offset(y: -size * 0.19)
    }

    /// Two puffs either side of a pink nose, and a mouth under them that opens on a poke.
    private var muzzle: some View {
        ZStack {
            if isPoked {
                Ellipse()
                    .fill(Palette.terracotta.opacity(0.8))
                    .frame(width: size * 0.12, height: size * 0.10)
                    .offset(y: size * 0.07)
            }
            HStack(spacing: 0) {
                Circle().fill(Palette.cream).frame(width: size * 0.085, height: size * 0.075)
                Circle().fill(Palette.cream).frame(width: size * 0.085, height: size * 0.075)
            }
            .offset(y: size * 0.04)
            Triangle()
                .fill(Self.pink)
                .frame(width: size * 0.07, height: size * 0.05)
                .rotationEffect(.degrees(180))
        }
        .offset(y: size * 0.075)
    }

    private var headLift: CGFloat {
        if isPoked { return 0.14 }
        if isAwake { return 0.11 }
        return stirs ? 0.09 : 0.06
    }
}

// MARK: The goldfinch

/// A plush goldfinch, round as a ball and facing the room: black cap, red mask round the
/// bill, and the gold bar on each dark wing, which are the three things that say goldfinch
/// and not sparrow.
struct FinchArt: View {
    private static let breast = Color(red: 0.961, green: 0.925, blue: 0.851)
    private static let flank = Color(red: 0.882, green: 0.788, blue: 0.635)
    private static let red = Color(red: 0.863, green: 0.325, blue: 0.263)
    private static let bill = Color(red: 0.965, green: 0.878, blue: 0.788)
    private static let shank = Color(red: 0.851, green: 0.643, blue: 0.557)

    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            feet
            // Everything above the legs hops, the feet stay on the table.
            ZStack {
                wing(at: -1)
                wing(at: 1)
                belly
                head
            }
            .offset(y: -size * hop)
        }
        .animation(.spring(duration: 0.4, bounce: 0.5), value: isAwake)
    }

    private var hop: CGFloat {
        if isPoked { return 0.12 }
        return stirs ? 0.07 : 0
    }

    private var belly: some View {
        ZStack {
            Ellipse()
                .fill(Self.flank)
                .frame(width: size * 0.56, height: size * 0.48)
            Ellipse()
                .fill(Self.breast)
                .frame(width: size * 0.34, height: size * 0.38)
                .offset(y: size * 0.03)
        }
        .offset(y: size * 0.17)
    }

    /// Dark, with the gold bar, folded to a stub at rest and flung out on a poke.
    private func wing(at side: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(Palette.ink)
            Capsule()
                .fill(Palette.goldLight)
                .frame(width: size * 0.16, height: size * 0.05)
                .offset(y: -size * 0.07)
        }
        .frame(width: size * 0.17, height: size * (isPoked ? 0.32 : 0.27))
        .rotationEffect(.degrees(Double(side) * wingAngle), anchor: .top)
        .offset(x: side * size * (isPoked ? 0.33 : 0.28), y: size * (isPoked ? 0.08 : 0.13))
    }

    private var wingAngle: Double {
        if isPoked { return 80 }
        return stirs ? 40 : 18
    }

    private var head: some View {
        ZStack {
            ZStack {
                Circle().fill(Self.breast)
                // The cap, clipped to the crown.
                Ellipse()
                    .fill(Palette.ink)
                    .frame(width: size * 0.56, height: size * 0.26)
                    .offset(y: -size * 0.20)
                // The mask, which is the whole face of a goldfinch.
                Ellipse()
                    .fill(Self.red)
                    .frame(width: size * 0.36, height: size * 0.28)
                    .offset(y: size * 0.03)
            }
            .frame(width: size * 0.50, height: size * 0.50)
            .clipShape(Circle())
            pose.beads(apart: 0.17).offset(y: -size * 0.04)
            beak
        }
        .offset(y: -size * 0.08)
    }

    /// A short pale cone pointing down, which parts on a poke: the song.
    private var beak: some View {
        ZStack {
            Triangle()
                .fill(Self.bill)
                .frame(width: size * 0.10, height: size * 0.08)
                .rotationEffect(.degrees(180))
                .offset(y: isPoked ? -size * 0.015 : 0)
            if isPoked {
                Triangle()
                    .fill(Self.bill)
                    .frame(width: size * 0.07, height: size * 0.05)
                    .offset(y: size * 0.06)
            }
        }
        .offset(y: size * 0.06)
    }

    /// Two twigs of legs with a splay of toes, which is what says the bird is standing.
    private var feet: some View {
        HStack(spacing: size * 0.10) {
            foot
            foot
        }
        .offset(y: size * 0.43)
    }

    private var foot: some View {
        VStack(spacing: -size * 0.01) {
            Capsule().fill(Self.shank).frame(width: size * 0.035, height: size * 0.07)
            Capsule().fill(Self.shank).frame(width: size * 0.11, height: size * 0.035)
        }
    }
}

// MARK: The hedgehog

/// A plush hedgehog facing the room, its spines fanned behind its head like a collar.
///
/// The spines are drawn the way `BroomMark` draws straw: one capsule per slat, hinged at
/// the middle and fanned. Brown rather than black, because this one is a toy.
struct HedgehogArt: View {
    private static let spine = Color(red: 0.502, green: 0.388, blue: 0.294)
    private static let spineDeep = Color(red: 0.365, green: 0.278, blue: 0.212)
    private static let face = Color(red: 0.965, green: 0.894, blue: 0.773)
    private static let faceDeep = Color(red: 0.902, green: 0.800, blue: 0.651)
    private static let pink = Color(red: 0.945, green: 0.639, blue: 0.620)

    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var isPoked: Bool { pose.isPoked }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            spines
            feet
            belly
            head
        }
        .animation(.spring(duration: 0.5, bounce: 0.5), value: isAwake)
    }

    private var spines: some View {
        ZStack {
            ForEach(0..<17, id: \.self) { index in
                let position = Double(index) / 16 * 2 - 1
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Self.spineDeep : Self.spine)
                    .frame(width: size * 0.10, height: size * spineLength)
                    .offset(y: -size * spineLength / 2)
                    .rotationEffect(.degrees(position * spineSpread))
            }
        }
        .offset(y: size * 0.08)
    }

    /// Longest at the moment of a poke: every spine it owns, at once.
    private var spineLength: CGFloat {
        if isPoked { return 0.50 }
        if isAwake { return 0.42 }
        return stirs ? 0.43 : 0.39
    }

    private var spineSpread: Double {
        if isPoked { return 160 }
        return stirs ? 128 : 116
    }

    private var belly: some View {
        Ellipse()
            .fill(Self.face)
            .frame(width: size * 0.50, height: size * 0.42)
            .offset(y: size * 0.21)
    }

    private var feet: some View {
        HStack(spacing: size * 0.14) {
            Ellipse().fill(Self.faceDeep).frame(width: size * 0.15, height: size * 0.10)
            Ellipse().fill(Self.faceDeep).frame(width: size * 0.15, height: size * 0.10)
        }
        .offset(y: size * 0.41)
    }

    /// Round ears, a pale face and a snout with a button on the end. Poked, it screws the
    /// face up tight and lets the spines do the talking.
    private var head: some View {
        ZStack {
            ear(at: -1)
            ear(at: 1)
            Circle()
                .fill(Self.face)
                .frame(width: size * 0.48, height: size * 0.48)
            // The widow's peak of spines coming down onto the brow.
            Triangle()
                .fill(Self.spine)
                .frame(width: size * 0.18, height: size * 0.10)
                .rotationEffect(.degrees(180))
                .offset(y: -size * 0.19)
            eyes.offset(y: -size * 0.03)
            snout
        }
        .scaleEffect(isPoked ? 0.9 : 1)
        .offset(y: -size * (isAwake || isPoked ? 0.05 : 0.02))
    }

    @ViewBuilder private var eyes: some View {
        if isPoked {
            HStack(spacing: size * 0.20) {
                Capsule().fill(Palette.ink).frame(width: size * 0.10, height: size * 0.03)
                Capsule().fill(Palette.ink).frame(width: size * 0.10, height: size * 0.03)
            }
        } else {
            pose.beads(apart: 0.17)
        }
    }

    private func ear(at side: CGFloat) -> some View {
        ZStack {
            Circle().fill(Self.faceDeep).frame(width: size * 0.14, height: size * 0.14)
            Circle().fill(Self.pink).frame(width: size * 0.07, height: size * 0.07)
        }
        .offset(x: side * size * 0.19, y: -size * 0.18)
    }

    private var snout: some View {
        ZStack {
            Ellipse()
                .fill(Self.faceDeep.opacity(0.6))
                .frame(width: size * 0.18, height: size * 0.11)
            Ellipse()
                .fill(Palette.ink)
                .frame(width: size * 0.08, height: size * 0.06)
                .offset(y: -size * 0.02)
        }
        .offset(y: size * 0.09)
    }
}

// MARK: The tortoise

/// A plush tortoise facing the room: a big head poking out from under a domed shell, and
/// two stubby front feet. The shell is horn rather than green, which is invisible on a
/// green table, and the skin is sage for the same reason.
struct TortoiseArt: View {
    private static let shell = Color(red: 0.827, green: 0.584, blue: 0.318)
    private static let plate = Color(red: 0.929, green: 0.765, blue: 0.494)
    private static let skin = Color(red: 0.706, green: 0.769, blue: 0.482)
    private static let skinDeep = Color(red: 0.588, green: 0.659, blue: 0.376)

    let pose: AnimalPose

    private var size: CGFloat { pose.size }
    private var stirs: Bool { pose.stirs }
    private var isAwake: Bool { pose.isAwake }

    var body: some View {
        ZStack {
            feet
            dome
            hole
            head
        }
        .animation(.spring(duration: 0.6, bounce: 0.3), value: isAwake)
    }

    private var dome: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(Self.shell)
                .frame(width: size * 0.90, height: size * 0.90)
                .scaleEffect(x: 1, y: 1.1, anchor: .center)
                .offset(y: size * 0.225)
            // The plates, in the pale horn the top of a shell actually is.
            ForEach(0..<3, id: \.self) { index in
                let side = CGFloat(index - 1)
                Circle()
                    .fill(Self.plate)
                    .frame(width: size * 0.19, height: size * 0.19)
                    .offset(x: side * size * 0.23, y: side == 0 ? -size * 0.10 : -size * 0.01)
            }
            Capsule()
                .fill(Palette.linenDeep)
                .frame(width: size * 0.94, height: size * 0.08)
                .offset(y: size * 0.225)
        }
    }

    /// The dark under the rim the head goes into. Two pale glints in it while it hides,
    /// so it is plainly still in there, watching.
    private var hole: some View {
        ZStack {
            Ellipse()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: size * 0.30, height: size * 0.10)
            if isHiding {
                HStack(spacing: size * 0.07) {
                    Circle().fill(Palette.cream).frame(width: size * 0.035, height: size * 0.035)
                    Circle().fill(Palette.cream).frame(width: size * 0.035, height: size * 0.035)
                }
            }
        }
        .offset(y: size * 0.27)
    }

    /// The one part of a tortoise with any hurry in it, and only when a finger arrives.
    private var head: some View {
        ZStack {
            Circle()
                .fill(Self.skin)
                .frame(width: size * 0.42, height: size * 0.42)
            pose.beads(apart: 0.15, wide: pose.poke == .settle).offset(y: -size * 0.03)
            Arc(from: 25, to: 155, radius: 0.5)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(y: size * 0.03)
        }
        .scaleEffect(isHiding ? 0.1 : 1, anchor: .bottom)
        .opacity(isHiding ? 0 : 1)
        .offset(y: size * headDrop)
    }

    /// In the shell, and staying there for the length of the poke.
    private var isHiding: Bool { pose.poke == .gather || pose.poke == .spring }

    /// Where the head sits. Furthest out on the way back from a poke, to have a look at
    /// whoever did that.
    private var headDrop: CGFloat {
        switch pose.poke {
        case .gather, .spring: 0.22
        case .settle: 0.05
        case .none: stirs ? 0.08 : isAwake ? 0.10 : 0.13
        }
    }

    private var feet: some View {
        HStack(spacing: size * 0.36) {
            Ellipse().fill(Self.skinDeep).frame(width: size * 0.17, height: size * 0.13)
            Ellipse().fill(Self.skinDeep).frame(width: size * 0.17, height: size * 0.13)
        }
        .offset(y: size * (pose.isPoked ? 0.29 : 0.33))
    }
}

// MARK: The duck

/// Ferdinand: a plush duckling, sat facing the room rather than the cards.
///
/// He set the pattern the others follow: what makes him a duckling is the pair of eyes
/// over a wide flat bill, the tuft, and two enormous feet pointing at you, none of which
/// survives being turned sideways.
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
            pose.beads().offset(y: -size * 0.06)
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
