import ScopaCore
import SwiftUI

/// The wording of each reaction.
///
/// The wire carries only the `Reaction` case, so phones on different builds and in
/// different languages stay compatible. `Reaction.label` stays English for the ledger.
extension Reaction {
    /// The line as it is said. Kept under about sixteen characters to fit a capsule.
    var phrase: LocalizedStringKey {
        switch self {
        case .bravo: "Bravo!"
        case .ouch: "Ahi, that hurt."
        case .thinking: "Let me think…"
        case .laugh: "Ha! Good one."
        case .cheers: "Cin cin."
        case .mamma: "Mamma mia!"
        case .perfetto: "Perfetto."
        case .sleepy: "Any day now…"
        case .fortuna: "Fortuna smiles."
        case .fire: "You're on fire."
        case .respect: "Respect."
        case .no: "Not that one!"
        case .clever: "Very clever."
        case .careful: "Careful now."
        case .taught: "Nonna taught me."
        case .patience: "Patience."
        case .told: "I told you so."
        }
    }
}

/// A reaction's words with its emoji small and after them.
///
/// Shared by the floating bubble, the picker row and the shop so they stay identical.
struct SaidLine: View {
    let reaction: Reaction
    var size: CGFloat = 14
    var tint: Color = Palette.onTable

    var body: some View {
        HStack(spacing: size * 0.42) {
            Text(reaction.phrase)
                .font(.display(size))
                .foregroundStyle(tint)
                .lineLimit(1)
            // Smaller and dimmer than the words so the sentence reads first.
            Text(verbatim: reaction.emoji)
                .font(.system(size: size * 0.72))
                .opacity(0.85)
        }
        .fixedSize()
    }
}
