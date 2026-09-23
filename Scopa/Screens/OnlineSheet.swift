import GameKit
import SwiftUI
import ScopaCore
import ScopaGameCenter
import ScopaRelay
import ScopaRewards

/// A table over the internet against people you do not know: for the league, or for
/// nothing. Playing a friend lives behind the friends door, where the codes are.
struct OnlineSheet: View {
    @Bindable var store: TableStore

    /// Ranked is one real opponent near your league, for the league. Casual is whoever
    /// else is looking, for nothing. One door, two ways through it.
    private enum Mode: Hashable { case ranked, casual }

    @State private var mode = Mode.ranked
    @State private var players = 2
    /// The partner picker, once the friends list has come back.
    @State private var friends: [GKPlayer]?
    @State private var isLoadingFriends = false
    @State private var friendsProblem: FriendsProblem?
    @Environment(\.dismiss) private var dismiss

    private var isBusy: Bool { store.onlineStatus != nil }

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        SheetScaffold(title: "Ranked", subtitle: "Real people near your league. Or a casual table, for nothing.",
                      close: { dismiss() }) {
            VStack(alignment: .leading, spacing: 20) {
                // Where you stand comes before how to play: the door is called Ranked, and
                // the league is what somebody opening it has come to look at.
                LeaguePanel(store: store)
                modePicker
                if mode == .ranked { rankedIntro } else { casualSetup }
            }
            .padding(20)
        } bottom: {
            actions
        }
        .onAppear { store.refreshRank() }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: store.onlineStatus)
        .sheet(isPresented: Binding(get: { friends != nil }, set: { if !$0 { friends = nil } })) {
            PartnerPicker(friends: friends ?? [], problem: friendsProblem, isLoading: isLoadingFriends,
                          invite: { store.inviteRankedDuo() },
                          addFriends: { store.showGameCenterFriends { pickPartner() } },
                          retry: { pickPartner() }) { friend in
                friends = nil
                store.playRankedDuo(with: friend)
            }
        }
        // Full height: the league now leads the sheet, and at the medium detent it pushed the
        // choice the Solo button obeys down behind the buttons.
        .presentationDetents([.large])
    }

    private var modePicker: some View {
        GlassSegments(options: [Mode.ranked, .casual], selection: $mode,
                      title: { $0 == .ranked ? "Ranked" : "Casual" }, isEnabled: !isBusy)
    }

    /// The shape of a game played alone, then the small print both shapes share. The league
    /// itself sits above the mode picker, at the top of the sheet.
    ///
    /// The shape used to be neither asked nor said: solo dealt a four with the house behind
    /// each player, which is a duo with a stranger for a partner, so the two buttons played
    /// the same game. The picker is here rather than in the settings because it is part of
    /// asking for the game, and the line under it changes with it, so the choice is read
    /// where it is made.
    private var rankedIntro: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "Playing alone")
                GlassSegments(options: RankedSolo.allCases, selection: $store.rankedSolo,
                              title: { LocalizedStringKey($0.pillLabel) },
                              spoken: { $0.spokenLabel }, isEnabled: !isBusy)
                Text(store.rankedSolo.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: store.rankedSolo)
            }
            Text("Nobody found in time means the house sits down instead, in the same seats. Duo is you and a friend against two of the house, rated together. Only real players are rated, and a league reached is yours for the season. A game against the house counts ten times a day; a game against somebody real always counts.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var casualSetup: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "How many at the table")
                GlassSegments(options: Array(GameConfiguration.playerRange), selection: $players,
                              title: { LocalizedStringKey("\($0)") }, isEnabled: !isBusy)
            }
            Text("Whoever else is looking for a table of the same size. Nothing is at stake and nothing is rated. Your Game Center name is the one shown at the table — to play someone you know, open a table behind the friends door and send them the code.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The bar along the bottom. The ground behind the sheet stops at the scroll view, so
    /// the felt is repeated here, faded in at the top, to hide what scrolls behind it.
    ///
    /// The wait takes the buttons' place rather than sitting under them: on the medium detent
    /// anything below the fold is out of sight, and what the search is doing is the one thing
    /// somebody waiting is looking at.
    private var actions: some View {
        Group {
            if let status = store.onlineStatus {
                OnlineProgressLine(store: store, status: status, waiting: waitingLabel)
                    .transition(.opacity)
            } else if mode == .ranked {
                VStack(spacing: 10) {
                    Button("Solo") { store.playRanked() }
                        .buttonStyle(FilledButtonStyle())
                    Button(isLoadingFriends ? "Loading friends…" : "Duo · pick a partner") { pickPartner() }
                        .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
                        .disabled(isLoadingFriends)
                }
            } else {
                Button("Find a table") { store.playOnline(players: players) }
                    .buttonStyle(FilledButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            LinearGradient(stops: [.init(color: felt.shade(0), location: 0),
                                   .init(color: felt.deep, location: 0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    /// Loads the friends list and opens the picker. An empty list opens it too, with a line
    /// saying where friends come from, and so does a failure, saying what went wrong.
    private func pickPartner() {
        guard !isLoadingFriends else { return }
        isLoadingFriends = true
        Task {
            defer { isLoadingFriends = false }
            do {
                friendsProblem = nil
                friends = try await store.loadFriends().sorted { $0.displayName < $1.displayName }
            } catch let error as GameCenterError {
                friendsProblem = FriendsProblem(error)
                friends = []
            } catch {
                friendsProblem = .unavailable(error.localizedDescription)
                friends = []
            }
        }
    }

    /// What the wait is for, once a table is being looked for.
    private var waitingLabel: LocalizedStringKey {
        store.isRanked ? "Looking for someone near your league" : "Looking for players"
    }
}

/// Why the friends list has nobody in it, when it is not simply empty.
private enum FriendsProblem: Equatable {
    case signedOut
    case denied
    case restricted
    case unavailable(String)

    init(_ error: GameCenterError) {
        switch error {
        case .notSignedIn, .cancelled: self = .signedOut
        case .friendsDenied: self = .denied
        case .friendsRestricted: self = .restricted
        case .friendsUnavailable(let reason), .matchmakingFailed(let reason): self = .unavailable(reason)
        }
    }
}

/// One friend, by name, for a duo. Apple's sheet would offer three; a duo is one.
///
/// The list only holds friends who already play Scopa and have let it see them, so
/// "invite someone else" opens Apple's own invitation sheet, where the rest of the friend
/// list can be named. Apple's friends page is a profile browser with no invitation on it.
///
/// With nobody to show it says why and offers the way out: an invitation when there is
/// nobody to list, Settings when Scopa was refused, another go when the fetch failed.
private struct PartnerPicker: View {
    let friends: [GKPlayer]
    let problem: FriendsProblem?
    let isLoading: Bool
    let invite: () -> Void
    let addFriends: () -> Void
    let retry: () -> Void
    let pick: (GKPlayer) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(20)
            }
            .softScrollEdge(.top)
            .background(TableGround())
            .navigationTitle("Your partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(Palette.goldLight)
                }
                // Friend lists off on the device is the one case where nothing can be sent.
                if problem != .restricted {
                    ToolbarItem(placement: .primaryAction) {
                        Button { invite() } label: {
                            Label("Invite a friend", systemImage: "person.badge.plus")
                        }
                        .tint(Palette.goldLight)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            HStack(spacing: 12) {
                ProgressView().tint(Palette.onTable)
                Text("Loading friends…")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onTable)
            }
        } else if let problem {
            trouble(problem)
        } else if friends.isEmpty {
            nobodyToList
        } else {
            friendList
        }
    }

    /// Why there is no list, and the way out of it.
    @ViewBuilder private func trouble(_ problem: FriendsProblem) -> some View {
        switch problem {
        case .signedOut:
            explanation("Sign in to Game Center to play a duo.")
            Button("Sign in") { retry() }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        case .denied:
            explanation("Scopa needs to see your Game Center friends to pick a partner. Allow it in Settings, under Game Center.")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
            quietButton("Check again", action: retry)
        case .restricted:
            explanation("Friend lists are turned off on this device, so a duo cannot be picked here. Screen Time settings can turn them back on.")
        case .unavailable(let reason):
            explanation("Your Game Center friends could not be loaded just now.")
            Text(verbatim: reason)
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { retry() }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        }
    }

    private var nobodyToList: some View {
        Group {
            explanation("Nobody to list yet — only friends who already play Scopa show up here. Invite a friend anyway and Game Center will ask them on their phone.")
            Button("Invite a friend") { invite() }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
            quietButton("Find friends on Game Center", action: addFriends)
            quietButton("Check again", action: retry)
        }
    }

    private var friendList: some View {
        Group {
            Text("They get an invitation on their phone. The table fills once they have said yes.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.offset) { _, friend in
                    Button { pick(friend) } label: {
                        row(name: Text(verbatim: friend.displayName)) {
                            SeatBadge(name: friend.displayName, tint: Palette.seat(2), size: 34)
                        }
                    }
                    .buttonStyle(.plain)
                    Rule()
                }
                Button { invite() } label: {
                    row(name: Text("Invite someone else")) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.goldLight)
                            .frame(width: 34, height: 34)
                    }
                }
                .buttonStyle(.plain)
            }
            .glassPanel(radius: GlassRadius.control)
            Text("Someone missing? Only friends who already play Scopa are listed. Anyone else on your friend list can still be invited — Game Center asks them on their phone.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Find friends on Game Center") { addFriends() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.goldLight)
        }
    }

    /// One line of the list: a badge or a symbol, a name, and a chevron.
    private func row(name: Text, mark: () -> some View) -> some View {
        HStack(spacing: 12) {
            mark()
            name
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Palette.onTableSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func explanation(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.onTable)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The second way out of a page, under the button that is the first.
    private func quietButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title) { action() }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
            .frame(maxWidth: .infinity)
    }
}

/// Your league, as a medal struck in its own metal, a name and how far along the bar you
/// are. The same metal as the chip under the lobby's wordmark, at the size a sheet allows.
private struct LeaguePanel: View {
    let store: TableStore
    @Environment(\.locale) private var locale

    private var metal: LeagueMetal { LeagueMetal.league(store.rank?.standing.league ?? 0) }

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(spacing: 16) {
            LeagueMedal(league: store.rank?.standing.league ?? 0, size: 46)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: store.rank?.standing.leagueTitle(locale: locale)
                     ?? String(localized: "Bronze", locale: locale) + " III")
                    .font(.display(34))
                    .foregroundStyle(Palette.onTable)
                progressBar
                record
                houseLeft
            }
        }
        .padding(16)
        .glassPanel()
        .overlay { RoundedRectangle(cornerRadius: GlassRadius.panel).strokeBorder(metal.base.opacity(0.25), lineWidth: 1) }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = Double(store.rank?.standing.progress ?? 0) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.45))
                Capsule().fill(metal.sheen)
                    .frame(width: max(geometry.size.width * progress, progress > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder private var record: some View {
        if let rank = store.rank {
            HStack(spacing: 6) {
                Text("\(rank.wins) wins · \(rank.games) games")
                // Only from a Worker that has seasons in it: an older one answers without
                // a date and says nothing.
                if let days = rank.daysLeftInSeason {
                    Text(verbatim: "·")
                    Text(days == 0 ? "Season ends today" : "Season ends in \(days) days")
                        .foregroundStyle(Palette.goldLight.opacity(0.9))
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.onTableSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    /// What the house will still pay for today.
    ///
    /// The day's ration is the only thing holding a house win back, so somebody who does not
    /// know it is spent reads a game that moved nothing as the ladder being broken. It belongs
    /// here, on the panel the sheet opens on, rather than in a line below the fold or in the
    /// banner over a deal already under way.
    ///
    /// Nothing at all until the Worker has answered, which is the honest state: the phone does
    /// not know the count until it asks.
    @ViewBuilder private var houseLeft: some View {
        if let house = store.rank?.house {
            let left = max(house.perDay - house.playedToday, 0)
            HStack(spacing: 5) {
                Image(systemName: left > 0 ? "hourglass" : "hourglass.bottomhalf.filled")
                if left > 0 {
                    Text("\(left) of \(house.perDay) house games left today")
                } else {
                    Text("No house games left today")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(left > 0 ? Palette.onTableSoft : Palette.goldLight.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}
