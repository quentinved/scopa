import ScopaRewards
import SwiftUI

extension View {
    /// Hangs the house's arrival moment over the lobby: a gift to open and a version's news.
    /// It waits for `isClear` — no sheet, no season, no week, no first-launch walkthrough —
    /// and for the new-league ceremony, which outranks it. `openPacks` takes the player to
    /// where the packs asked for are torn: the album for cards, the shop for its own.
    func releaseMoment(store: TableStore, purse: PurseStore, isClear: Bool,
                       openPacks: @escaping (PackTier.Shelf) -> Void) -> some View {
        modifier(ReleaseMomentHost(store: store, purse: purse, isClear: isClear, openPacks: openPacks))
    }
}

private struct ReleaseMomentHost: ViewModifier {
    let store: TableStore
    let purse: PurseStore
    let isClear: Bool
    let openPacks: (PackTier.Shelf) -> Void

    @State private var desk = ReleaseDesk()
    @Environment(LadderCeremony.self) private var ceremony: LadderCeremony?

    private var canCheck: Bool { isClear && purse.isReady && ceremony?.showing == nil }

    func body(content: Content) -> some View {
        content
            .overlay {
                if let moment = desk.moment {
                    ReleaseMoment(moment: moment, name: store.playerName,
                                  open: { await desk.open(purse: purse, book: store.albumBook) },
                                  close: { close(opening: $0) })
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: desk.moment)
            // A beat after the lobby settles, and after the league ceremony has had its turn
            // to arrive: it asks 1.2 s in.
            .task(id: canCheck) {
                guard canCheck else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                desk.check(paid: purse.purse.keys)
            }
    }

    private func close(opening shelf: PackTier.Shelf?) {
        desk.close()
        if let shelf { openPacks(shelf) }
    }
}

/// The parcel, then the pages. Shown over a dimmed lobby rather than as a sheet, so a gift
/// is not swiped away by accident.
struct ReleaseMoment: View {
    let moment: ReleaseDesk.Moment
    let name: String
    /// Pays the gift. Called once, as the parcel opens.
    let open: () async -> Void
    /// Ends the moment, taking the player to one shelf's packs when asked.
    let close: (_ opening: PackTier.Shelf?) -> Void

    private enum Step { case parcel, notes }

    @State private var step: Step
    @State private var isOpen: Bool
    @State private var page: Int
    @State private var hop = false

    @Environment(\.tableFelt) private var felt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(moment: ReleaseDesk.Moment, name: String, open: @escaping () async -> Void,
         close: @escaping (_ opening: PackTier.Shelf?) -> Void) {
        self.moment = moment
        self.name = name
        self.open = open
        self.close = close
        _step = State(initialValue: moment.gift == nil ? .notes : .parcel)
        _isOpen = State(initialValue: moment.startsOpen)
        _page = State(initialValue: moment.page)
    }

    private var release: Release? { Releases.all.first { $0.version == moment.version } }

