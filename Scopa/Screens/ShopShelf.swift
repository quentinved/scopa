import ScopaRewards
import SwiftUI

/// One part of the shop, such as the cards or the table: a plain heading, the line that
/// says what it covers, and its shelves under it.
struct ShopSection<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// The name `-shelf` scrolls to, for a screenshot.
    let anchor: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.gold.opacity(0.22)).frame(height: 1).offset(y: -14)
        }
        .id(anchor)
    }
}

/// The name of a shelf and the line under it saying what buying from it changes.
struct ShelfHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    init(_ kind: ShopItem.Kind) {
        self.title = Cosmetics.title(of: kind)
        self.subtitle = Cosmetics.subtitle(of: kind)
    }

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caption(text: title)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A shelf of one kind of thing: its heading, then a row of swatches that scrolls sideways.
struct ShopShelf<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: Content

    init(_ kind: ShopItem.Kind, @ViewBuilder content: () -> Content) {
        self.title = Cosmetics.title(of: kind)
        self.subtitle = Cosmetics.subtitle(of: kind)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShelfHeading(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy, so a tile off the side of the shelf is neither drawn nor animated.
                LazyHStack(alignment: .top, spacing: 10) { content }
                    .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
}

extension View {
    /// Scrolls to the shelf or section named by `-shelf`, for a screenshot. Inert without the flag.
    func scrollsToDebugShelf() -> some View {
        ScrollViewReader { reader in
            task {
                guard let shelf = DebugLaunch.shelf else { return }
                try? await Task.sleep(for: .milliseconds(400))
                reader.scrollTo(shelf, anchor: .top)
            }
        }
    }

    /// The spring and the click every shelf gives when its equipped item changes.
    func reactsToPick<Value: Equatable>(_ value: Value) -> some View {
        animation(.spring(duration: 0.35, bounce: 0.2), value: value)
            .sensoryFeedback(.selection, trigger: value)
    }
}
