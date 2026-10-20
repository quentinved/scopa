import ScopaRewards
import SwiftUI

/// A foil card at rest: the faint rainbow of foil paper across the face, and gold leaf round
/// the edge. Static, so a page of foils costs a page of cards. The band that moves is
/// `FoilGlare`'s, laid on top only where something is being turned or tilted.
struct FoilSheen: View {
    let radius: CGFloat
    /// How strong the rainbow is: more on a deck that paints its own gold, where the foil's
    /// colours are the only thing that tells it from the plain card.
    var strength: Double = 1

    var body: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.05),
            .init(color: Self.ice.opacity(0.3 * strength), location: 0.3),
            .init(color: Palette.goldLight.opacity(0.36 * strength), location: 0.48),
            .init(color: Self.rose.opacity(0.26 * strength), location: 0.68),
            .init(color: .clear, location: 0.95),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .blendMode(.multiply)
        .clipShape(.rect(cornerRadius: radius))
        .allowsHitTesting(false)
    }

    /// The two colours either side of the gold, the ones a foil card shows as it turns.
    static let ice = Color(red: 0.62, green: 0.84, blue: 1)
    static let rose = Color(red: 1, green: 0.7, blue: 0.8)
}

extension View {
    /// Finishes a card face as a foil when it is one: in Oro, gold laid over the whole face,
    /// the sheen over that, gold leaf round it; in Perla, mother-of-pearl.
    ///
    /// The gold wash came in 1.4. The sheen and the edge alone were lost on the decks that
    /// paint their own gold, Mosaico first: a foil numeral there read as a pale one, and the
    /// plain king beside it looked the more golden of the two.
    func foil(_ isFoil: Bool, in album: FoilAlbum = .oro) -> some View {
        environment(\.foilFace, isFoil ? album : nil)
            .transformEnvironment(\.cardEdge) { edge in if isFoil { edge = .prize(of: album) } }
    }
}

extension EnvironmentValues {
    /// The card is a foil of this album. `CardView` draws the whole finish inside its own
    /// rasterised face: laid over the card from outside, the reveal's tilt turned the gold's
    /// multiply into a flat veil that washed a king out, and a page of them cost more.
    @Entry var foilFace: FoilAlbum? = nil
}

/// A gold foil's face: the paper turned gold and the sheen over it, under the leaf edge.
struct GoldFoilFace: View {
    let width: CGFloat
    /// The deck paints its own face, where the sheen's colours are what tell foil from plain.
    var painted = false

    var body: some View {
        ZStack {
            // Multiplied, so the paper turns gold and the ink stays ink: laid on soft-light
            // at three quarters, it washed a king out to a gold plate.
            RoundedRectangle(cornerRadius: width * 0.12)
                .fill(GoldLeaf.sheet)
                .blendMode(.multiply)
                .opacity(0.42)
            FoilSheen(radius: width * 0.12, strength: painted ? 1.9 : 1)
        }
        .frame(width: width, height: width * 1.5)
        .allowsHitTesting(false)
    }
}

extension Fanfare {
    /// A foil goes over a tier above its card and never below a seven's, since about one
    /// card in twenty-four shines and a foil seven is rarer than the settebello itself.
    init(_ rarity: Rarity, foil: Bool) {
        if foil {
            self = rarity >= .prime ? .crowning : .grand
        } else {
            self.init(rarity)
        }
    }
}

extension FoilAlbum {
    /// A name, and Italian in every language.
    var title: String {
        switch self {
        case .oro: "Oro"
        case .perla: "Perla"
        }
    }

    /// The light its foils turn over in.
    var tint: Color {
        switch self {
        case .oro: Palette.goldLight
        case .perla: Nacre.glow
        }
    }
}
