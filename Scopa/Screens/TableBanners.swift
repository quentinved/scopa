import SwiftUI
import ScopaCore

/// A terracotta band across the table for a sweep. It only ever says "Scopa!", with who
/// swept in small type underneath.
///
/// It is the game's biggest moment and it arrives like one: the band is swept in from the
/// side the way a broom crosses the cloth, the letters drop onto it one after another and
/// bounce, the broom on it swishes, a gleam runs along it and a few sparkles go off round
/// the word. It used to fade in and sit there, which read as a notice rather than a win.
struct ScopaBanner: View {
    /// Who swept, or empty when it was you.
    var by: String
    /// What the room does about it, over and around the band. Only your own sweeps carry
    /// one: a flourish is bought on this phone and drawn on this phone.
    var flourish: Flourish = .stendardo

    private let cheer = "Scopa!"
    /// Long enough for the last letter to settle.
    private static let dropLength: Double = 1.2

    @State private var arrived = false
    /// Seconds since the band arrived, driven linearly so the letters can run their own
    /// springs off it. See `LetterDrop`.
    @State private var elapsed: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.08)
            GeometryReader { proxy in
                // Sized from the diagonal so a tilted band still covers the corners.
                band(width: max(proxy.size.width, proxy.size.height) * 1.4,
                     lettering: proxy.size.width - 40)
                    .rotationEffect(.degrees(stage.pick(tall: -6, wide: -3)))
                    .offset(x: arrived ? 0 : -proxy.size.width * 1.3)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        // Over the band rather than under it: confetti that fell behind the announcement
        // would be a texture, and the point of it is that it is in front of the table.
        .overlay { FlourishView(flourish: flourish) }
        .ignoresSafeArea()
        .transition(.opacity)
        .allowsHitTesting(false)
        .onAppear(perform: arrive)
    }

    private func arrive() {
        guard !reduceMotion else {
            arrived = true
            elapsed = Self.dropLength
            return
        }
        withAnimation(.spring(duration: 0.42, bounce: 0.24)) { arrived = true }
        withAnimation(.linear(duration: Self.dropLength)) { elapsed = Self.dropLength }
    }

    /// The slab is given both dimensions and clipped: left to size itself inside a
    /// `GeometryReader` the glass grew to most of the height on offer.
    private func band(width: CGFloat, lettering: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: bandHeight)
            .glass(.riviera(tint: Palette.terracotta), in: .rect(cornerRadius: 10))
            .overlay { if !reduceMotion { Gleam(delay: 0.32) } }
            .clipShape(.rect(cornerRadius: 10))
            // Held to the screen width, not the slab's, so `minimumScaleFactor` measures
            // the cheer against something the phone can show.
            .overlay { text.frame(maxWidth: lettering) }
            .shadow(color: Palette.terracotta.opacity(0.35), radius: 30, y: 12)
    }

    private var text: some View {
        HStack(spacing: stage.pick(tall: 18, wide: 14)) {
            BroomMark(size: stage.pick(tall: 52, wide: 34), tint: Palette.cream)
                .keyframeAnimator(initialValue: 0.0, trigger: arrived && !reduceMotion) { broom, angle in
                    broom.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    // A swish across and back, then settling upright.
                    KeyframeTrack {
                        CubicKeyframe(-32, duration: 0.16)
                        CubicKeyframe(26, duration: 0.2)
                        SpringKeyframe(-10, duration: 0.18)
                        SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                    }
                }
            VStack(alignment: .leading, spacing: -4) {
                word
                Text(by.isEmpty ? "You swept the table" : "\(by) swept the table")
                    .font(.system(size: stage.pick(tall: 14, wide: 12), weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    // Once the letters are down, not with them.
                    .opacity(arrived ? 1 : 0)
                    .offset(y: arrived ? 0 : 6)
                    .animation(.easeOut(duration: 0.3).delay(reduceMotion ? 0 : 0.45), value: arrived)
            }
            .overlay { if !reduceMotion { Twinkles(trigger: arrived) } }
        }
    }

    @ViewBuilder private var word: some View {
        let lettering = Text(cheer.uppercased())
            .font(.display(displaySize))
        if #available(iOS 18, *) {
            lettering
                .textRenderer(LetterDrop(elapsed: elapsed))
                .modifier(Lettering())
        } else {
            // The whole word at once: per-letter drawing needs iOS 18.
            lettering
                .modifier(Lettering())
                .scaleEffect(arrived ? 1 : 0.4)
                .opacity(arrived ? 1 : 0)
                .animation(.spring(duration: 0.45, bounce: 0.45).delay(0.12), value: arrived)
        }
    }

    private var displaySize: CGFloat {
        let long = cheer.count > 8
        return stage.pick(tall: long ? 62 : 88, wide: long ? 44 : 58)
    }

    private var bandHeight: CGFloat {
        displaySize * 1.2 + stage.pick(tall: 56, wide: 28)
    }
}

/// How the cheer is set, whichever way it arrives.
private struct Lettering: ViewModifier {
    func body(content: Content) -> some View {
        content
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(Palette.cream)
    }
}

