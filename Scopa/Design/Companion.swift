import ScopaCore
import SwiftUI

/// A small animal on the edge of the table, watching the cards. It takes no part in the
/// game: it cannot be played, cannot be captured and scores nothing.
///
/// Unlike the felt and the deck it travels on the wire beside the seat mark and the
/// cornice, so everyone at the table can see it.
enum Companion: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Nobody, and free.
    case nessuno
    /// A cat, curled by the cards, opening one eye when it is your turn.
    case gatto
    /// A goldfinch on the table edge.
    case cardellino
    /// A hedgehog, spines up.
    case riccio
    /// A tortoise, in no hurry.
    case tartaruga
    /// A duck, sat where the cards fall. The only one here with a name.
    case ferdinando

    static let `default` = Companion.nessuno

    var id: String { rawValue }

    /// Where the phone keeps its owner's choice.
    static let stored = "companion"

    /// What goes on the wire. Nothing when nobody was brought, so a build that knows no
    /// such field reads a player exactly as before.
    var wireValue: String? { self == .nessuno ? nil : rawValue }

    init(_ player: Player) {
        self = player.companion.flatMap(Companion.init(rawValue:)) ?? .nessuno
    }

    var title: String {
        switch self {
        case .nessuno: "Nobody"
        case .gatto: "Gatto"
        case .cardellino: "Cardellino"
        case .riccio: "Riccio"
        case .tartaruga: "Tartaruga"
        case .ferdinando: "Ferdinand"
        }
    }

    /// Written into the ledger with a purchase, so it stays in one language.
    var detail: String {
        switch self {
        case .nessuno: "No one beside the cards"
        case .gatto: "A cat, asleep until it is your turn"
        case .cardellino: "A goldfinch on the table edge"
        case .riccio: "A hedgehog, spines up"
        case .tartaruga: "A tortoise, in no hurry"
        case .ferdinando: "A duck called Ferdinand"
        }
    }

    /// The line under the swatch in the shop. Each says what poking it does, which is the
    /// half of a companion nobody would otherwise find out about before buying.
    var explanation: LocalizedStringKey {
        switch self {
        case .nessuno: "Just you and the cards"
        case .gatto: "Poke it: tail up, ears flat, delighted"
        case .cardellino: "Poke it: hops off the table with a song"
        case .riccio: "Poke it: every spine at once"
        case .tartaruga: "Poke it: gone. Back out once you behave"
        case .ferdinando: "Poke him: wings out, and one enormous quack"
        }
    }

    /// The glyph that pops over its head when a finger lands on it.
    var emote: String? {
        switch self {
        case .nessuno: nil
        case .gatto: "heart.fill"
        case .cardellino: "music.note"
        case .riccio: "exclamationmark"
        case .tartaruga: "zzz"
        case .ferdinando: "quote.bubble.fill"
        }
    }

    /// What the table has the animal doing. Between these it stirs on its own, in short
    /// bursts rather than a forever loop: see `CompanionView.idle`.
    enum Mood: Hashable {
        /// Between turns. Curled, folded, eyes shut.
        case resting
        /// Your turn: it looks up at the cards.
        case watching
        /// You swept the table.
        case delighted
    }
}

/// The animal itself: the timing and the state, with the drawing in `CompanionAnimals`.
///
/// Everything is drawn from circles, capsules and arcs rather than from an image, so it is
/// sharp at any size and there is no asset to ship.
///
/// It can be poked. A finger on it gets a second and a half of animal and then it settles
/// back to whatever the table had it doing. It never touches the game.
struct CompanionView: View {
    let companion: Companion
    var size: CGFloat = 40
    var mood: Companion.Mood = .resting
    /// Whether a finger on the animal pokes it. False on the shop shelf, where the tile it
    /// sits on is a button and a gesture inside it would stop the tile being buyable.
    var interactive: Bool = true

    /// Mid-stir. True for about half a second at a time, false for the seconds between.
    @State private var stirs = false
    /// The double-take some stirs end with, which keeps the idle off a metronome.
    @State private var startles = false
    /// How far a poke has got. `nil` almost always.
    @State private var poke: AnimalPose.Poke? =
        ProcessInfo.processInfo.arguments.contains("-poked") ? .spring : nil
    /// Bumped once per poke. The phone and the speaker follow this rather than the
    /// animation, so a poke feels and sounds like one thing however long it takes to draw.
    @State private var pokes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What the piece drops on the cloth, so the shadow is the table's own colour.
    @Environment(\.tableFelt) private var felt

    /// The moment of the poke everything funny hangs on.
    private var isPoked: Bool { poke == .spring }

    /// How far it lifts when something happens. A hop, not a jump.
    private var lift: CGFloat {
        if let poke {
            switch poke {
            case .gather: return size * 0.05
            case .spring: return hop
            case .settle: return 0
            }
        }
        let base: CGFloat = switch mood {
        case .resting: 0
        case .watching: -size * 0.05
        case .delighted: -size * 0.18
        }
        return startles ? base - size * 0.07 : base
    }

    /// What a poke actually gets off the table. A finch leaves it, a tortoise does not.
    private var hop: CGFloat {
        guard !reduceMotion else { return 0 }
        switch companion {
        case .nessuno: return 0
        case .gatto: return -size * 0.26
        case .cardellino: return -size * 0.12
        case .riccio: return -size * 0.10
        case .tartaruga: return -size * 0.02
        case .ferdinando: return -size * 0.17
        }
    }

