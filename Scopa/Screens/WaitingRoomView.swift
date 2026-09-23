import SwiftUI
import UIKit
import ScopaCore
import ScopaRelay

/// The host sets the table; guests watch the seats fill.
struct WaitingRoomView: View {
    let store: TableStore

    private var lobby: Lobby? { store.lobby }
    private var players: [Player] { lobby?.players ?? [] }

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    var body: some View {
        Group {
            if stage.isWide { wideBody } else { tallBody }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TableGround() }
    }

    /// Portrait: the table, then the seats around it, then the rules of the game.
    private var tallBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    invitation
                    seats.padding(.top, 24)
                    if store.isHost { settings.padding(.top, 24) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The seats and the table rules dissolve under the button rather than
            // being cut off by it.
            .softScrollEdge(.bottom)
            footer.padding(.horizontal, 24)
        }
    }

    /// Landscape: who is here on the left, what they are about to play on the right.
    ///
    /// The diamond of four seats is 380 points tall, more than a turned phone has, so it
    /// closes up into a square and the table's rules move alongside it.
    private var wideBody: some View {
        VStack(spacing: 0) {
            header
            invitation
            HStack(alignment: .top, spacing: 24) {
                ScrollView {
                    seats.padding(.vertical, 4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                VStack(spacing: 0) {
                    ScrollView {
                        if store.isHost { settings.padding(.vertical, 4) }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .softScrollEdge(.bottom)
                    footer
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\((lobby?.host.name ?? store.playerName).uppercased())'S TABLE")
                    .font(.display(stage.pick(tall: 38, wide: 30)))
                    .foregroundStyle(Palette.onTable)
                Text(store.isNearbyTable
                     ? "Nearby · \(players.count) of \(GameConfiguration.playerRange.upperBound) seated"
                     : "Online · \(players.count) of \(GameConfiguration.playerRange.upperBound) seated")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer()
            Button { store.leaveTable() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .glass(.riviera(interactive: true), in: .circle)
                    .contentShape(.circle)
            }
            .foregroundStyle(Palette.onTable)
        }
        .padding(.top, 12)
    }

    /// The four letters, and the link that saves anybody typing them. It goes when the
    /// table fills, since a code nobody can use any more is only clutter.
    @ViewBuilder private var invitation: some View {
        if let room = store.room, lobby?.isFull != true {
            HStack(spacing: 14) {
                tableCode(room)
                Spacer(minLength: 0)
                shareLink(room)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassPanel(radius: GlassRadius.control)
            .padding(.top, 16)
            // A tap puts the code on the clipboard, for everywhere the sheet does not fit.
            .onTapGesture { UIPasteboard.general.string = room.code }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Table code \(room.code.map(String.init).joined(separator: " "))")
        }
    }

    private func tableCode(_ room: Relay.Table) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("TABLE CODE")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Palette.onTableSoft)
            Text(room.code)
                .font(.system(size: stage.pick(tall: 32, wide: 26), weight: .bold, design: .monospaced))
                .kerning(5)
                .foregroundStyle(Palette.goldLight)
        }
    }

    private func shareLink(_ room: Relay.Table) -> some View {
        ShareLink(item: room.link,
                  subject: Text("A game of Scopa"),
                  message: Text("Join my table of Scopa — the code is \(room.code)")) {
            Label("Invite", systemImage: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glass(.riviera(interactive: true), in: .capsule)
        }
        .foregroundStyle(Palette.onTable)
    }

    /// Four places around a broom, filling clockwise as people join. Landscape drops the
    /// broom in the middle and squares the four up: the same seats, half the height.
    private var seats: some View {
        seatGrid.animation(.spring(duration: 0.35, bounce: 0.2), value: players)
    }

    @ViewBuilder private var seatGrid: some View {
        if stage.isWide { squaredSeats } else { diamondSeats }
    }

    private var squaredSeats: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                seat(0, height: 96)
                seat(1, height: 96)
            }
            GridRow {
                seat(2, height: 96)
                seat(3, height: 96)
            }
        }
    }

    private var diamondSeats: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Color.clear.frame(width: 88, height: 1)
                seat(0)
                Color.clear.frame(width: 88, height: 1)
            }
            GridRow {
                seat(1)
                BroomMark(size: 38, tint: Palette.goldLight)
                    .frame(width: 84, height: 84)
                    .glass(.riviera(), in: .circle)
                seat(2)
            }
            GridRow {
                Color.clear.frame(width: 88, height: 1)
                seat(3)
                Color.clear.frame(width: 88, height: 1)
            }
        }
    }

    /// One chair. Empty, it is the host's way of filling it with a bot or a friend, and
    /// with a bot in it, the host's way of standing it back up.
    private func seat(_ index: Int, height: CGFloat = 118) -> some View {
        let player = players[safe: index]
        let bot = player.flatMap { $0.isBot && store.isSettingTheTable ? $0.id : nil }
        let free = player == nil
        return SeatCard(
            player: player,
            index: index,
            teams: lobby?.teams == true,
            height: height,
            seatBot: free && store.canSeatBots ? { store.addBot() } : nil,
            inviteFriend: free && store.canInviteFriends ? { store.inviteFriendToTable() } : nil,
            // A table of ours has a code, so a chair at it can be sent to anybody, or
            // offered to a Game Center friend by name with the code inside the invitation.
            shareCode: free && store.canInviteToRoom ? store.room : nil,
            inviteByName: free && store.canInviteToRoom ? { store.inviteFriendToRoom() } : nil,
            sendBotAway: bot.map { id in { store.removeBot(id) } }
        )
    }

    /// What the host can set before the deal.
    private var settings: some View {
        VStack(spacing: 14) {
            teamsTabs
            clockTabs
            primieraTabs
            tieTabs
            targetRow
            if players.count != 4 && lobby?.teams == true {
                Text("Teams need four players.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.terracotta)
            }
        }
    }

    private var teamsTabs: some View {
        HStack(spacing: 4) {
            ModeTab(title: "Teams", selected: lobby?.teams == true, enabled: players.count == 4) {
                store.setTeams(true)
            }
            ModeTab(title: "Everyone alone", selected: lobby?.teams != true, enabled: true) {
                store.setTeams(false)
            }
        }
        .padding(5)
        .glassPanel(radius: GlassRadius.control)
    }

    private var clockTabs: some View {
        HStack(spacing: 6) {
            ForEach(TurnClock.allCases, id: \.self) { clock in
                ModeTab(title: clock.label, selected: lobby?.turnClock == clock, enabled: true) {
                    store.setTurnClock(clock)
                }
            }
        }
        .padding(5)
        .glassPanel(radius: GlassRadius.control)
    }

    /// How the primiera is settled: the classic sum, or the kitchen-table count of sevens.
    private var primieraTabs: some View {
        HStack(spacing: 6) {
            ForEach(PrimieraRule.allCases, id: \.self) { rule in
                ModeTab(title: rule.label, selected: (lobby?.primiera ?? .default) == rule, enabled: true) {
                    store.setPrimiera(rule)
                }
            }
        }
        .padding(5)
        .glassPanel(radius: GlassRadius.control)
    }

    /// The house rule, on the host's screen only: a guest sees what it settled on in the
    /// summary and is never shown a choice that was not theirs to make.
    @ViewBuilder private var tieTabs: some View {
        if store.knowsTieRules && store.isHost {
            HStack(spacing: 6) {
                ForEach(TieRule.allCases, id: \.self) { rule in
                    ModeTab(title: rule.label, selected: (lobby?.ties ?? .default) == rule, enabled: true) {
                        store.setTies(rule)
                    }
                }
            }
            .padding(5)
            .glassPanel(radius: GlassRadius.control)
        }
    }

    private var targetRow: some View {
        HStack {
            Text("Play to")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTable)
            Spacer()
            ScoreStepper(value: lobby?.targetScore ?? 11, enabled: store.isHost) {
                store.setTargetScore($0)
            }
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if store.isHost {
                // Nobody who accepted is left standing: the button waits for the last of
                // them to take a chair, however the rest of the table is made up.
                let ready = lobby?.canStart == true && !store.isWaitingForInvited
                Button("Deal the cards") { store.startGame() }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.45)
            } else {
                Text("Waiting for \(lobby?.host.name ?? "the host") to deal")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(.bottom, stage.pick(tall: 24, wide: 14))
    }
}

