import SwiftUI
import ScopaCore

extension View {
    /// Hangs the match-found moment over every screen. Applied once, at the root, so it
    /// carries on across the lobby, the waiting room and the deal.
    func matchFoundMoment(store: TableStore) -> some View {
        modifier(MatchFoundHost(store: store))
    }
}

private struct MatchFoundHost: ViewModifier {
    let store: TableStore

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if let found = store.matchFound {
                        MatchFoundMoment(found: found, store: store)
                            .id(found.id)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: store.matchFound)
            }
            #if DEBUG
            .task { await loopForScreenshots() }
            #endif
    }

    #if DEBUG
    /// `-matchFound <name>`: the moment again every few seconds, over whatever is on screen.
    /// `-matchFound house` shows the house sitting down instead.
    private func loopForScreenshots() async {
        guard let names = DebugLaunch.matchFoundNames else { return }
        try? await Task.sleep(for: .seconds(1))
        while !Task.isCancelled {
            store.pretendMatchFound(names)
            try? await Task.sleep(for: .seconds(9))
        }
    }
    #endif
}

/// A ranked table found its other side: a person the search paired, or the house. The screen
/// is covered for a beat — both sides come in from their edges with their badges and leagues,
/// a card from each leans on the other, the newcomer is named — and then the table.
///
/// It used to be a small panel over the lobby. The ranked sheet stayed up over it while the
/// seats were taken, so the moment mostly played out behind the sheet, and the house, which
/// is most ranked games, never had one at all.
struct MatchFoundMoment: View {
    let found: MatchFound
    let store: TableStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @Environment(\.screenSize) private var screenSize
    /// The two sides have come in from the edges.
    @State private var met = false
    /// The cards have touched and the name is said.
    @State private var seated = false

    /// Everything in its place, straight away when motion is reduced.
    private var together: Bool { met || reduceMotion }
    private var isWide: Bool { screenSize.width > screenSize.height && screenSize.height < 500 }

    var body: some View {
        ZStack {
            backdrop
            content
        }
        // Heard instead, see `land`: a VoiceOver cursor sent here would be gone in a moment.
        .accessibilityHidden(true)
        .sensoryFeedback(Haptic.seated, trigger: seated) { _, now in now }
        .task { await play() }
        // A person's league is known once the ladder answers for their seat, which can land
        // while the moment is up.
        .task(id: store.lobby?.players.count) { await store.lookUpRanks(of: store.lobby?.players ?? []) }
    }

