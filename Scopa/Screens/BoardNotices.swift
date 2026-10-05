import SwiftUI

/// A board with nothing to rank on it: what happened, and the way on where there is one.
/// Shared by the season's board and the campaign's.
struct BoardMessage: View {
    let symbol: String
    var title: LocalizedStringKey? = nil
    let detail: LocalizedStringKey
    var action: (LocalizedStringKey, () -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.onTable)
            }
            Text(detail)
                .font(.system(size: title == nil ? 15 : 13))
                .foregroundStyle(title == nil ? Palette.onTable : Palette.onTableSoft)
            if let action { BoardLink(label: action.0, action: action.1).padding(.top, 4) }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 50)
    }
}

/// A board's text button, in gold.
struct BoardLink: View {
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.goldLight)
    }
}

/// Why a friends' tab has nobody on it when Game Center is the reason, and the way out.
struct FriendsTrouble: View {
    let problem: FriendsProblem
    let openSettings: () -> Void
    let retry: () -> Void

    var body: some View {
        switch problem {
        case .signedOut:
            BoardMessage(symbol: "person.crop.circle.badge.questionmark", title: "Sign in to Game Center to see your friends",
                         detail: "Needs Game Center, which is signed in to from the iPhone's Settings.")
        case .denied:
            BoardMessage(symbol: "lock", detail: "Scopa is not allowed to see your friends. Turn it on in the iPhone's Settings, under Game Center.",
                         action: ("Open Settings", openSettings))
        case .restricted:
            BoardMessage(symbol: "lock", detail: "Friend lists are turned off on this device. Screen Time settings can turn them back on.")
        case .unavailable:
            BoardMessage(symbol: "exclamationmark.triangle", detail: "Your Game Center friends could not be loaded just now.",
                         action: ("Try again", retry))
        }
    }
}