private struct SeatCard: View {
    let player: Player?
    let index: Int
    /// Whether the chairs are paired off, which is what decides their colour.
    var teams = false
    var height: CGFloat = 118
    /// Given when this chair is the host's to fill with a bot, and to empty again.
    var seatBot: (() -> Void)?
    /// Given when a friend can still be asked to this chair, meaning an invited table with
    /// an invitation left to send. Nearby tables have none.
    var inviteFriend: (() -> Void)?
    /// Given at a table of ours, whose chair is four letters and a link away from anybody.
    var shareCode: Relay.Table?
    /// Given at a table of ours, for the friend who is on Game Center and would rather be
    /// asked by name than sent a code.
    var inviteByName: (() -> Void)?
    var sendBotAway: (() -> Void)?

    /// Whether this empty chair has anything to offer beyond the bot.
    private var asksWho: Bool { inviteFriend != nil || shareCode != nil || inviteByName != nil }

    @ViewBuilder var body: some View {
        if let player {
            takenChair(player)
        } else if let seatBot {
            // With a friend still invitable the chair asks which. With only the bot on
            // offer it stays the one tap it has always been.
            if asksWho {
                Menu { fillMenu(seatBot: seatBot) } label: { emptyChair("Fill this seat") }
                    .buttonStyle(.plain)
            } else {
                Button(action: seatBot) { emptyChair("Add a bot") }
                    .buttonStyle(.plain)
            }
        } else {
            waitingChair
        }
    }