    /// The table's own cloth in its deepest shade, warmed in the middle where the two sides
    /// meet. Opaque, and it takes every touch, so nothing on the table being dealt underneath
    /// is seen half-laid or played blind.
    private var backdrop: some View {
        ZStack {
            felt.deep
            RadialGradient(colors: [Palette.goldLight.opacity(seated ? 0.22 : 0.08), .clear],
                           center: .center, startRadius: 8, endRadius: 360)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private var content: some View {
        VStack(spacing: isWide ? 12 : 22) {
            VStack(spacing: 6) {
                Caption(text: "Ranked")
                Text("Match found")
                    .font(.display(isWide ? 30 : 38))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .opacity(together ? 1 : 0)
            HStack(alignment: .top, spacing: 0) {
                MatchFoundSide(names: found.ours, home: true, found: found, store: store)
                    .offset(x: together ? 0 : -64)
                Spacer(minLength: 4)
                cards.padding(.top, 10)
                Spacer(minLength: 4)
                MatchFoundSide(names: found.theirs, home: false, found: found, store: store)
                    .offset(x: together ? 0 : 64)
            }
            .opacity(together ? 1 : 0)
            arrivalLines
                .opacity(seated || reduceMotion ? 1 : 0)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .scaleEffect(together ? 1 : 0.96)
    }

    /// Who sat down, and for the house, how hard it plays.
    private var arrivalLines: some View {
        VStack(spacing: 6) {
            Text(arrival)
                .font(.display(isWide ? 20 : 24))
                .foregroundStyle(Palette.goldLight)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if found.isHouse {
                Text(store.isRankedDuo ? "The house plays at the higher league of you two."
                                       : "The house plays at your league.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// A card from each side, leaning in until the tops touch: a little house of two cards
    /// in the middle of the table.
    private var cards: some View {
        ZStack {
            CardBack(width: 26)
                .rotationEffect(.degrees(together ? 14 : 0), anchor: .bottom)
                .offset(x: together ? -19 : -46)
            CardBack(width: 26)
                .rotationEffect(.degrees(together ? -14 : 0), anchor: .bottom)
                .offset(x: together ? 19 : 46)
        }
        .frame(width: 72, height: 48)
    }

    /// "Giulia sits down", every name at a table that found more than one, or the house.
    private var arrival: String {
        if found.isHouse { return String(localized: "The house sits down", locale: locale) }
        let names = found.theirs.formatted(.list(type: .and).locale(locale))
        return found.theirs.count == 1
            ? String(localized: "\(names) sits down", locale: locale)
            : String(localized: "\(names) sit down", locale: locale)
    }

    /// The sides come in, and the moment the cards meet is heard and felt.
    private func play() async {
        if !reduceMotion {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.55, bounce: 0.25)) { met = true }
            try? await Task.sleep(for: .milliseconds(450))
        }
        guard !Task.isCancelled else { return }
        land()
    }

    private func land() {
        withAnimation(.easeOut(duration: 0.3)) { seated = true }
        Audio.shared.play(.reveal)
        let title = String(localized: "Match found", locale: locale)
        AccessibilityNotification.Announcement(title + ". " + arrival).post()
    }
}

/// One side of the moment: a badge for each player on it, overlapping when there are two, their
/// names, and the league each one wears at the table.
private struct MatchFoundSide: View {
    let names: [String]
    let home: Bool
    let found: MatchFound
    let store: TableStore

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: -16) {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    badge(name, index: index)
                }
            }
            // One line, so the leagues under the two sides sit level.
            Text(verbatim: names.formatted(.list(type: .and).locale(locale)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            leagues
                .frame(minHeight: 20)
                .animation(.easeOut(duration: 0.25), value: standings)
        }
        .frame(width: 142)
    }

    /// Each player's league, as far as it is known yet, in seat order.
    private var standings: [Standing?] { names.indices.map { standing(names[$0], index: $0) } }

    /// The league in full under a side that shares one, as the house's two chairs do, and a
    /// medal and numeral each where two people stand in different places.
    @ViewBuilder private var leagues: some View {
        let known = standings.compactMap { $0 }
        if let only = known.first, Set(known.map(\.step)).count == 1 {
            chip(only, named: true)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(known.enumerated()), id: \.offset) { _, standing in chip(standing, named: false) }
            }
        }
    }

    /// The seat behind a name: from the lobby at a table over the network, from the deal at
    /// one on this phone. Nil until it has reached this phone.
    private func player(_ name: String) -> Player? {
        (store.lobby?.players ?? store.view?.configuration.players)?.first { $0.name == name }
    }

    private func isMe(_ index: Int) -> Bool { home && index == 0 }

    /// This phone's chair is terracotta, as at the table, and the others take the next colours.
    private func badge(_ name: String, index: Int) -> some View {
        let seat = isMe(index) ? nil : player(name)
        return SeatBadge(name: name, tint: Palette.seat(home ? index * 2 : [1, 3, 2][index % 3]), size: 58,
                         mark: isMe(index) ? store.seatMark : seat.map { SeatMark($0) } ?? .initial,
                         cornice: isMe(index) ? store.cornice : seat.map { Cornice($0) } ?? .none,
                         livery: isMe(index) ? store.livery : seat.map { SeatLivery($0) } ?? .tavolo)
    }

    /// The league over somebody: this phone's own off the ladder, a person's once the ladder
    /// has answered for them, the house at the division it plays at, whichever side it is on.
    private func standing(_ name: String, index: Int) -> Standing? {
        if isMe(index) { return store.rank.map { Ranking.standing(for: $0.rating) } }
        if !home, let step = found.houseStep { return Ranking.standing(for: Ranking.houseRating(atStep: step, jitter: 0)) }
        return player(name).flatMap { store.rank(of: $0) }.map { Ranking.standing(for: $0.rating) }
    }

    /// A medal and the league, or only its numeral as over a seat at the table.
    private func chip(_ standing: Standing, named: Bool) -> some View {
        HStack(spacing: 5) {
            LeagueMedal(league: standing.league.rawValue, size: 20)
            Text(verbatim: named ? standing.leagueTitle(locale: locale)
                                 : ["I", "II", "III"][safe: standing.division - 1] ?? "")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LeagueMetal.league(standing.league.rawValue).light)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .transition(.opacity)
    }
}
