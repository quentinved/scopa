import ScopaRewards
import SwiftUI

/// The line under the album's road: what the stop just reached paid, or what the next one
/// pays and where it is.
struct AlbumRoadLine: View {
    let found: Int
    let paid: AlbumRoadPayout.Paid?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let paid {
                row(paid.prize, reached(paid))
                    .foregroundStyle(Palette.goldLight)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                if paid.isCatchUp {
                    Text("Your album was past \(paid.stop) cards before the road was laid, so that stop pays and the road goes on from there.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let stop = AlbumRoad.next(after: found) {
                row(AlbumRoad.prize(at: stop), ahead(stop))
                    .foregroundStyle(Palette.goldLight.opacity(0.9))
            } else {
                Text("Every stop on the road is paid")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
    }

    private func row(_ prize: AlbumRoad.Prize, _ words: Text) -> some View {
        HStack(spacing: 6) {
            switch prize {
            case .denari: DenariMark(size: 13)
            case .pack: Image(systemName: "gift.fill").font(.system(size: 11, weight: .bold))
            }
            words
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private func reached(_ paid: AlbumRoadPayout.Paid) -> Text {
        switch paid.prize {
        case .denari(let amount): Text("\(paid.stop) cards found: +\(amount.coins) denari")
        case .pack(let tier): Text("\(paid.stop) cards found: a \(tier.title) pack is waiting above")
        }
    }

    private func ahead(_ stop: Int) -> Text {
        switch AlbumRoad.prize(at: stop) {
        case .denari(let amount): Text("+\(amount.coins) at \(stop) cards")
        case .pack(let tier): Text("A \(tier.title) pack at \(stop) cards")
        }
    }
}
