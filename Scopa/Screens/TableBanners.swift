import SwiftUI
import ScopaCore

/// A terracotta band across the table for a sweep. It only ever says "Scopa!", with who
/// swept in small type underneath.
struct ScopaBanner: View {
    /// Who swept, or empty when it was you.
    var by: String
    /// What the room does about it, over and around the band. Only your own sweeps carry
    /// one: a flourish is bought on this phone and drawn on this phone.
    var flourish: Flourish = .stendardo

    private let cheer = "Scopa!"

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
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        // Over the band rather than under it: confetti that fell behind the announcement
        // would be a texture, and the point of it is that it is in front of the table.
        .overlay { FlourishView(flourish: flourish) }
        .ignoresSafeArea()
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    /// The slab is given both dimensions and clipped: left to size itself inside a
    /// `GeometryReader` the glass grew to most of the height on offer.
    private func band(width: CGFloat, lettering: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: bandHeight)
            .glass(.riviera(tint: Palette.terracotta), in: .rect(cornerRadius: 10))
            .clipShape(.rect(cornerRadius: 10))
            // Held to the screen width, not the slab's, so `minimumScaleFactor` measures
            // the cheer against something the phone can show.
            .overlay { text.frame(maxWidth: lettering) }
            .shadow(color: Palette.terracotta.opacity(0.35), radius: 30, y: 12)
    }

    private var text: some View {
        HStack(spacing: stage.pick(tall: 18, wide: 14)) {
            BroomMark(size: stage.pick(tall: 52, wide: 34), tint: Palette.cream)
            VStack(alignment: .leading, spacing: -4) {
                Text(cheer.uppercased())
                    .font(.display(displaySize))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Palette.cream)
                Text(by.isEmpty ? "You swept the table" : "\(by) swept the table")
                    .font(.system(size: stage.pick(tall: 14, wide: 12), weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Palette.cream.opacity(0.9))
            }
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