    /// Where the parcel's packs are torn, album first: cards in the album, the shop's own
    /// in the shop. Empty when it held none.
    private var doors: [PackTier.Shelf] {
        let packs = moment.gift?.packs ?? []
        return PackTier.Shelf.allCases.filter { shelf in packs.contains { $0.shelf == shelf } }
    }

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.62).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    card
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .task { if moment.startsOpen { await open() } }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 0) {
            switch step {
            case .parcel: parcelStep
            case .notes: notesStep
            }
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background { cardBackground }
        .overlay(alignment: .topTrailing) { closeButton }
        .animation(.spring(duration: 0.5, bounce: 0.2), value: step)
    }

    // MARK: The parcel

    @ViewBuilder private var parcelStep: some View {
        heading(moment.isWelcome ? "Welcome to the table" : "A gift from the house")
        Button(action: unwrap) {
            Parcel(width: 172, isOpen: isOpen, name: name, packs: moment.gift?.packs ?? [])
                .scaleEffect(hop ? 1.04 : 1, anchor: .bottom)
        }
        // Not disabled once open: a disabled button dims what it holds, and this one holds the gift.
        .buttonStyle(.plain)
        .padding(.bottom, 14)
        .task { await nudge() }
        if isOpen { thanks } else { sealedWords }
    }

    private var sealedWords: some View {
        VStack(spacing: 6) {
            Text("Something is waiting for you")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
                .multilineTextAlignment(.center)
            Text("Tap the parcel to open it.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
        }
        .padding(.bottom, 8)
    }

    private var thanks: some View {
        VStack(spacing: 0) {
            Text(verbatim: moment.isWelcome ? "Benvenuto!" : "Grazie!")
                .font(.display(38))
                .foregroundStyle(Palette.onTable)
                .padding(.bottom, 8)
            Group {
                if moment.isWelcome {
                    Text("A few packs to start your album and dress your table. Thank you for sitting down with us.")
                } else {
                    Text("Thank you for playing Scopa. It is kind of you to keep a seat at our table, so the house has put something by for you.")
                }
            }
            .font(.system(size: 14.5))
            .foregroundStyle(Palette.onTableSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 16)
            if let gift = moment.gift { GiftReceipt(gift: gift).padding(.bottom, 20) }
            parcelButtons
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder private var parcelButtons: some View {
        if release != nil {
            primary("See what's new") { step = .notes }
            ForEach(doors, id: \.self) { door in
                secondary(openTitle(door, now: true)) { close(door) }
            }
        } else {
            openButtons(otherwise: "Lovely")
            secondary("Later") { close(nil) }
        }
    }

    /// One button per place the packs wait, the first one filled; `otherwise` when the
    /// parcel held none.
    @ViewBuilder private func openButtons(otherwise: LocalizedStringKey) -> some View {
        if let first = doors.first {
            primary(openTitle(first)) { close(first) }
            ForEach(doors.dropFirst(), id: \.self) { door in
                secondary(openTitle(door)) { close(door) }
            }
        } else {
            primary(otherwise) { close(nil) }
        }
    }

    /// "Open my packs" when they all wait in one place; which ones, when they are split.
    private func openTitle(_ door: PackTier.Shelf, now: Bool = false) -> LocalizedStringKey {
        guard doors.count > 1 else { return now ? "Open my packs now" : "Open my packs" }
        return door == .album ? "Open the card packs" : "Open the shop's packs"
    }

    private func unwrap() {
        guard !isOpen else { return }
        Audio.shared.play(.reveal)
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.9, bounce: 0.3)) {
            isOpen = true
        }
        Task { await open() }
    }

    /// Two small hops while it waits, so it reads as something to take hold of. Not a
    /// loop: a parcel that bounces for ever is a parcel nobody can put down.
    private func nudge() async {
        guard !reduceMotion, !isOpen else { return }
        for _ in 0..<2 {
            try? await Task.sleep(for: .seconds(1.4))
            guard !isOpen, !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.25, bounce: 0.6)) { hop = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { hop = false }
        }
    }

    // MARK: The pages

    @ViewBuilder private var notesStep: some View {
        if let release {
            heading("New in \(release.version)")
            ReleaseNotesPager(release: release, page: $page)
                .frame(height: 390)
                .padding(.bottom, 18)
            let isLast = page >= release.notes.count - 1
            if isLast {
                openButtons(otherwise: "Back to the table")
            } else {
                primary("Next") { withAnimation { page += 1 } }
            }
        }
    }

    // MARK: Pieces

    private func heading(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(Palette.goldLight)
            .padding(.bottom, 14)
    }

    private func primary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { Capsule().fill(Palette.terracotta) }
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var closeButton: some View {
        Button { close(nil) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(width: 30, height: 30)
                .background { Circle().fill(felt.shade(0.5)) }
        }
        .buttonStyle(.plain)
        .padding(14)
        .accessibilityLabel(Text("Close"))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(felt.plate(from: .top, to: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1.5)
            }
            .shadow(color: Palette.ink.opacity(0.4), radius: 30, y: 14)
    }
}

/// What the parcel held, counted: each kind of pack once with how many, and any denari.
private struct GiftReceipt: View {
    let gift: ReleaseGift

    @Environment(\.tableFelt) private var felt

    private var tiers: [(tier: PackTier, count: Int)] {
        PackTier.allCases.compactMap { tier in
            let count = gift.packs.filter { $0 == tier }.count
            return count > 0 ? (tier, count) : nil
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(tiers.indices, id: \.self) { index in chip(tiers[index].tier, count: tiers[index].count) }
                if gift.denari.isCredit {
                    DenariLabel(amount: gift.denari, size: 14, tint: Palette.goldLight, signed: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background { Capsule().fill(felt.shade(0.5)) }
                }
            }
            if let waits {
                Text(waits)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Where the packs wait: one place, or both when the parcel held each kind.
    private var waits: LocalizedStringKey? {
        let shelves = Set(gift.packs.map(\.shelf))
        guard shelves.count < 2 else { return "The card packs wait in the album, the others in the shop" }
        return shelves.first?.waitsIn
    }

    private func chip(_ tier: PackTier, count: Int) -> some View {
        HStack(spacing: 6) {
            PackArt(tier: tier, width: 14)
            Text(verbatim: "\(count) × \(tier.title)")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Palette.onTable)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background { Capsule().fill(felt.shade(0.5)) }
        .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1) }
    }
}
