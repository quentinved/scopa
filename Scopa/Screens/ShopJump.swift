import SwiftUI

/// The parts of the shop, in the order they stand on the page. The raw value is the anchor
/// each section is given, so a chip scrolls to it and `-shelf` reaches it.
enum ShopJump: String, CaseIterable, Identifiable {
    case packs, cards, table, songs, you, sweeps

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .packs: "Packs"
        case .cards: "Cards"
        case .table: "Table"
        case .songs: "Songs"
        case .you: "You"
        case .sweeps: "Scopa"
        }
    }
}

/// A row of chips pinned over the shop, one per section: the page is five screens long,
/// and without it nobody found the songs or the badges at the bottom.
struct ShopJumpBar: View {
    /// The section under the bar, lit so the chip says where you are.
    let current: ShopJump?
    let jump: (ShopJump) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ShopJump.allCases) { section in
                        Button { jump(section) } label: { chip(section) }
                            .buttonStyle(.plain)
                            .id(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .onChange(of: current) { _, section in
                guard let section else { return }
                withAnimation(.snappy) { reader.scrollTo(section, anchor: .center) }
            }
        }
        .animation(.snappy, value: current)
    }

    private func chip(_ section: ShopJump) -> some View {
        let lit = current == section
        return Text(section.title)
            .font(.system(size: 13, weight: lit ? .semibold : .medium))
            .foregroundStyle(lit ? Palette.cream : Palette.onTable)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .glassCapsule(tint: lit ? Palette.terracotta.opacity(0.8) : nil, interactive: true)
    }
}

extension View {
    /// Pins the bar over the top of the page. iOS 26 blurs the page under it as it does under
    /// the navigation bar; before that the bar brings its own material, reaching up behind
    /// the title, since the navigation bar stops drawing one once the chips scroll sideways.
    @ViewBuilder
    func shopJumpBar(_ bar: some View) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0) { bar }
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                bar.background(.bar, ignoresSafeAreaEdges: .top)
            }
        }
    }

    /// Reports whether this section's top has gone up under the bar. A flag rather than the
    /// offset, so the page re-renders when a section is crossed and not on every frame.
    func passesUnderShopBar(_ section: ShopJump, into passed: Binding<Set<ShopJump>>) -> some View {
        onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).minY < 120 } action: { under in
            if under { passed.wrappedValue.insert(section) } else { passed.wrappedValue.remove(section) }
        }
    }
}
