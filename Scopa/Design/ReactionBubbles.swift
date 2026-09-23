import SwiftUI
import ScopaCore

/// Reactions people send float up beside the table and fade out on their own.
struct ReactionBubbles: View {
    let store: TableStore

    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.screenSize) private var screenSize
    private var stage: Stage { Stage(heightClass, size: screenSize) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(store.reactions) { seen in
                Bubble(seen: seen) { store.forget(seen) }
            }
        }
        .padding(.trailing, 16)
        .padding(.top, stage.pick(tall: 96, wide: 62))
        .allowsHitTesting(false)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: store.reactions)
    }

    private struct Bubble: View {
        let seen: TableStore.SeenReaction
        let done: () -> Void

        @State private var shown = false

        var body: some View {
            VStack(alignment: .trailing, spacing: 1) {
                // Name above the line, not beside it: side by side they overflow a phone.
                Text(seen.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
                SaidLine(reaction: seen.reaction, size: 15)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassCapsule()
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .task {
                withAnimation(.spring(duration: 0.3)) { shown = true }
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut(duration: 0.3)) { shown = false }
                try? await Task.sleep(for: .milliseconds(320))
                done()
            }
        }
    }
}
