import SwiftUI

/// Something out of a pack, face down and then face up.
///
/// Face down it gathers itself for as long as its `Fanfare` says: a light the colour of
/// its rarity growing behind it, and from a seven up a tremble that builds and a heartbeat
/// in the hand. Face up it goes over with a lift, throws off a ring and sparks, and a band
/// of foil crosses its face — and keeps catching the light wherever a finger tilts it.
///
/// It only draws. When to turn over is the opening's to decide, so a tap can hurry it.
struct RevealStage<Face: View, Back: View>: View {
    var fanfare: Fanfare
    var tint: Color
    var faceUp: Bool
    /// Missing until now: a few more sparks, in the stamp's colours.
    var isNew = false
    /// Rays behind it once it is up.
    var rays: Int
    /// The face's width and corner, which the light around it is sized from.
    var width: CGFloat
    var radius: CGFloat
    @ViewBuilder var face: Face
    @ViewBuilder var back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date.now
    @State private var tilt: CGSize = .zero
    @State private var beat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: faceUp || reduceMotion)) { timeline in
            let held = progress(at: timeline.date)
            let time = timeline.date.timeIntervalSinceReferenceDate
            Turnover(angle: faceUp ? 0 : 180, front: front, back: trembling(held, time: time))
                .rotation3DEffect(.degrees(Double(tilt.width)), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.height)), axis: (x: 1, y: 0, z: 0))
                .gesture(tilting)
                // Everything round the card is a background: drawn, never laid out. Light
                // wider than the screen in the layout widened the screen, and the table's
                // ground was baked again at the new size for every card.
                .background {
                    ZStack {
                        if faceUp { landed } else { gathering(held, time: time) }
                        // Behind the card, so they burst out from round its edges rather
                        // than falling across its face, where a coin reads as one more pip.
                        if faceUp, fanfare > .quiet || isNew { thrown }
                    }
                }
        }
        .sensoryFeedback(trigger: beat) { _, beat in
            .impact(flexibility: .soft, intensity: min(0.25 + 0.07 * Double(beat), 0.85))
        }
        .task(id: faceUp) { await heartbeat() }
    }

    /// How far through its wait it is, 0 to 1.
    private func progress(at date: Date) -> CGFloat {
        let wait = Double(fanfare.gathering.components.attoseconds) / 1e18
            + Double(fanfare.gathering.components.seconds)
        return CGFloat(min(date.timeIntervalSince(began) / max(wait, 0.01), 1))
    }

    // MARK: Face down

    /// The light behind it while it waits: nothing for a numeral, and from a court up a
    /// glow in its colour that grows and breathes.
    @ViewBuilder private func gathering(_ held: CGFloat, time: TimeInterval) -> some View {
        if fanfare > .quiet {
            let pulse = 1 + 0.06 * sin(time * (6 + 6 * Double(held)))
            RadialGradient(colors: [tint.opacity(0.2 + 0.5 * Double(held)), tint.opacity(0)],
                           center: .center, startRadius: 0, endRadius: width * 1.25)
                .frame(width: width * 2.6, height: width * 2.6)
                .scaleEffect((0.7 + 0.5 * held) * pulse)
                .allowsHitTesting(false)
        }
    }

    /// The back, shaking harder the nearer it is to going over, and from a seven up
    /// letting its colour out round the edges.
    private func trembling(_ held: CGFloat, time: TimeInterval) -> some View {
        let shake = reduceMotion ? 0 : fanfare.tremble * held * held
        let leak = fanfare >= .grand ? Double(held) : 0
        return back
            .shadow(color: tint.opacity(0.9 * leak), radius: 4 + 20 * held)
            .shadow(color: tint.opacity(0.6 * leak), radius: 2)
            .offset(x: shake * sin(time * 55), y: shake * 0.45 * cos(time * 43))
            .rotationEffect(.degrees(Double(shake) * 0.4 * sin(time * 47)))
    }

    /// From a seven up, the hand feels it coming: soft beats, closer and harder.
    private func heartbeat() async {
        guard fanfare >= .grand, !faceUp else { return }
        var gap = 0.34
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(gap))
            guard !Task.isCancelled else { return }
            beat += 1
            gap = max(gap * 0.84, 0.11)
        }
    }

    // MARK: Face up

    private var front: some View {
        face
            .overlay {
                if faceUp {
                    FoilGlare(fanfare: fanfare, tint: tint, glance: tilt.width / 16, radius: radius)
                    LandingFlash(radius: radius, strength: fanfare == .quiet ? 0.45 : 0.95)
                }
            }
    }

    /// The rays, once it is up.
    @ViewBuilder private var landed: some View {
        RarityBurst(count: rays, tint: tint, size: width * 1.95)
    }

    /// What it throws off as it lands: a ring, two from a seven up, and the sparks.
    @ViewBuilder private var thrown: some View {
        Shockwave(tint: fanfare > .quiet ? tint : Palette.cream, size: width * 1.1)
        if fanfare >= .grand {
            Shockwave(tint: .white, size: width * 1.1, delay: 0.12)
        }
        SparkBurst(sparks: fanfare.sparks + (isNew ? 12 : 0), coins: fanfare.coins,
                   palette: sparkColours, force: 360 + 80 * CGFloat(fanfare.rawValue),
                   seed: UInt64(fanfare.rawValue * 97 + (isNew ? 13 : 0)))
    }

    private var sparkColours: [Color] {
        var colours: [Color] = fanfare > .quiet ? [tint, .white, tint] : []
        if fanfare == .crowning { colours += [Palette.goldLight, Palette.cream] }
        if isNew { colours += [Palette.terracotta, Palette.cream] }
        return colours
    }

    /// Tilting it under a finger, which turns the foil to the light. It springs flat when
    /// let go.
    private var tilting: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard faceUp, !reduceMotion else { return }
                tilt = CGSize(width: max(min(value.translation.width / 6, 18), -18),
                              height: max(min(value.translation.height / 6, 14), -14))
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.6, bounce: 0.45)) { tilt = .zero }
            }
    }
}

