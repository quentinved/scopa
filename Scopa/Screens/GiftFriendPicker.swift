import SwiftUI

/// Who a spare card goes to: the Game Center friends who play Scopa, by name.
///
/// With nobody to show it says why and offers the way out, as the duo's partner picker does.
struct GiftFriendPicker: View {
    let friends: [GiftFriend]
    let problem: FriendsProblem?
    let retry: @MainActor @Sendable () -> Void
    let pick: (GiftFriend) -> Void

    @Environment(TableStore.self) private var store
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
            .navigationTitle("Who gets it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(Palette.goldLight)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var content: some View {
        if let problem {
            trouble(problem)
        } else if friends.isEmpty {
            explanation("Nobody to list yet. Only Game Center friends who play Scopa show up here.")
            Button("Find friends on Game Center") { store.showGameCenterFriends(done: retry) }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        } else {
            explanation("It waits for them in their album the next time they open Scopa.")
            VStack(spacing: 0) {
                ForEach(friends) { friend in
                    Button { pick(friend) } label: { row(friend) }
                        .buttonStyle(.plain)
                    if friend != friends.last { Rule() }
                }
            }
            .glassPanel(radius: GlassRadius.control)
        }
    }

    private func row(_ friend: GiftFriend) -> some View {
        HStack(spacing: 12) {
            SeatBadge(name: friend.name, tint: Palette.seat(2), size: 34)
            Text(verbatim: friend.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            Spacer(minLength: 0)
            Image(systemName: "gift").foregroundStyle(Palette.terracotta)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Why there is no list, and the way out of it.
    @ViewBuilder private func trouble(_ problem: FriendsProblem) -> some View {
        switch problem {
        case .signedOut:
            explanation("Sign in to Game Center to give a card.")
            Button("Sign in") { retry() }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        case .denied:
            explanation("Scopa needs to see your Game Center friends to give them a card. Allow it in Settings, under Game Center.")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        case .restricted:
            explanation("Friend lists are turned off on this device. Screen Time settings can turn them back on.")
        case .unavailable:
            explanation("Your Game Center friends could not be loaded just now.")
            Button("Try again") { retry() }
                .buttonStyle(FilledButtonStyle(tint: Palette.linen, foreground: Palette.ink, minHeight: 50))
        }
    }

    private func explanation(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.onTable)
            .fixedSize(horizontal: false, vertical: true)
    }
}
