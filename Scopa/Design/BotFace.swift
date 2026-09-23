import SwiftUI
import ScopaCore

/// A tin head in the seat's colour, so a bot is never taken for a person.
struct BotFace: View {
    var tint: Color
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            antenna
            head
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Bot")
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle().fill(Palette.goldLight).frame(width: size * 0.14, height: size * 0.14)
            Rectangle().fill(Palette.cream.opacity(0.8)).frame(width: size * 0.06, height: size * 0.12)
            Spacer(minLength: 0)
        }
        .frame(height: size)
    }

    private var head: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(tint)
            .frame(width: size * 0.82, height: size * 0.68)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .strokeBorder(Palette.cream.opacity(0.35), lineWidth: size * 0.04)
            }
            .overlay { features }
            .offset(y: size * 0.1)
    }

    private var features: some View {
        VStack(spacing: size * 0.09) {
            HStack(spacing: size * 0.16) {
                eye
                eye
            }
            mouth
        }
    }

    /// Three square teeth, which is what reads as a robot rather than a mask.
    private var mouth: some View {
        HStack(spacing: size * 0.04) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: size * 0.02)
                    .fill(Palette.cream.opacity(0.9))
                    .frame(width: size * 0.09, height: size * 0.07)
            }
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: size * 0.05)
            .fill(Palette.cream)
            .frame(width: size * 0.16, height: size * 0.14)
            .overlay {
                Circle().fill(Palette.ink).frame(width: size * 0.07, height: size * 0.07)
            }
    }
}

/// A person's initial, or the machine's face, whichever is sitting there.
struct PlayerBadge: View {
    let name: String
    let isBot: Bool
    var tint: Color
    var size: CGFloat = 36
    var mark: SeatMark = .initial
    /// Finished a recent week's challenge. Never set for a bot.
    var honoured = false
    /// The frame round their mark. Never set for a bot: the machine buys nothing.
    var cornice: Cornice = .none
    /// The colour they play in. Never set for a bot, which keeps the colour of its chair.
    var livery: SeatLivery = .tavolo

    var body: some View {
        if isBot {
            BotFace(tint: tint, size: size)
        } else {
            SeatBadge(name: name, tint: tint, size: size, mark: mark, honoured: honoured,
                      cornice: cornice, livery: livery)
        }
    }
}

/// A small "BOT" tag to sit beside a name.
struct BotTag: View {
    var body: some View {
        Text("BOT")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Palette.goldLight, in: RoundedRectangle(cornerRadius: 4))
    }
}