/// A card going over: the back until it is edge on, then the face. It lifts toward you as
/// it turns, which is what makes it a turn and not a swap.
private struct Turnover<Front: View, Back: View>: View, Animatable {
    /// 180 is face down, 0 face up.
    var angle: Double
    var front: Front
    var back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            // Mirrored, because the whole thing is turned through 180 to show it.
            back.scaleEffect(x: -1).opacity(angle > 90 ? 1 : 0)
            front.opacity(angle > 90 ? 0 : 1)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .scaleEffect(1 + 0.14 * sin(angle * .pi / 180))
    }
}

/// White over a face as it lands, gone in half a second.
private struct LandingFlash: View {
    var radius: CGFloat
    var strength: Double

    @State private var shown = true
    @State private var gone = false

    var body: some View {
        if !gone {
            RoundedRectangle(cornerRadius: radius)
                .fill(.white)
                .opacity(shown ? strength : 0)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5).delay(0.12)) { shown = false } completion: {
                        gone = true
                    }
                }
        }
    }
}

/// The back of something off the shelves: a tile with the house's broom on it, edged in
/// the colour of its grade — which is the tell, the way a card's light is.
struct ShelfBack: View {
    var tint: Color
    var sheen: AnyShapeStyle

    @Environment(\.tableFelt) private var felt

    var body: some View {
        RoundedRectangle(cornerRadius: GlassRadius.panel)
            .fill(felt.shade(0.96))
            .overlay {
                RoundedRectangle(cornerRadius: GlassRadius.panel)
                    .strokeBorder(sheen, lineWidth: 2)
            }
            .overlay { BroomMark(size: 64, tint: tint) }
            .frame(width: 236, height: 214)
    }
}
