import SwiftUI
import ScopaCore
import ScopaRewards

/// The solo campaign: a road through Italy, region by region, a table at every stop.
///
/// Takes nothing at init: the table and the purse come down the environment from
/// `ContentView`. Opened from the lobby, and again on the walk back from a campaign game,
/// when the stars just won are struck and the next table's road is drawn in, once.
struct CampaignView: View {
    @Environment(TableStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: CampaignStage?
    @State private var moment = CampaignMoment()
    /// The region whose last table was just won, for its prize card.
    @State private var prize: CampaignRegion?
    /// The sheet across, which the map's grounds fill.
    @State private var span: CGFloat = 0

    private var book: CampaignBook { store.campaignBook }
    /// A phone's width, centred on an iPad.
    private static let maxWidth: CGFloat = 560
    /// The column the road is laid in.
    private var width: CGFloat { min(span, Self.maxWidth) }

    var body: some View {
        ScrollViewReader { proxy in
            SheetScaffold(title: "Campaign", subtitle: "Thirty tables across Italy. Win one to open the road to the next.",
                          close: close, bleeds: true) {
                content(proxy)
            } bottom: {
                card(proxy)
            }
            .overlay { prizeOverlay }
            .animation(.spring(duration: 0.45, bounce: 0.2), value: prize)
            .task { await walkBack(proxy) }
        }
    }

    /// The map is the sheet's surface, edge to edge: no card laid on the cloth, so nothing
    /// square sits inside the sheet's rounded corners. The tally stands on the head of the
    /// first region's plate, which runs on up under the header.
    private func content(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            progress
                .frame(maxWidth: Self.maxWidth)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .background(CampaignRegion.liguria.ground.light)
            if span > 0 {
                CampaignMap(book: book, width: width, span: span, selected: selected, moment: moment,
                            you: badge) { tap($0, proxy) }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { span = $0 }
    }

    private var badge: SeatBadge {
        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 26, mark: store.seatMark,
                  cornice: store.cornice, livery: store.livery)
    }

    /// Stars over the whole road, and the table it has reached.
    private var progress: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(Palette.goldLight)
            Text("\(book.totalStars) of \(CampaignBook.maxStars) stars")
                .monospacedDigit()
            Spacer(minLength: 8)
            Text(verbatim: "\(book.current.place) · \(book.current.number)/\(Campaign.stages.count)")
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(1)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.onTable)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel()
    }

    @ViewBuilder private func card(_ proxy: ScrollViewProxy) -> some View {
        if let selected {
            CampaignStageCard(stage: selected, stars: book.stars(of: selected)) {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) { self.selected = nil }
            } play: {
                play(selected)
            }
            .frame(maxWidth: Self.maxWidth)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(selected.id)
        }
    }

    // MARK: Actions

    private func tap(_ stage: CampaignStage, _ proxy: ScrollViewProxy) {
        guard book.isUnlocked(stage), moment.unlocking != stage else { return Audio.shared.play(.refused) }
        Audio.shared.play(.tap)
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selected = selected == stage ? nil : stage }
        withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(CampaignLayout.anchor(stage.id), anchor: Self.overCard) }
    }

    /// High enough on screen that the card at the foot does not cover the table it is about.
    private static let overCard = UnitPoint(x: 0.5, y: 0.3)

    private func play(_ stage: CampaignStage) {
        book.showsMap = false
        dismiss()
        store.playCampaign(stage)
    }

    private func close() {
        book.showsMap = false
        dismiss()
    }

    // MARK: The walk back

    /// Scrolls to where the road is, and if a game has just been played there, plays out
    /// what it did: the stars struck one by one, the road to the next table drawn in, the
    /// table opening, and a region's prize if that was its last.
    private func walkBack(_ proxy: ScrollViewProxy) async {
        try? await Task.sleep(for: .milliseconds(80))
        guard let outcome = book.takeOutcome() else {
            let shown = DebugLaunch.campaignCard.flatMap(Campaign.stage(number:))
            selected = shown
            proxy.scrollTo(CampaignLayout.anchor((shown ?? book.current).id), anchor: shown == nil ? .center : Self.overCard)
            return
        }
        let next = outcome.firstClear ? Campaign.stage(number: outcome.stage.number + 1) : nil
        moment = CampaignMoment(outcome: outcome, struck: outcome.before, unlocking: next)
        proxy.scrollTo(CampaignLayout.anchor(outcome.stage.id), anchor: .center)
        guard outcome.won else {
            // A loss opens the same table again, one tap from another go.
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selected = outcome.stage }
            return
        }
        await strikeStars(outcome)
        if let next { await openRoad(to: next, proxy) }
        if let region = outcome.finishedRegion {
            try? await Task.sleep(for: .milliseconds(350))
            Audio.shared.play(.purchase)
            prize = region
        }
        moment = CampaignMoment()
    }

    private func strikeStars(_ outcome: CampaignBook.Outcome) async {
        try? await Task.sleep(for: .milliseconds(650))
        for star in outcome.before..<outcome.best {
            moment.struck = star + 1
            Audio.shared.play(.step)
            try? await Task.sleep(for: .milliseconds(380))
        }
    }

    private func openRoad(to next: CampaignStage, _ proxy: ScrollViewProxy) async {
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(CampaignLayout.anchor(next.id), anchor: .center) }
        withAnimation(.easeInOut(duration: 1.0)) { moment.roadDrawn = true }
        try? await Task.sleep(for: .milliseconds(1_000))
        moment.unlocking = nil
        moment.popped = next
        Audio.shared.play(.reveal)
        try? await Task.sleep(for: .milliseconds(420))
        moment.popped = nil
    }

    // MARK: A region won

    @ViewBuilder private var prizeOverlay: some View {
        if let prize {
            ZStack {
                Palette.ink.opacity(0.62).ignoresSafeArea()
                CampaignPrizeCard(region: prize, store: store) { self.prize = nil }
                    .padding(24)
                    .frame(maxWidth: 440)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }
}
