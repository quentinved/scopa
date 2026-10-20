import SwiftUI
import UIKit

extension View {
    /// Asks for an update when the App Store has a newer Scopa. Only over a clear lobby:
    /// `isClear` is the lobby's word that nothing of its own is up, and the card also waits
    /// for the house's arrival moment, the league ceremony and anything presented at all.
    /// `isPresented` is the lobby's, so its other news knows the card is up.
    func storeUpdate(isPresented: Binding<Bool>, isClear: Bool) -> some View {
        modifier(StoreUpdateHost(isPresented: isPresented, isClear: isClear))
    }
}

private struct StoreUpdateHost: ViewModifier {
    @Binding var isPresented: Bool
    let isClear: Bool

    @State private var versions = StoreVersion()
    @State private var isReleaseMomentUp = false
    /// Once per visit to the lobby, which a pretended version would otherwise not keep to.
    @State private var hasAsked = false
    @Environment(LadderCeremony.self) private var ceremony: LadderCeremony?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var mayAsk: Bool {
        !hasAsked && isClear && !isReleaseMomentUp && ceremony?.showing == nil
            && scenePhase == .active && versions.offer() != nil
    }

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ReleaseMomentIsUp.self) { isReleaseMomentUp = $0 }
            .task { await versions.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await versions.refresh() } }
            }
            // After the gift and the league ceremony have had their turn: they ask 2 s and
            // 1.2 s in. A sheet still up from elsewhere is waited out.
            .task(id: mayAsk) {
                guard mayAsk else { return }
                try? await Task.sleep(for: .seconds(3))
                while Self.isSomethingPresented, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                }
                guard !Task.isCancelled, versions.offer() != nil else { return }
                hasAsked = true
                versions.markShown()
                isPresented = true
            }
            .confirmation(isPresented: $isPresented) { card }
    }

    private var card: Confirmation? {
        guard let version = versions.offer() ?? versions.latest else { return nil }
        return Confirmation(Text("A new Scopa is out"),
                            message: Text("Version \(version) is waiting for you on the App Store."),
                            actions: [
            .init(title: Text("Update"), role: .primary) { openURL(StoreVersion.storeURL) },
            .init(title: Text("Later"), role: .cancel) { versions.later() },
        ])
    }

    /// Whether anything is presented over the app: a sheet, a cover, Game Center's own.
    private static var isSomethingPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .contains { $0.presentedViewController != nil }
    }
}
