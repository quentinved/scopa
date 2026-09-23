import ScopaCore
import ScopaRewards
import SwiftUI

/// What the album pays, shown as the things themselves rather than described: the mark a
/// full album strikes, at the size and in the metal it will be worn in, and under it the
/// four a full suit hands over.
///
/// For a long time the page said nothing about any of it. A finished suit paid 150 denari
/// and a seat mark, the whole deck 750, and the first anybody heard of it was the pack
/// that happened to finish one — so the one reason to keep opening packs past the first
/// dozen was a secret.
struct AlbumPrizes: View {
    let album: Album
    let name: String
    let livery: SeatLivery

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What the album pays")
                .textCase(.uppercase)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Palette.onTable)
            crown
            HStack(spacing: 8) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    suitPrize(suit)
                }
            }
        }
    }

    // MARK: The whole deck

    /// The top prize, drawn as a trophy in a case: the sovereign badge on a gold bloom, its
    /// name in the display face, and how far there is still to go.
    private var crown: some View {
        let done = album.isComplete
        return HStack(spacing: 18) {
            ZStack {
                // The bloom behind the metal. Breathing, so the case reads as lit rather
                // than printed; it is the one thing on the page that moves on its own.
                Circle()
                    .fill(RadialGradient(colors: [Palette.goldLight.opacity(breathing ? 0.55 : 0.32), .clear],
                                         center: .center, startRadius: 0, endRadius: 72))
                    .frame(width: 144, height: 144)
                SeatBadge(name: name, tint: Palette.seat(0), size: 58, mark: .settebello, livery: livery)
                    .saturation(done ? 1 : 0.55)
                    .scaleEffect(breathing ? 1.03 : 1)
            }
            .frame(width: 104, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                status(done: done)
                Text(verbatim: "Settebello")
                    .font(.display(30))
                    .foregroundStyle(Palette.goldSheen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Every card in the deck, and the rarest mark in the game")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                payout(Album.deckBonus, size: 17)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: GlassRadius.panel)
                .fill(felt.plate())
                .overlay {
                    RoundedRectangle(cornerRadius: GlassRadius.panel)
                        .strokeBorder(LinearGradient(colors: [Palette.goldLight, Palette.gold.opacity(0.4), Palette.goldLight],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: 1.5)
                }
        }
        .shadow(color: Palette.gold.opacity(0.25), radius: 18, y: 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathing = true }
        }
        .accessibilityElement(children: .combine)
    }

    /// Won, or how many cards stand between here and it.
    @ViewBuilder private func status(done: Bool) -> some View {
        Group {
            if done {
                Label("Yours", systemImage: "checkmark.seal.fill")
            } else {
                Label("Still missing: \(Album.size - album.found)", systemImage: "lock.fill")
            }
        }
        .font(.system(size: 10.5, weight: .heavy))
        .textCase(.uppercase)
        .tracking(0.8)
        .foregroundStyle(done ? Palette.ink : Palette.goldLight)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(done ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink.opacity(0.35)))
        }
    }

    // MARK: One suit

    /// A suit's mark, what the suit pays, and how far into it the album is.
    private func suitPrize(_ suit: Suit) -> some View {
        let have = 10 - album.missing(in: suit).count
        let done = album.isComplete(suit)
        return VStack(spacing: 7) {
            SeatBadge(name: name, tint: Palette.seat(0), size: 34, mark: mark(for: suit), livery: livery)
                .saturation(done ? 1 : 0)
                .opacity(done ? 1 : 0.55)
                .frame(height: 44)
            payout(Album.suitBonus, size: 13)
            // Ten pips rather than "7/10": a row with three gaps in it says which way to go.
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .fill(index < have ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(felt.shade(0.55)))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassPanel(radius: GlassRadius.control)
        .overlay(alignment: .topTrailing) {
            if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.goldLight)
                    .padding(6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SeatMark.Requirement.suit(suit).label)
        .accessibilityValue(Text(verbatim: "\(have)/10, +\(Album.suitBonus.coins)"))
    }

    private func mark(for suit: Suit) -> SeatMark {
        switch suit {
        case .coins: .coins
        case .cups: .cups
        case .swords: .swords
        case .clubs: .clubs
        }
    }

    private func payout(_ value: Denari, size: CGFloat) -> some View {
        HStack(spacing: 4) {
            DenariMark(size: size * 0.95)
            Text(verbatim: "+\(value.coins)")
                .font(.system(size: size, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.goldLight)
        }
    }
}
