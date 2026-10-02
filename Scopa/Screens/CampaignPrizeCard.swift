import SwiftUI
import ScopaCore
import ScopaRewards

/// The card a region's last table hands over: the prize off the shop's shelves, already
/// owned, and the pack already waiting in the album.
struct CampaignPrizeCard: View {
    let region: CampaignRegion
    let store: TableStore
    let done: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Caption(verbatim: "\(region.numeral) · \(region.title)")
            Text(region == .roma ? "The road is yours" : "Region complete")
                .font(.display(32))
                .foregroundStyle(Palette.ink)
            HStack(alignment: .bottom, spacing: 22) {
                prizeArt
                PackArt(tier: region.pack, width: 58)
            }
            .padding(.vertical, 6)
            Text("\(region.prizeTitle) is yours, and a \(region.pack.title) pack is waiting in the album.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Lovely", action: done)
                .buttonStyle(FilledButtonStyle(minHeight: 50))
        }
        .padding(22)
        .background(Palette.stock, in: .rect(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1.5).padding(5) }
        .shadow(color: Palette.ink.opacity(0.5), radius: 24, y: 10)
    }

    @ViewBuilder private var prizeArt: some View {
        switch region.prize {
        case .mark(let mark):
            SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 72, mark: mark, livery: store.livery)
        case .cornice(let cornice):
            SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 64, mark: store.seatMark,
                      cornice: cornice, livery: store.livery)
                .padding(6)
        case .tapis(let tapis):
            TapisSwatch(tapis: tapis, felt: store.tableFelt, height: 104)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}

extension View {
    /// The campaign map over everything, for the walk back from a campaign table and for
    /// `-campaign`. The lobby opens it its own way; this is the door that outlives the lobby.
    func campaignCover(_ store: TableStore) -> some View {
        modifier(CampaignCover(store: store, book: store.campaignBook))
    }
}

private struct CampaignCover: ViewModifier {
    let store: TableStore
    @Bindable var book: CampaignBook

    private var finishedCampaignGame: Bool { store.campaignStage != nil && store.view?.isFinished == true }

    /// `-campaignPlay` with `-autoPlay`: once the summary has paid, walks back to the map
    /// the way the button would, so the whole round trip can be watched without a finger.
    private func walkOutIfAutoPlaying() async {
        guard finishedCampaignGame, DebugLaunch.playsItself, DebugLaunch.campaignPlay != nil else { return }
        try? await Task.sleep(for: .seconds(12))
        if finishedCampaignGame { store.leaveTable() }
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $book.showsMap) { CampaignView() }
            .task {
                // A beat after launch: a cover asked for before the window is up never shows.
                try? await Task.sleep(for: .milliseconds(900))
                DebugLaunch.applyCampaign(to: store)
            }
            .task(id: finishedCampaignGame) { await walkOutIfAutoPlaying() }
    }
}
