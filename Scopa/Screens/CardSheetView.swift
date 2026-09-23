import SwiftUI
import ScopaCore

/// All forty cards in one place, for checking the art. Reached with the `-cardSheet` launch argument.
struct CardSheetView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("THE DECK")
                    .font(.display(44))
                    .foregroundStyle(Palette.onTable)
                ForEach(Suit.allCases, id: \.self) { suit in
                    suitRow(suit)
                }
                HStack(spacing: 16) {
                    CardBack(width: 76)
                    CardBack(width: 40)
                    Caption(text: "Card back")
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
    }

    private func suitRow(_ suit: Suit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SuitMark(suit, size: 16)
                Caption(text: suit.name)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Rank.allCases, id: \.self) { rank in
                        CardView(card: Card(rank, of: suit), width: 76)
                    }
                }
            }
        }
    }
}
