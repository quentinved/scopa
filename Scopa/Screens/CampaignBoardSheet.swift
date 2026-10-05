import SwiftUI
import UIKit
import ScopaGameCenter

/// The campaign's board, read from the Worker's `v1/campaign/board`: everyone on the road,
/// most stars first, or only your Game Center friends. Opened from the map's header.
struct CampaignBoardSheet: View {
    let store: TableStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var who: SeasonBoardSheet.Who
    @State private var board: Ladder.CampaignBoard?
    /// Ladder off, Worker down, or no network.
    @State private var failed = false
    @State private var friendsProblem: FriendsProblem?

    init(store: TableStore) {
        self.store = store
        _who = State(initialValue: DebugLaunch.campaignBoardOnFriends ? .friends : .everyone)
    }

    var body: some View {
        SheetScaffold(title: "Campaign board", subtitle: "Everyone on the road, most stars first.",
                      close: { dismiss() }) {
            VStack(spacing: 0) {
                GlassSegments(options: SeasonBoardSheet.Who.allCases, selection: $who) { $0.title }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                content
            }
        }
        .presentationDetents([.large])
        .task(id: who) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let board, !board.isEmpty {
            rows(board)
        } else if let friendsProblem {
            FriendsTrouble(problem: friendsProblem, openSettings: openSettings, retry: reload)
        } else if failed {
            BoardMessage(symbol: "wifi.slash", title: "The ladder is not answering",
                         detail: "It needs a line out to the world. Try again in a moment.")
        } else if board != nil {
            empty
        } else {
            ProgressView()
                .tint(Palette.onTableSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
        }
    }

    @ViewBuilder private var empty: some View {
        switch who {
        case .everyone:
            BoardMessage(symbol: "map", title: "Nobody is on the road yet", detail: "Win a table and the board has you")
        case .friends:
            BoardMessage(symbol: "person.2", title: "None of your friends is on the road yet",
                         detail: "Someone missing? They need Scopa too. Add them on Game Center and they show up here when you come back.",
                         action: ("Find friends on Game Center", findFriends))
        }
    }

    private func rows(_ board: Ladder.CampaignBoard) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(board.top.enumerated()), id: \.element.id) { index, row in
                CampaignBoardRow(place: index + 1, row: row,
                                 isYou: row.id == CampaignStandings.playerID || board.you?.rank == index + 1)
            }
            // The Worker sends fifty rows. A reader below that gets their own line.
            if let you = board.you, let rank = you.rank, rank > board.top.count {
                YourPlace(title: "Where you stand", rank: rank, percentile: you.percentile)
                    .padding(.top, 6)
            }
            footnote(board)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func footnote(_ board: Ladder.CampaignBoard) -> some View {
        VStack(spacing: 4) {
            if who == .friends {
                Text("Someone missing? They need Scopa too. Add them on Game Center and they show up here when you come back.")
                BoardLink(label: "Find friends on Game Center", action: findFriends).padding(.top, 6)
            } else if let you = board.you {
                Text("^[\(you.played) player](inflect: true) on the road")
            }
            if board.you?.rank == nil {
                Text(CampaignStandings.playerID == nil ? "Sign in to Game Center to join the board" : "Win a table and the board has you")
                    .foregroundStyle(Palette.goldLight.opacity(0.9))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.onTableSoft)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 14)
    }

    // MARK: Loading

    private func load() async {
        board = nil
        failed = false
        friendsProblem = nil
        do {
            let answer: Ladder.CampaignBoard?
            if who == .everyone {
                answer = await CampaignStandings.board()
            } else {
                answer = try await CampaignStandings.friendsBoard()
            }
            // A tab left before its answer came back must not have it land on the other one.
            guard !Task.isCancelled else { return }
            guard let answer else {
                failed = true
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) { board = answer }
        } catch let error as GameCenterError {
            friendsProblem = FriendsProblem(error)
        } catch {
            friendsProblem = .unavailable(error.localizedDescription)
        }
    }

    private func reload() {
        Task { await load() }
    }

    private func findFriends() {
        store.showGameCenterFriends { reload() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// One player's road: place, face and name, the table reached under the name, and the
/// stars on the right.
private struct CampaignBoardRow: View {
    let place: Int
    let row: Ladder.CampaignBoard.Row
    let isYou: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(place)")
                .font(.system(size: 15, weight: place <= 3 ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(place <= 3 ? Palette.goldLight : Palette.onTableSoft)
                .frame(width: 26)
            CampaignFaceBadge(look: row, size: 32)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: row.name)
                    .font(.system(size: 15, weight: isYou ? .bold : .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                reached
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            stars
        }
        .ladderPanel(isYou: isYou)
        .accessibilityElement(children: .combine)
    }

    /// "Stage 9 · Napoli", as the lobby's campaign door says it.
    @ViewBuilder private var reached: some View {
        if let stage = Campaign.stage(number: row.stage) {
            Text("Stage \(stage.number) · \(stage.region.title)")
        }
    }

    private var stars: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.goldLight)
            Text(verbatim: "\(row.stars)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onTable)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(row.stars) of \(CampaignBook.maxStars) stars"))
    }
}
