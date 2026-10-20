import ScopaCore
import ScopaRewards
import SwiftUI

/// A card a friend sent, turned over: the pack's own stage, one card long.
///
/// It lands face down, gathers the light of its rarity, and goes over with its sparks and,
/// when it was missing, the NEW stamp. A suit or a volume it finished follows. Everything
/// shown is already in the album and the ledger.
struct GiftReveal: View {
    let arrival: GiftArrival
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

    private var opening: AlbumBook.Opening { arrival.opening }
    private var steps: [Step] {
        opening.found.map(Step.card) + opening.suits.map { .finale(.suit($0)) }
            + (opening.deck ? [.finale(.deck)] : [])
    }
    private var step: Step? { steps[safe: place] }
    private var isLast: Bool { place >= steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
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
        .sensoryFeedback(trigger: faceUp) { _, up in up ? Haptic.flip : nil }
        .environment(\.cardTheme, opening.volume.theme)
        .task { show(0, after: .milliseconds(500)) }
        .onDisappear { turning?.cancel() }
    }

    // MARK: Words

    private var header: some View {
        VStack(spacing: 6) {
            Text("A gift from \(arrival.from)")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
            if let card = arrival.card {
                Text("\(arrival.from) sent you the \(card.rank.italianName) of \(Text(card.suit.name))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.onTable)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var footer: some View {
        if isLast, faceUp {
            // A double tap that turned the last card over does not also leave.
            Button { if taps.isOpen { done() } } label: {
                Text("Into the album")
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
                        isNew: found.isNew, rays: 0, width: 168, radius: 168 * 0.09) {
                CardView(card: found.card, width: 168)
                    .shadow(color: felt.shade(0.5), radius: 22, y: 12)
                    .overlay(alignment: .topTrailing) {
                        if found.isNew, faceUp { NewStamp(sound: .purchase).offset(x: 20, y: -14) }
                    }
            } back: {
                CardBack(width: 168).shadow(color: felt.shade(0.5), radius: 22, y: 12)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 8), axis: (x: 1, y: -0.4, z: 0))
            .frame(height: 330)
            VStack(spacing: 10) {
                RarityTag(rarity, locale: locale, size: 12, filled: rarity > .plain)
                GiftFoundLine(found: found)
            }
            .opacity(faceUp ? 1 : 0)
            .offset(y: faceUp ? 0 : 10)
        }
    }

    /// The colour of what is in the middle, behind everything.
    private var wash: some View {
        let tint: Color = switch step {
        case .card(let found) where found.card.rarity > .plain: Rarities.tint(found.card.rarity)
        default: Palette.terracotta
        }
        return RadialGradient(colors: [tint.opacity(faceUp ? 0.2 : 0.12), .clear],
                              center: .center, startRadius: 0, endRadius: 420)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.6), value: faceUp)
    }

    // MARK: Moving it along

    /// A tap turns it over, or brings the next thing once it has landed. Leaving is the
    /// button's alone.
    private func advance() {
        guard taps.isOpen else { return }
        if !faceUp { turnOver() } else if !isLast { show(place + 1) }
    }

    private func show(_ next: Int, after landing: Duration = .zero) {
        turning?.cancel()
        faceUp = false
        taps.moved()
        withAnimation(.spring(duration: 0.42, bounce: 0.22)) { place = next }
        Audio.shared.play(.pick)
        let wait = fanfare(at: next).gathering
        turning = Task {
            try? await Task.sleep(for: landing + wait)
            guard !Task.isCancelled else { return }
            turnOver()
        }
    }

    private func turnOver() {
        guard !faceUp, step != nil else { return }
        turning?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.3)) { faceUp = true }
        taps.turned(reduceMotion: reduceMotion)
        if fanfare(at: place) > .quiet { Audio.shared.play(.shine) }
        switch step {
        case .card(let found) where found.card == .settebello: Audio.shared.play(.settebello)
        case .card(let found) where !found.isNew: Audio.shared.play(.denaro)
        case .card: Audio.shared.play(.play)
        case .finale, nil: Audio.shared.play(.purchase)
        }
    }

    private func fanfare(at index: Int) -> Fanfare {
        switch steps[safe: index] {
        case .card(let found): Fanfare(found.card.rarity)
        case .finale: .crowning
        case nil: .quiet
        }
    }
}

/// New in the album, or a spare and what it paid, as a pack says it.
private struct GiftFoundLine: View {
    let found: Album.Found

    var body: some View {
        switch found {
        case .new:
            Text("New in the album")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Palette.goldLight)
        case .spare(_, let paid):
            HStack(spacing: 6) {
                Text("Already had it").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                DenariMark(size: 14)
                Text(verbatim: "+\(paid.coins)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldLight)
            }
        }
    }
}
