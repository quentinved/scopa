import ScopaCore
import ScopaRewards
import SwiftUI

/// A suit finished by the pack just opened, or the whole deck: the last thing an opening
/// turns over, and the biggest.
///
/// A finished suit is rarer than the settebello and used to be one line in the tally. Here
/// it is its own beat: the room goes dark, the ten cards fan out of a stack one after
/// another, and when the opening says so the prize comes down on top of them with
/// everything the settebello gets — a mark for the seat in the first volume, the denari in
/// the others.
struct SuitFinale: View {
    enum Kind: Hashable {
        case suit(Suit)
        case deck
    }

    let kind: Kind
    let volume: Volume
    var name: String
    /// The prize has come down. Until then the cards are fanning out under nothing.
    var crowned: Bool
    /// What finishing the deck handed over besides the denari.
    var note: String?

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tableFelt) private var felt
    @State private var fanned = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                fan
                prize
            }
            .frame(height: 330)
            // A background, so the light is drawn and never laid out: wider than the
            // screen in the layout, it widened the screen and the ground was baked again.
            .background {
                if crowned {
                    ZStack {
                        RarityBurst(count: 28, tint: Palette.goldLight, size: 360)
                        SparkBurst(sparks: 44, coins: 20, palette: [Palette.goldLight, .white, Palette.cream],
                                   force: 520, seed: 41)
                        Shockwave(tint: Palette.goldLight, size: 200)
                        Shockwave(tint: .white, size: 200, delay: 0.12)
                    }
                }
            }
            VStack(spacing: 8) {
                Text(verbatim: title)
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                reward
            }
            .opacity(crowned ? 1 : 0)
            .offset(y: crowned ? 0 : 10)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.9, bounce: 0.25)) {
                fanned = true
            }
        }
    }

    // MARK: The cards

    private var cards: [Card] {
        switch kind {
        case .suit(let suit):
            Rank.allCases.map { Card($0, of: suit) }
        case .deck:
            // A hand of the deck's best: the four kings round the four sevens, the
            // settebello in the middle.
            [Card(.king, of: .cups), Card(.king, of: .swords), Card(.seven, of: .cups),
             Card(.seven, of: .swords), .settebello, Card(.seven, of: .clubs),
             Card(.king, of: .clubs), Card(.king, of: .coins)]
        }
    }

    /// The cards out of a stack into a fan, each one a beat behind the one before.
    private var fan: some View {
        let count = cards.count
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                let along = Double(index) - Double(count - 1) / 2
                CardView(card: card, width: 74)
                    .shadow(color: felt.shade(0.45), radius: 6, y: 3)
                    .rotationEffect(.degrees(fanned ? along * 8.5 : 0), anchor: .init(x: 0.5, y: 1.6))
                    .offset(y: fanned ? -18 : 30)
                    .opacity(fanned ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3)
                        .delay(0.06 * Double(index)), value: fanned)
            }
        }
        .offset(y: -20)
    }

    // MARK: The prize

    /// Stamped down on the fan, the way NEW comes down on a card.
    private var prize: some View {
        Group {
            if volume == .riviera {
                SeatBadge(name: name, tint: Palette.seat(0), size: 96, mark: mark)
            } else {
                DenariMark(size: 76)
            }
        }
        .shadow(color: felt.shade(0.6), radius: 14, y: 8)
        .scaleEffect(crowned || reduceMotion ? 1 : 2.4)
        .opacity(crowned ? 1 : 0)
        .offset(y: 92)
        .animation(.spring(duration: 0.4, bounce: 0.45), value: crowned)
    }

    private var mark: SeatMark {
        switch kind {
        case .deck: .settebello
        case .suit(.coins): .coins
        case .suit(.cups): .cups
        case .suit(.swords): .swords
        case .suit(.clubs): .clubs
        }
    }

    // MARK: The words

    private var title: String {
        switch kind {
        case .deck: String(localized: "The whole deck", locale: locale)
        case .suit(let suit): suitName(suit) + " " + String(localized: "complete", locale: locale)
        }
    }

    private var reward: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                DenariMark(size: 16)
                Text(verbatim: "+\((kind == .deck ? Album.deckBonus : Album.suitBonus).coins)")
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.goldLight)
            }
            if let line {
                Text(verbatim: line)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    /// What it paid beyond the denari: only the first volume's suits come with a mark.
    private var line: String? {
        switch kind {
        case .deck: note
        case .suit:
            volume == .riviera
                ? String(localized: "A mark for your seat, in the shop", locale: locale) : nil
        }
    }

    private func suitName(_ suit: Suit) -> String {
        switch suit {
        case .coins: String(localized: "Coins", locale: locale)
        case .cups: String(localized: "Cups", locale: locale)
        case .swords: String(localized: "Swords", locale: locale)
        case .clubs: String(localized: "Clubs", locale: locale)
        }
    }
}
