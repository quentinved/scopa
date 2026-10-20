import ScopaRewards
import SwiftUI

/// The album's shelf: the volumes, then Oro bound in gold, then Perla in mother-of-pearl.
///
/// Oro is never locked. It fills from the first pack, alongside whichever volume is open.
/// Perla is locked until Oro is full, and can still be opened to see what it pays.
///
/// There are more books than a phone is wide, so the shelf scrolls sideways, out to the
/// edges of the page, and keeps the one on the page in view.
struct AlbumShelf: View {
    let book: AlbumBook
    let shown: Volume
    /// The foil album on the page, or nil for the volume.
    @Binding var foil: FoilAlbum?
    /// The page's side margin, which the shelf runs out through.
    var gutter: CGFloat = 20
    let turn: (Volume) -> Void

    /// A book on the shelf, and the one on the page a size up.
    static let cover: CGFloat = 62
    static let lifted: CGFloat = 70

    private enum Book: Hashable { case volume(Volume), foil(FoilAlbum) }

    private var selected: Book { foil.map(Book.foil) ?? .volume(shown) }

    var body: some View {
        ScrollViewReader { shelf in
            ScrollView(.horizontal) {
                books
                    // Room for the ring round the book on the page, and the covers' shadows.
                    .padding(.vertical, 8)
                    .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .padding(.horizontal, -gutter)
            .onAppear { shelf.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, book in
                withAnimation(.spring(duration: 0.35)) { shelf.scrollTo(book, anchor: .center) }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var books: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Volume.allCases) { volume in
                Button {
                    foil = nil
                    turn(volume)
                } label: {
                    VolumeSpine(book: book, volume: volume, isShown: selected == .volume(volume),
                                width: width(.volume(volume)))
                }
                .buttonStyle(.plain)
                .id(Book.volume(volume))
            }
            ForEach(FoilAlbum.allCases, id: \.self) { album in
                Button { foil = album } label: { spine(album) }
                    .buttonStyle(.plain)
                    .id(Book.foil(album))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: selected)
    }

    private func width(_ book: Book) -> CGFloat {
        book == selected ? Self.lifted : Self.cover
    }

    private func spine(_ album: FoilAlbum) -> some View {
        let pages = book.foils(album)
        let isOpen = album == .oro || book.oro.isComplete
        return VStack(spacing: 6) {
            cover(album)
                .overlay {
                    if foil == album {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(album.tint, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .opacity(isOpen ? 1 : 0.55)
            Group {
                if isOpen {
                    Text(verbatim: "\(pages.found)/\(Album.size)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(pages.isComplete ? album.tint : Palette.onTable)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: album.title))
        .accessibilityValue(isOpen ? Text("\(pages.found) of \(Album.size) foils found") : Text("Locked"))
        .accessibilityAddTraits(foil == album ? .isSelected : [])
    }

    @ViewBuilder private func cover(_ album: FoilAlbum) -> some View {
        switch album {
        case .oro: OroCover(width: width(.foil(album)))
        case .perla: PerlaCover(width: width(.foil(album)))
        }
    }
}

/// Oro's cover: a board laid in gold leaf, its name struck into it in ink.
struct OroCover: View {
    var width: CGFloat = 56

    private var height: CGFloat { width * 1.38 }

    var body: some View {
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: width * 0.05, bottomLeadingRadius: width * 0.05,
                                   bottomTrailingRadius: width * 0.11, topTrailingRadius: width * 0.11)
                .fill(GoldLeaf.board)
            Rectangle()
                .fill(Palette.goldDeep.opacity(0.7))
                .frame(width: width * 0.11)
            Text(verbatim: "ORO")
                .font(.system(size: width * 0.2, weight: .bold, design: .serif))
                .tracking(width * 0.02)
                .foregroundStyle(Palette.ink.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.04)
                        .strokeBorder(Palette.goldDeep.opacity(0.8), lineWidth: max(1, width * 0.016))
                }
                .padding(.leading, width * 0.19)
                .padding([.top, .bottom, .trailing], width * 0.09)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: width * 0.1, y: width * 0.07)
    }
}
