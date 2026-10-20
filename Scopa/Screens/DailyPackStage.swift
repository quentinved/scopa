import ScopaRewards
import SwiftUI

/// The pack a run of daily deals reached, set down after today's card. Sealed, because it
/// is opened in the album like every other pack: this only says it is there.
struct DailyPackStage: View {
    let tier: PackTier
    /// Set down and lit, rather than still arriving.
    let isUp: Bool

    private var accent: Color { PackLook.accent(tier) }

    var body: some View {
        VStack(spacing: 22) {
            PackArt(tier: tier, width: 150)
                .scaleEffect(isUp ? 1 : 0.86)
                .opacity(isUp ? 1 : 0.7)
                // Drawn behind and never laid out, so the burst cannot widen the screen.
                .background {
                    if isUp {
                        ZStack {
                            Shockwave(tint: accent, size: 170)
                            SparkBurst(sparks: 26, palette: [accent, .white, Palette.goldLight],
                                       force: 380, seed: 29)
                        }
                    }
                }
            VStack(spacing: 8) {
                Text(verbatim: tier.title)
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                Text(PackLook.explanation(tier))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Waiting in the album")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Palette.goldLight)
            }
            .opacity(isUp ? 1 : 0)
            .offset(y: isUp ? 0 : 10)
        }
    }
}
