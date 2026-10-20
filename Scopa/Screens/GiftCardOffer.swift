import GameKit
import ScopaCore
import ScopaGameCenter
import ScopaRewards
import SwiftUI

/// Under a card lifted off the album: the way to give a spare of it to a friend.
///
/// Only a spare goes, one a day, and never the settebello; see `CardGift`. Nothing leaves the
/// album until the Worker has the gift, so every way it can fail says why and keeps the card.
struct GiftCardOffer: View {
    let card: Card
    let volume: Volume
    /// The page as it is shown, less what has already left it.
    let album: Album

    @Environment(TableStore.self) private var store
    @Environment(PurseStore.self) private var purse
    @Environment(CardGifts.self) private var gifts

    private enum Stage: Equatable { case idle, checking, sending, sent(String) }
    private enum Question { case give(GiftFriend), notOpen, offline, failed(GiftPost.Sent, GiftFriend) }

    @State private var stage = Stage.idle
    @State private var friends: [GiftFriend] = []
    @State private var problem: FriendsProblem?
    @State private var picksFriend = false
    @State private var picked: GiftFriend?
    @State private var asks = false
    @State private var question: Question?

    private var isDebugging: Bool { DebugLaunch.giftCard == card }

    /// The page, with a spare planted when `-giftCard` asked for this card.
    private var page: Album {
        guard isDebugging, album.spares(of: card) < 1 else { return album }
        return Album(counts: album.counts.merging([card: 2]) { max($0, $1) })
    }

    private var refusal: CardGift.Refusal? {
        CardGift.refusal(of: card, in: page, givenToday: gifts.givenToday(store.albumBook, today: store.today))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: stage)
            .sheet(isPresented: $picksFriend, onDismiss: askAboutPicked) {
                GiftFriendPicker(friends: friends, problem: problem, retry: { Task { await loadFriends() } }) {
                    picked = $0
                    picksFriend = false
                }
            }
            .confirmation(isPresented: $asks) { confirmation }
            .task {
                guard isDebugging else { return }
                // After the album's sheet and the lift: a sheet asked for mid-presentation is dropped.
                try? await Task.sleep(for: .seconds(1.5))
                await start()
            }
    }

    @ViewBuilder private var content: some View {
        switch (stage, refusal) {
        case (.sent(let name), _): GiftThanks(card: card, friend: name)
        case (_, nil): giveButton
        case (_, .givenToday?): note(Text("Today's gift has gone. Another tomorrow."))
        case (_, .settebello?) where page.spares(of: card) > 0: note(Text("The settebello is found, never given."))
        default: EmptyView()
        }
    }

    private var giveButton: some View {
        Button { Task { await start() } } label: {
            HStack(spacing: 8) {
                if stage == .idle {
                    Image(systemName: "gift.fill").foregroundStyle(Palette.terracotta)
                } else {
                    ProgressView().tint(Palette.onTable).controlSize(.small)
                }
                Text("Give to a friend")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.onTable)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassCapsule(tint: Palette.ink.opacity(0.55))
        }
        .buttonStyle(.plain)
        .disabled(stage != .idle)
    }

    private func note(_ text: Text) -> some View {
        text
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.onTableSoft)
            .multilineTextAlignment(.center)
    }

    // MARK: Asking

    /// Asks the Worker whether it takes gifts at all, then Game Center for the friends.
    private func start() async {
        guard stage == .idle else { return }
        stage = .checking
        defer { if stage == .checking { stage = .idle } }
        if isDebugging { return pretend() }
        switch await GiftPost.isOpen() {
        case false?: ask(.notOpen)
        case nil: ask(.offline)
        case true?:
            await loadFriends()
            picksFriend = true
        }
    }

    /// `-giftCard`: the made-up friends, and as far into the flow as it asked.
    private func pretend() {
        friends = DebugLaunch.giftFriends
        switch DebugLaunch.giftStep {
        case "confirm": ask(.give(friends[0]))
        case "sent": stage = .sent(friends[0].name)
        default: picksFriend = true
        }
    }

    private func loadFriends() async {
        do {
            friends = try await store.loadFriends()
                .map { GiftFriend(id: $0.gamePlayerID, name: $0.displayName) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            problem = nil
        } catch let error as GameCenterError {
            problem = FriendsProblem(error)
        } catch {
            problem = .unavailable(error.localizedDescription)
        }
    }

    private func askAboutPicked() {
        guard let friend = picked else { return }
        picked = nil
        ask(.give(friend))
    }

    private func ask(_ next: Question) {
        question = next
        asks = true
    }

    // MARK: Sending

    private func send(to friend: GiftFriend) {
        stage = .sending
        Task {
            var sent = GiftPost.Sent.sent
            if !isDebugging {
                sent = await gifts.give(card, from: volume, to: friend, day: store.today,
                                        book: store.albumBook, purse: purse)
            }
            guard sent == .sent else {
                stage = .idle
                ask(.failed(sent, friend))
                return
            }
            stage = .sent(friend.name)
        }
    }

    private var confirmation: Confirmation? {
        let ok = Confirmation.Action(title: Text("OK"), role: .cancel)
        switch question {
        case .give(let friend)?:
            return Confirmation(Text("Give it to \(friend.name)?"),
                                message: Text("Your spare \(card.rank.italianName) of \(Text(card.suit.name)) goes into their album. The one on your page stays. One gift a day."),
                                actions: [Confirmation.Action(title: Text("Give it")) { send(to: friend) },
                                          Confirmation.Action(title: Text("Not now"), role: .cancel)])
        case .notOpen?:
            return Confirmation(Text("Gifts are not open yet"),
                                message: Text("Scopa's server does not take them yet. Your card stays in your album."),
                                actions: [ok])
        case .offline?:
            return Confirmation(Text("You seem to be offline"),
                                message: Text("Your card stays in your album. Try again once you are connected."),
                                actions: [ok])
        case .failed(let sent, let friend)?:
            return Confirmation(GiftRefusals.title(sent, friend: friend.name),
                                message: GiftRefusals.message(sent, friend: friend.name), actions: [ok])
        case nil:
            return nil
        }
    }
}
