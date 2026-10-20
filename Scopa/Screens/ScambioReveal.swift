import ScopaCore
import ScopaRewards
import SwiftUI

/// The card a trade brought in, turned over the way a pack's are: face down while it gathers
/// the light of its rarity, then up with its sparks and NEW stamped on it. The spares that
/// paid for it sit small above, and fade back once it is up. A suit or a volume it finished
/// follows, as after a pack. Everything shown was already in the album and the ledger.
struct ScambioReveal: View {
    let trade: AlbumBook.Trade
    /// The player's own name, for the mark a finished suit hands over.
    var name = "?"
    let done: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt

    private enum Step: Hashable {
        case card(Album.Found)
        case finale(SuitFinale.Kind)
    }

    @State private var place = 0
    @State private var faceUp = false
    @State private var turning: Task<Void, Never>?
    /// Drops a tap that lands while the card is still going over. See `RevealTaps`.
    @State private var taps = RevealTaps()

    private var opening: AlbumBook.Opening { trade.opening }

    private var steps: [Step] {
        opening.found.map(Step.card) + opening.suits.map { .finale(.suit($0)) }
            + (opening.deck ? [.finale(.deck)] : [])
    }

    private var step: Step? { steps[safe: place] }
    private var isLast: Bool { place >= steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Caption(verbatim: "Scambio")
                ScambioSpareStrip(offer: trade.offer, spent: faceUp || place > 0)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            ZStack { if let step { content(step) } }
                .id(place)
                .transition(.asymmetric(insertion: .scale(scale: 0.74).combined(with: .opacity),
                                        removal: .offset(y: -70).combined(with: .opacity)))
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { wash }
        .background(TableGround())
        .contentShape(.rect)
        .onTapGesture(perform: advance)
        .sensoryFeedback(trigger: faceUp) { _, up in up ? feedback : nil }
        .task { show(0, after: .milliseconds(700)) }
        .onDisappear { turning?.cancel() }
    }

    // MARK: What is in the middle

    @ViewBuilder private func content(_ step: Step) -> some View {
        switch step {
        case .card(let found): cardStage(found)
        case .finale(let kind):
            SuitFinale(kind: kind, volume: opening.volume, name: name, crowned: faceUp,
                       note: kind == .deck ? PackOpening.prizeNote(for: opening.volume, locale: locale) : nil)
        }
    }

    private func cardStage(_ found: Album.Found) -> some View {
        let rarity = found.card.rarity
        return VStack(spacing: 18) {
            RevealStage(fanfare: Fanfare(rarity), tint: Rarities.tint(rarity), faceUp: faceUp,
                        isNew: true, rays: 0, width: 168, radius: 168 * 0.09) {
                CardView(card: found.card, width: 168)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
                    .overlay(alignment: .topTrailing) {
                        if faceUp { NewStamp(sound: .purchase).offset(x: 20, y: -14) }
                    }
            } back: {
                CardBack(width: 168).shadow(color: felt.shade(0.5), radius: 22, y: 12)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
            .frame(height: 330)
            VStack(spacing: 10) {
                RarityTag(rarity, locale: locale, size: 12, filled: rarity > .plain)
                Text("New in the album")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Palette.goldLight)
            }
            .opacity(faceUp ? 1 : 0)
            .offset(y: faceUp ? 0 : 10)
        }
    }

    @ViewBuilder private var footer: some View {
        if isLast, faceUp {
            // A double tap that turned the last card over does not also leave.
            Button { if taps.isOpen { done() } } label: {
                Text("Back to the album")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background { Capsule().fill(Palette.goldSheen) }
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else {
            Text(faceUp ? "Tap for the next one" : "Tap to turn it over")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.onTableSoft.opacity(0.8))
                .frame(height: 50)
        }
    }

    /// The rarity's colour pooled behind everything, a little brighter once it is up.
    private var wash: some View {
        RadialGradient(colors: [Rarities.tint(trade.offer.card.rarity).opacity(faceUp ? 0.2 : 0.12), .clear],
                       center: .center, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.6), value: faceUp)
    }

    // MARK: Moving it along

    /// A tap turns the thing in the middle over, or brings the next one once it has landed.
    /// Leaving is the button's alone.
    private func advance() {
        guard taps.isOpen else { return }
        if !faceUp { turnOver() } else if !isLast { show(place + 1) }
    }

    /// Puts the next thing down face down, and turns it over once it has gathered itself.
    private func show(_ next: Int, after landing: Duration = .zero) {
        turning?.cancel()
        faceUp = false
        taps.moved()
        withAnimation(.spring(duration: 0.42, bounce: 0.22)) { place = next }
        Audio.shared.play(.pick)
        let fanfare = fanfare(at: next)
        turning = Task {
            try? await Task.sleep(for: landing)
            guard !Task.isCancelled else { return }
            if fanfare >= .grand, !reduceMotion { Audio.shared.play(.rise) }
            try? await Task.sleep(for: fanfare.gathering)
            guard !Task.isCancelled else { return }
            turnOver()
        }
    }

    private func turnOver() {
        guard !faceUp, step != nil else { return }
        turning?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.3)) {
            faceUp = true
        }
        taps.turned(reduceMotion: reduceMotion)
        if fanfare(at: place) > .quiet { Audio.shared.play(.shine) }
        if case .card(let found) = step, found.card == .settebello { Audio.shared.play(.settebello) }
    }

    private func fanfare(at index: Int) -> Fanfare {
        switch steps[safe: index] {
        case .card(let found): Fanfare(found.card.rarity)
        case .finale: .crowning
        case nil: .quiet
        }
    }

    private var feedback: SensoryFeedback? {
        switch fanfare(at: place) {
        case .quiet: Haptic.turn
        case .bright: Haptic.flip
        case .grand: Haptic.prize
        case .crowning: Haptic.settebello
        }
    }
}