    private func takenChair(_ player: Player) -> some View {
        VStack(spacing: 8) {
            PlayerBadge(name: player.name, isBot: player.isBot,
                        tint: Palette.seat(index, teams: teams), size: 40,
                        mark: SeatMark(player), cornice: Cornice(player),
                        livery: SeatLivery(player))
            Text(player.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(Palette.onTable)
            if player.isBot { BotTag() }
        }
        .frame(width: 88, height: height)
        .glassPanel(radius: GlassRadius.control)
        .overlay(alignment: .topTrailing) {
            if let sendBotAway { RemoveBotButton(action: sendBotAway) }
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    /// Every way this table has of filling one chair.
    @ViewBuilder private func fillMenu(seatBot: @escaping () -> Void) -> some View {
        if let shareCode {
            ShareLink(item: shareCode.link,
                      subject: Text("A game of Scopa"),
                      message: Text("Join my table of Scopa — the code is \(shareCode.code)")) {
                Label("Send the code", systemImage: "square.and.arrow.up")
            }
        }
        if let inviteByName {
            Button { inviteByName() } label: {
                Label("Invite a Game Center friend", systemImage: "person.2.fill")
            }
        }
        if let inviteFriend {
            Button { inviteFriend() } label: {
                Label("Invite a friend", systemImage: "paperplane.fill")
            }
        }
        Button { seatBot() } label: {
            Label("Add a bot", systemImage: "cpu")
        }
    }

    /// A chair somebody has accepted but not yet taken.
    private var waitingChair: some View {
        VStack(spacing: 6) {
            Text("·").font(.system(size: 22))
            Text("Waiting").font(.system(size: 13))
        }
        .foregroundStyle(Palette.onTableSoft)
        .frame(width: 88, height: height)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Palette.onTable.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }
    }

    /// The dashed outline of a chair nobody is in yet, under whatever it offers to do.
    private func emptyChair(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Palette.onTable)
        .frame(width: 88, height: height)
        .contentShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Palette.goldLight.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }
    }
}

/// The little cross that stands a bot back up, on the corner of its chair.
private struct RemoveBotButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(width: 22, height: 22)
                .background(Palette.terracotta.opacity(0.9), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send this bot away")
        .offset(x: 7, y: -7)
    }
}

/// Sets how many points win the game. Only the host can move it.
struct ScoreStepper: View {
    let value: Int
    var enabled = true
    let change: (Int) -> Void

    private var range: ClosedRange<Int> { GameConfiguration.targetRange }

    var body: some View {
        HStack(spacing: 12) {
            button("minus", to: value - 1)
            Text("\(value)")
                .font(.display(28))
                .foregroundStyle(Palette.onTable)
                .frame(minWidth: 42)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: value)
            button("plus", to: value + 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassCapsule()
        .opacity(enabled ? 1 : 0.5)
    }

    private func button(_ symbol: String, to next: Int) -> some View {
        Button { change(next) } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.terracotta)
        .disabled(!enabled || !range.contains(next))
        .opacity(range.contains(next) ? 1 : 0.3)
    }
}

private struct ModeTab: View {
    /// A key, not a string: `Text` only looks a value up in the catalogue when it is given
    /// one, and these tabs used to sit in English on an otherwise French screen.
    let title: LocalizedStringKey
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Palette.cream : Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 40)
                .glass(selected ? .riviera(tint: Palette.terracotta.opacity(0.8), interactive: true) : .identity,
                             in: .rect(cornerRadius: GlassRadius.chip))
                .contentShape(.rect(cornerRadius: GlassRadius.chip))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: selected)
    }
}