    private var lean: Double {
        guard !reduceMotion else { return 0 }
        if let poke {
            guard poke == .spring else { return 0 }
            switch companion {
            case .nessuno: return 0
            case .gatto: return -16
            case .cardellino: return 10
            case .riccio: return -11
            case .tartaruga: return 6
            case .ferdinando: return -9
            }
        }
        let base: Double = switch mood {
        case .resting: 0
        case .watching: -4
        case .delighted: -9
        }
        return startles ? base - 6 : base
    }

    /// Squash going down, stretch coming up, so a poke reads as a living thing.
    private var squash: CGSize {
        guard !reduceMotion else { return CGSize(width: 1, height: 1) }
        switch poke {
        case .gather: return CGSize(width: 1.12, height: 0.86)
        case .spring: return companion == .riccio
            ? CGSize(width: 1.08, height: 1.06)
            : CGSize(width: 0.93, height: 1.11)
        case .settle, .none: return CGSize(width: 1, height: 1)
        }
    }

    private var isAwake: Bool { mood != .resting }

    private var pose: AnimalPose {
        AnimalPose(size: size, poke: poke, stirs: stirs, isAwake: isAwake)
    }

    @ViewBuilder private var animal: some View {
        switch companion {
        case .nessuno: EmptyView()
        case .gatto: CatArt(pose: pose)
        case .cardellino: FinchArt(pose: pose)
        case .riccio: HedgehogArt(pose: pose)
        case .tartaruga: TortoiseArt(pose: pose)
        case .ferdinando: DuckArt(pose: pose)
        }
    }

    var body: some View {
        animal
            .frame(width: size, height: size)
            .scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
            .offset(y: lift)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .animation(.spring(duration: 0.45, bounce: 0.42), value: mood)
            .overlay(alignment: .top) { emote }
            // The animal is a few small shapes with a lot of table between them, so the
            // target is the square it sits in.
            .contentShape(.rect)
            .onTapGesture { poked() }
            // A sweep gets the whole reaction and not just the lift.
            .onChange(of: mood) { _, now in if now == .delighted { cheered() } }
            .allowsHitTesting(interactive && companion != .nessuno)
            .task(id: companion) {
                guard companion != .nessuno, !reduceMotion else { return }
                await idle()
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45), trigger: pokes)
            .accessibilityElement()
            .accessibilityLabel(Text(companion.title))
            .accessibilityHint("Pokes the animal")
            .accessibilityAddTraits(.isButton)
            .accessibilityHidden(!interactive || companion == .nessuno)
    }

    /// What it thinks of having been poked, in one glyph over its head. Drawn above the
    /// frame and untouchable, so a second poke still lands on the animal.
    @ViewBuilder private var emote: some View {
        if let glyph = companion.emote {
            Image(systemName: glyph)
                .font(.system(size: size * 0.30, weight: .heavy))
                .foregroundStyle(Palette.gold)
                .shadow(color: felt.shade(0.45), radius: 1, y: 1)
                .scaleEffect(isPoked ? 1 : 0.3)
                .opacity(isPoked ? 1 : 0)
                .offset(x: size * 0.30, y: isPoked ? -size * 0.52 : -size * 0.18)
                .allowsHitTesting(false)
        }
    }

    // MARK: Being poked

    /// A finger on the animal: the phone says so, the speaker says so, and then it goes off.
    private func poked() {
        guard !ProcessInfo.processInfo.arguments.contains("-poked"), startsReacting() else { return }
        pokes += 1
        Audio.shared.play(.tap)
    }

    /// The same reaction on a sweep, without the tap or the buzz: the table already
    /// shouts and rumbles at a scopa.
    private func cheered() {
        guard !reduceMotion else { return }
        startsReacting()
    }

    /// One reaction at a time. The first beat is set here rather than inside the task, so
    /// a second tap arriving immediately finds the guard already closed.
    @discardableResult private func startsReacting() -> Bool {
        guard poke == nil else { return false }
        withAnimation(.easeOut(duration: 0.12)) { poke = .gather }
        Task { await react() }
        return true
    }

    /// The second and a half: gather, go off, come down, then back to `nil` so nothing is
    /// left running.
    private func react() async {
        try? await Task.sleep(for: .seconds(0.12))
        withAnimation(.spring(duration: 0.42, bounce: 0.55)) { poke = .spring }
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { poke = .settle }
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeOut(duration: 0.25)) { poke = nil }
    }

    /// Stirs now and then for as long as the animal is on screen.
    ///
    /// Bounded animations rather than `repeatForever`, which holds the whole screen
    /// compositing at full frame rate under a dozen surfaces of glass. The wait is
    /// jittered so four animals on one table do not stir in unison.
    private func idle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(.random(in: 3...7)))
            guard !Task.isCancelled else { return }
            // A poke wins: whatever it was about to do waits for the next round.
            guard poke == nil else { continue }
            withAnimation(.easeInOut(duration: 0.45)) { stirs = true }
            try? await Task.sleep(for: .seconds(0.45))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.7)) { stirs = false }
            try? await Task.sleep(for: .seconds(0.7))
            // About one stir in four ends with a second look.
            guard !Task.isCancelled, poke == nil, Bool.random(), Bool.random() else { continue }
            withAnimation(.spring(duration: 0.3, bounce: 0.55)) { startles = true }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { startles = false }
            try? await Task.sleep(for: .seconds(0.45))
        }
    }
}
