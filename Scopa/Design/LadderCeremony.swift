import SwiftUI
import ScopaCore

/// Which league is owed its ceremony, and whether the ceremony is on screen.
///
/// A league is celebrated once, ever: leagues are never lost, so the highest one shown is
/// all there is to remember. The ranked summary asks as soon as its bar has run, and the
/// lobby asks whenever it comes back, which catches a result the ladder settled late.
@Observable
final class LadderCeremony {
    struct Showing: Equatable {
        let league: League
        /// What the medal turns over from. Nil for Bronze, which arrives on its own.
        let from: League?
        /// Leagues below it reached without a ceremony of their own.
        let skipped: Int
    }

    private(set) var showing: Showing?

    /// Shows the ceremony for a league reached and not yet celebrated, if there is one.
    func check() {
        guard showing == nil, !Self.isQuiet, let owed = LadderPrizes.owed else { return }
        present(owed)
    }

    /// Checks once whatever is arriving on screen has settled.
    func checkSoon() {
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            check()
        }
    }

    func present(_ league: League) {
        let before = LadderPrizes.celebrated
        LadderPrizes.markCelebrated(league)
        let skipped = league.rawValue - (before.map { $0.rawValue + 1 } ?? 0)
        let from = league == .bronze ? nil : League(rawValue: league.rawValue - 1)
        withAnimation(.easeOut(duration: 0.3)) {
            showing = Showing(league: league, from: from, skipped: max(skipped, 0))
        }
    }

    func close() {
        withAnimation(.easeIn(duration: 0.25)) { showing = nil }
    }

    /// Screenshots are taken with `-noGameCenter`, often with `-rank` planting a league, and
    /// must not be covered by a ceremony nobody asked for. `-rankUp` asks for one.
    private static var isQuiet: Bool {
        #if DEBUG
        DebugLaunch.staysSignedOut && !DebugLaunch.forcesRankUp
        #else
        false
        #endif
    }
}

extension View {
    /// Hangs the new-league ceremony over everything. Applied once, at the root.
    func ladderCeremony(store: TableStore) -> some View {
        modifier(LadderCeremonyHost(store: store))
    }
}

private struct LadderCeremonyHost: ViewModifier {
    @Bindable var store: TableStore
    @State private var ceremony = LadderCeremony()
    @State private var showsRoad = false
    @Environment(Toaster.self) private var toaster: Toaster?

    func body(content: Content) -> some View {
        content
            .environment(ceremony)
            .overlay {
                if let showing = ceremony.showing {
                    RankUpCeremony(showing: showing, name: store.playerName, livery: store.livery,
                                   mark: $store.seatMark,
                                   road: { ceremony.close(); showsRoad = true },
                                   close: { ceremony.close() })
                        .transition(.opacity)
                }
            }
            .sheet(isPresented: $showsRoad) { LadderRoadSheet(store: store).coversBanner() }
            .task { await arrive() }
            .onChange(of: store.rank) { if store.route == .lobby { ceremony.check() } }
            .onChange(of: store.route) { _, route in if route == .lobby { ceremony.checkSoon() } }
            // News held for the end of a ranked result comes after the ceremony, not over it.
            .onChange(of: ceremony.showing == nil) { _, closed in if closed { toaster?.releaseHeld() } }
    }

    /// Picks up a league cached by a build older than the prizes, then checks.
    private func arrive() async {
        LadderPrizes.remember(store.rank)
        #if DEBUG
        if DebugLaunch.forcesRankUp {
            // After `-rank` has planted its league.
            try? await Task.sleep(for: .seconds(1))
            if let league = store.rank.flatMap({ League(rawValue: $0.standing.league) }) { ceremony.present(league) }
            return
        }
        #endif
        if store.route == .lobby { ceremony.checkSoon() }
    }
}
