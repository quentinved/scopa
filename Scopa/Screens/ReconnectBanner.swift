import SwiftUI
import ScopaCore
import ScopaRelay

/// What an online table says when the line to it is in trouble, over the table and the
/// waiting room alike, and what a wager table asks before an invitation walks out of it.
///
/// A line that is mending itself is a small capsule at the top, since it usually has before
/// anybody could read it. Anything that needs an answer is a card in the middle, over a shade
/// that keeps the cards from being played into a table that cannot hear them.
struct ReconnectBanner: View {
    let store: TableStore

    @Environment(\.tableFelt) private var felt
    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    private var connection: TableConnection { store.connection }

    var body: some View {
        ZStack {
            if store.route != .lobby, let link = connection.link {
                switch connection.shown {
                case .steady: EmptyView()
                case .reconnecting: mending.frame(maxHeight: .infinity, alignment: .top)
                case .lost: card(lost(link))
                case .hostAway(let name): card(waiting(for: name, link))
                case .hostGone(let name): card(gone(name, link))
                }
            }
            if store.invitationOverStake != nil { card(leavingStake) }
        }
        .animation(.easeInOut(duration: 0.25), value: connection.shown)
        .animation(.easeInOut(duration: 0.25), value: store.invitationOverStake?.id)
        .sound(trigger: connection.shown) { _, state in state == .steady || state == .reconnecting ? nil : .notice }
        #if DEBUG
        .task { DebugLaunch.applyReconnect(to: store) }
        #endif
    }

    /// The line is down and being remade: say so, and nothing more.
    private var mending: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Palette.cream).controlSize(.small)
            Text("Reconnecting…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.cream)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassCapsule(tint: Palette.ink.opacity(0.85))
        .padding(.top, stage.pick(tall: 60, wide: 46))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: What each state says

    private struct Words {
        var symbol: String
        var title: Text
        var message: Text
        var waits = false
        var actions: [Confirmation.Action]
    }

    private func lost(_ link: TableLink) -> Words {
        guard link.canReconnect else { return stopped(Text("Connection lost"), link) }
        return Words(symbol: "wifi.exclamationmark", title: Text("Connection lost"),
                     message: Text("Your seat is kept, and the house plays your cards until you are back."),
                     actions: [.init(title: Text("Reconnect")) { connection.reconnect() },
                               .init(title: Text("Leave the table"), role: .cancel) { store.leaveTable() }])
    }

    private func waiting(for name: String, _ link: TableLink) -> Words {
        let message = link.canReconnect
            ? Text("Their phone lost the table. The game picks up where it stopped as soon as they are back.")
            : Text("Their phone dropped off. Game Center is trying to bring them back.")
        return Words(symbol: "hourglass", title: Text("Waiting for \(name)"), message: message, waits: true,
                     actions: [.init(title: Text("Leave the table"), role: .cancel) { store.leaveWithoutHost() }])
    }

    private func gone(_ name: String, _ link: TableLink) -> Words {
        guard link.hostCanReturn, link.canReconnect else { return stopped(Text("\(name) dropped off"), link) }
        return Words(symbol: "person.crop.circle.badge.questionmark", title: Text("\(name) has not come back"),
                     message: Text("Their phone has been gone a while. You can keep waiting, or leave the table."),
                     actions: [.init(title: Text("Keep waiting"), role: .plain) { connection.keepWaiting() },
                               .init(title: Text("Leave the table"), role: .cancel) { store.leaveWithoutHost() }])
    }

    /// An invitation said yes to mid-wager: taking it up leaves the stake behind.
    private var leavingStake: Words {
        Words(symbol: "envelope.open", title: Text("Leave this game?"), message: Text("Your stake stays on the table."),
              actions: [.init(title: Text("Leave"), role: .destructive) { store.leaveStakeForInvitation() },
                        .init(title: Text("Stay"), role: .cancel) { store.stayAtStake() }])
    }

    /// A table that cannot be walked back into, said plainly.
    private func stopped(_ title: Text, _ link: TableLink) -> Words {
        let message = link.carrier == .nearby
            ? Text("A nearby table cannot be picked up again once a phone drops, so this game stops here.")
            : Text("A Game Center table cannot be picked up again once a phone drops, so this game stops here.")
        return Words(symbol: "wifi.slash", title: title, message: message,
                     actions: [.init(title: Text("Back to the lobby")) { store.leaveWithoutHost() }])
    }

    // MARK: The card

    private func card(_ words: Words) -> some View {
        ZStack {
            // Taps stop here: a card played now would go nowhere.
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture {}
                .accessibilityHidden(true)
            VStack(spacing: 18) {
                Image(systemName: words.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                VStack(spacing: 8) {
                    words.title
                        .font(.display(26))
                        .foregroundStyle(Palette.onTable)
                    words.message
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.onTableSoft)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                if words.waits { ProgressView().tint(Palette.onTable) }
                VStack(spacing: 10) {
                    ForEach(words.actions) { button($0) }
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassPanel(tint: felt.shade(0.85))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    @ViewBuilder
    private func button(_ action: Confirmation.Action) -> some View {
        switch action.role {
        case .primary, .destructive:
            Button(action: action.run) { action.title }
                .buttonStyle(FilledButtonStyle(tint: Palette.gold, foreground: Palette.ink, minHeight: 50))
        case .plain:
            Button(action: action.run) { action.title }
                .buttonStyle(OutlineButtonStyle(minHeight: 50))
        case .cancel:
            Button(action: action.run) { action.title }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
    }
}
