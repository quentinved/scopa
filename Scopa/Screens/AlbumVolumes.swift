import ScopaCore
import ScopaRewards
import SwiftUI

/// One volume on the album's shelf, as the book itself: a cloth cover in the colours of the
/// deck inside, its number and its name, and how far in it is.
///
/// A volume not open yet is still on the shelf, dimmed and locked, because the reason to
/// finish this one is knowing what is behind it.
struct VolumeSpine: View {
    let book: AlbumBook
    let volume: Volume
    /// It is the volume on the page.
    let isShown: Bool
    let width: CGFloat

    var body: some View {
        let isOpen = volume.isOpen(given: book.album(_:))
        let album = book.album(volume)
        VStack(spacing: 6) {
            VolumeCover(volume: volume, width: width)
                .overlay {
                    if isShown {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Palette.goldLight, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .opacity(isOpen ? 1 : 0.55)
            Group {
                if isOpen {
                    Text(verbatim: "\(album.found)/\(Album.size)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(album.isComplete ? Palette.goldLight : Palette.onTable)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(volume.numeral) · \(volume.title)"))
        .accessibilityValue(isOpen
                            ? Text("\(album.found) of \(Album.size) cards found")
                            : Text("Locked"))
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }
}

/// One volume's cover: the cloth of the deck's back, a rule in its trim, the number and the
/// name. Drawn rather than pictured, like everything else in the app.
struct VolumeCover: View {
    let volume: Volume
    var width: CGFloat = 62

    private var height: CGFloat { width * 1.38 }

    var body: some View {
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: width * 0.05, bottomLeadingRadius: width * 0.05,
                                   bottomTrailingRadius: width * 0.11, topTrailingRadius: width * 0.11)
                .fill(volume.cloth)
            // The spine, a shade darker than the board.
            Rectangle()
                .fill(.black.opacity(0.24))
                .frame(width: width * 0.11)
            VStack(spacing: width * 0.05) {
                Text(verbatim: volume.numeral)
                    .font(.system(size: width * 0.26, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(verbatim: volume.title.uppercased())
                    .font(.system(size: width * 0.095, weight: .heavy))
                    .tracking(width * 0.006)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    // Clear of the rule, so PERGAMENA shrinks rather than running into it.
                    .padding(.horizontal, width * 0.05)
                if volume.holdsBack > 0 { lozenges }
            }
            .foregroundStyle(volume.lettering)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.04)
                    .strokeBorder(volume.lettering, lineWidth: max(1, width * 0.016))
            }
            .padding(.leading, width * 0.19)
            .padding([.top, .bottom, .trailing], width * 0.09)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: width * 0.1, y: width * 0.07)
    }

    /// A printer's lozenge under the name for each step the volume holds its good cards
    /// back, the way a binder marks a later printing. The page says what they mean.
    private var lozenges: some View {
        HStack(spacing: width * 0.04) {
            ForEach(0..<volume.holdsBack, id: \.self) { _ in
                Rectangle()
                    .frame(width: width * 0.05, height: width * 0.05)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(height: width * 0.07)
    }
}

/// What a volume after the first pays, shown as the thing itself: the card back on a card,
/// the flourish running, the companion sat there, the song on a plate that plays it, the
/// frame round a badge, the phrases in their bubbles, the cloth under a hand, the lace on a
/// badge, the icon as the home screen shows it. The first volume has its own case, with the
/// marks, in `AlbumPrizes`.
struct VolumePrize: View {
    let volume: Volume
    let album: Album
    /// Whether the volume can be collected yet.
    let isOpen: Bool
    /// Whose initial a badge prize is previewed wearing.
    var name = ""

    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(text: "What this volume pays")
            HStack(spacing: 16) {
                preview
                    .frame(width: 96, height: 104)
                VStack(alignment: .leading, spacing: 5) {
                    status
                    Text(volume.prizeKind)
                        .textCase(.uppercase)
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Palette.onTableSoft)
                    Text(verbatim: volume.prizeTitle)
                        .font(.display(28))
                        .foregroundStyle(volume.lettering)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(volume.prizeLine)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Plus \(volume.theme.style.title) · \(volume.theme.skin.title) to play with")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                        .fixedSize(horizontal: false, vertical: true)
                    if let line = volume.scarcityLine { scarcity(line) }
                    payout(Album.deckBonus, size: 16)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: GlassRadius.panel)
                    .fill(felt.plate())
                    .overlay {
                        RoundedRectangle(cornerRadius: GlassRadius.panel)
                            .strokeBorder(volume.lettering.opacity(0.8), lineWidth: 1.5)
                    }
            }
            if isOpen {
                HStack(spacing: 8) {
                    ForEach(Suit.allCases, id: \.self) { suit in
                        suitPrize(suit)
                    }
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        switch volume.prize {
        case .mark(let mark):
            SeatBadge(name: "", tint: Palette.seat(0), size: 56, mark: mark)
        case .back(let back):
            CardBack(width: 62)
                .environment(\.cardBack, back)
                .environment(\.cardTheme, volume.theme)
                .rotationEffect(.degrees(-6))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        case .flourish(let flourish):
            FlourishSwatch(flourish: flourish, felt: felt)
        case .companion(let companion):
            CompanionView(companion: companion, size: 70, mood: .watching, interactive: false)
        case .song(let song):
            SongPlate(song: song)
        case .cornice(let cornice):
            SeatBadge(name: "", tint: Palette.seat(0), size: 58, cornice: cornice)
        case .phrases(let pack):
            PhrasesSwatch(reactions: pack.reactions)
        case .tapis(let tapis):
            TapisSwatch(tapis: tapis, felt: felt, height: 104)
        case .livery(let livery):
            SeatBadge(name: name, tint: Palette.seat(0), size: 64, livery: livery)
        case .icon:
            ViscontiIconArt(size: 76)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        }
    }

    /// That this volume is the harder one to fill, said the way the album says everything
    /// else: a line, and the cover's lozenges beside it.
    private func scarcity(_ line: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .bold))
            Text(line)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(Palette.goldLight)
    }

    /// Won, how far there is still to go, or which volume opens it.
    @ViewBuilder private var status: some View {
        Group {
            if album.isComplete {
                Label("Yours", systemImage: "checkmark.seal.fill")
            } else if isOpen {
                Label("Still missing: \(Album.size - album.found)", systemImage: "lock.fill")
            } else if let previous = volume.previous {
                Label("Opens after \(previous.title)", systemImage: "lock.fill")
            }
        }
        .font(.system(size: 10.5, weight: .heavy))
        .textCase(.uppercase)
        .tracking(0.8)
        .foregroundStyle(album.isComplete ? Palette.ink : Palette.goldLight)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(album.isComplete ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink.opacity(0.35)))
        }
    }

    /// A suit's ace in this volume's drawing, what finishing the suit pays, and how far in.
    /// Later volumes' suits pay denari only: the four marks belong to the first.
    private func suitPrize(_ suit: Suit) -> some View {
        let have = 10 - album.missing(in: suit).count
        let done = album.isComplete(suit)
        return VStack(spacing: 7) {
            CardView(card: Card(.ace, of: suit), width: 26)
                .environment(\.cardTheme, volume.theme)
                .saturation(done ? 1 : 0.4)
                .frame(height: 40)
            payout(Album.suitBonus, size: 13)
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
        .accessibilityValue(Text(verbatim: "\(have)/10, +\(Album.suitBonus.coins)"))
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

/// A set of phrases as they arrive at the table, small enough to stand in for a prize.
struct PhrasesSwatch: View {
    let reactions: [Reaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(reactions.enumerated()), id: \.offset) { place, reaction in
                SaidLine(reaction: reaction, size: 9.5, tint: Palette.cream)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(.black.opacity(0.26)))
                    .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.3)) }
                    // Staggered, the way they float up beside the table.
                    .offset(x: place.isMultiple(of: 2) ? 0 : 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
