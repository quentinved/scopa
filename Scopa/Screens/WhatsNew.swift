import SwiftUI

/// A version's news, a page at a time: the drawing, the title, a sentence or two.
///
/// Shared by the moment after an update and by Settings, so the pages read the same
/// wherever they are turned.
struct ReleaseNotesPager: View {
    let release: Release
    @Binding var page: Int

    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $page) {
                ForEach(release.notes.indices, id: \.self) { index in
                    ReleaseNotePage(note: release.notes[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageDots(count: release.notes.count, current: page)
        }
    }
}

/// One page: the drawing in a well cut into the cloth, and the words under it.
struct ReleaseNotePage: View {
    let note: ReleaseNote

    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22)
                .fill(felt.shade(0.4))
                .overlay { ReleaseNoteArt(kind: note.art) }
                .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1) }
                .frame(height: 196)
            VStack(spacing: 8) {
                Text(note.title)
                    .font(.display(28))
                    .foregroundStyle(Palette.onTable)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note.body)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

/// Where the pages have got to, in gold.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.goldLight : Palette.onTableSoft.opacity(0.35))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
        .accessibilityHidden(true)
    }
}

/// "What's new", from Settings: the latest version's pages, to turn again.
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        NavigationStack {
            Group {
                if let release = Releases.latestNotes {
                    ReleaseNotesPager(release: release, page: $page)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .navigationTitle(Text("New in \(release.version)"))
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TableGround())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Palette.goldLight)
                }
            }
        }
    }
}

#Preview("What's new") {
    WhatsNewSheet()
}
