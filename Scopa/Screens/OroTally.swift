import ScopaCore
import ScopaRewards
import SwiftUI

/// What a pack's foils finished in Oro or Perla, among the lines a pack ends on: a suit,
/// which leaves a pack waiting, and the whole album, which finishes every card.
struct OroTally: View {
    let gilt: Gilt

    @Environment(\.locale) private var locale

    private var album: FoilAlbum { gilt.album }

    var body: some View {
        ForEach(gilt.suits, id: \.self) { suit in
            row(Text(verbatim: "\(album.title) · \(OroSuit.name(suit, locale: locale))"),
                note: Text("A \(album.suitPack.title) pack is waiting in the album")) {
                PackArt(tier: album.suitPack, width: 22)
            }
        }
        if gilt.isComplete {
            row(whole, note: prize) { OroTag(size: 9, album: album) }
        }
    }

    private var whole: Text {
        album == .oro ? Text("The whole of Oro") : Text("The whole of Perla")
    }

    private var prize: Text {
        album == .oro ? Text("Bordo d'oro, for every card. Put it on in the shop.")
            : Text("Madreperla, for every card. Put it on in the shop.")
    }

    private func row(_ title: Text, note: Text, @ViewBuilder mark: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(album.tint)
                note
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 8)
            mark()
        }
    }
}

/// A suit's name in the interface's language, as the album prints it.
enum OroSuit {
    static func name(_ suit: Suit, locale: Locale) -> String {
        switch suit {
        case .coins: String(localized: "Coins", locale: locale)
        case .cups: String(localized: "Cups", locale: locale)
        case .swords: String(localized: "Swords", locale: locale)
        case .clubs: String(localized: "Clubs", locale: locale)
        }
    }
}