/// Drops the letters of a word onto the band one after another, each on its own spring:
/// in from above, turned a little and small, overshooting and settling.
///
/// A renderer rather than a row of letter views, so the word keeps its
/// `minimumScaleFactor` and is still one piece of text to VoiceOver. It is driven by a
/// clock rather than by a spring animation on a flag, because an animated value is only
/// ever interpolated between its two ends; here each letter works out its own curve.
@available(iOS 18, *)
private struct LetterDrop: TextRenderer, Animatable {
    /// Seconds since the band arrived.
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let letters = layout.flatMap { $0 }.flatMap { $0 }
        for (index, letter) in letters.enumerated() {
            let age = elapsed - 0.12 - Double(index) * 0.055
            guard age > 0 else { continue }
            let settled = 1 - exp(-age * 9) * cos(age * 20)
            let bounds = letter.typographicBounds.rect
            let scale = 0.35 + 0.65 * settled
            var copy = context
            copy.opacity = min(age / 0.06, 1)
            copy.translateBy(x: bounds.midX, y: bounds.midY - (1 - settled) * bounds.height * 0.8)
            copy.rotate(by: .degrees((index.isMultiple(of: 2) ? -16 : 16) * (1 - settled)))
            copy.scaleBy(x: scale, y: scale)
            copy.translateBy(x: -bounds.midX, y: -bounds.midY)
            copy.draw(letter)
        }
    }
}

/// A strip of light run once along the band after it lands.
private struct Gleam: View {
    var delay: Double

    @State private var across = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.28), location: 0.45),
                .init(color: .white.opacity(0.5), location: 0.5),
                .init(color: .white.opacity(0.28), location: 0.55),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: width * 0.22)
            .rotationEffect(.degrees(18))
            .offset(x: across ? width : -width * 0.25)
            .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).delay(delay)) { across = true }
        }
    }
}

/// Five small sparkles going off round the word, one after another, once.
private struct Twinkles: View {
    var trigger: Bool

    /// Where each goes off, as a point in the word's own frame, and when.
    private static let spots: [(at: UnitPoint, size: CGFloat, delay: Double)] = [
        (UnitPoint(x: -0.04, y: 0.02), 18, 0.38), (UnitPoint(x: 0.97, y: 0.0), 22, 0.5),
        (UnitPoint(x: 0.62, y: -0.08), 13, 0.62), (UnitPoint(x: 1.06, y: 0.7), 15, 0.74),
        (UnitPoint(x: 0.3, y: 1.02), 12, 0.86),
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Self.spots.indices, id: \.self) { index in
                let spot = Self.spots[index]
                Image(systemName: "sparkle")
                    .font(.system(size: spot.size, weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 2) ? Palette.goldLight : Palette.cream)
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { star, grown in
                        star.scaleEffect(grown).rotationEffect(.degrees(grown * 90)).opacity(min(grown * 2, 1))
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0, duration: spot.delay)
                            SpringKeyframe(1.15, duration: 0.2, spring: .bouncy)
                            CubicKeyframe(1, duration: 0.16)
                            CubicKeyframe(0, duration: 0.4)
                        }
                    }
                    .position(x: spot.at.x * proxy.size.width, y: spot.at.y * proxy.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The seven of coins taken: a gold plate in the middle of the cloth, smaller and shorter
/// than a sweep's banner.
struct SettebelloBanner: View {
    /// Who took it, or empty when it was you.
    var by: String

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    var body: some View {
        HStack(spacing: stage.pick(tall: 14, wide: 12)) {
            CardView(card: .settebello, width: stage.pick(tall: 44, wide: 36))
                .rotationEffect(.degrees(-6))
            VStack(alignment: .leading, spacing: -2) {
                Text(verbatim: "Settebello!")
                    .font(.display(stage.pick(tall: 36, wide: 30)))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(by.isEmpty ? "The seven of coins is yours" : "\(by) takes the seven of coins")
                    .font(.system(size: stage.pick(tall: 13, wide: 12), weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.panel, tint: Palette.gold.opacity(0.92))
        .shadow(color: Palette.goldDeep.opacity(0.45), radius: 24, y: 10)
        .padding(.horizontal, 24)
        .transition(.scale(scale: 0.82).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

/// Three fresh cards each, announced with the same weight as a scopa.
struct DealBanner: View {
    var hand: Int

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                CardBack(width: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("HAND \(hand)")
                        .font(.display(52))
                        .foregroundStyle(Palette.onTable)
                    Text("THREE MORE CARDS")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Palette.goldLight)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
            .glass(.riviera(tint: felt.shade(0.94)), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1.5)
            }
            .rotationEffect(.degrees(-3))
            .shadow(color: felt.shade(0.5), radius: 26, y: 12)
        }
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

/// Hides the cards while the phone changes hands at a shared table, until the next
/// player taps.
struct PassCurtain: View {
    let name: String
    var mark: SeatMark = .initial
    var cornice: Cornice = .none
    var livery: SeatLivery = .tavolo
    let tint: Color
    let done: () -> Void

    var body: some View {
        ZStack {
            TableGround()
            VStack(spacing: 20) {
                SeatBadge(name: name, tint: tint, size: 84, mark: mark, cornice: cornice,
                          livery: livery)
                VStack(spacing: 4) {
                    Text("Pass the phone to")
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Palette.onTableSoft)
                    Text(verbatim: name)
                        .font(.display(48))
                        .foregroundStyle(Palette.onTable)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text("Their cards stay hidden until they tap.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                Button("I have it, show my cards", action: done)
                    .buttonStyle(FilledButtonStyle())
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 380)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }
}
