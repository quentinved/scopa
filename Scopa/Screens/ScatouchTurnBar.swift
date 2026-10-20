import SwiftUI

/// In the action bar's place while a steered bot's cards wait for a pick: the button that
/// gives the bot its turn back. Picking a card swaps it for the usual play button.
struct ScatouchTurnBar: View {
    let name: String
    let height: CGFloat
    let letGo: () -> Void

    var body: some View {
        Button("Let \(name) play", action: letGo)
            .buttonStyle(OutlineButtonStyle(minHeight: height))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
