import SwiftUI

/// Over the summary of a ranked loss that broke a run: a short video and the run carries on.
///
/// The game stays lost and its points stay gone; only the run comes back, and a run can be
/// carried once. Drawn like `Confirmation`'s card, with the run's flames on top: out while
/// it is asked, caught again once it is kept.
struct KeepRunCard: View {
    enum Phase: Equatable {
        case offered
        case watching
        /// The tap found no video to show.
        case noVideo
        /// The video was watched but the ladder could not be reached. Asked again without one.
        case unsent
        case kept
    }

    let run: Int
    let phase: Phase
    let keep: () -> Void
    let letGo: () -> Void

    @Environment(\.tableFelt) private var felt
    @State private var isIn = false

    var body: some View {
        ZStack {
            Color.black.opacity(isIn ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { if phase == .offered || phase == .noVideo { letGo() } }
                .accessibilityHidden(true)
            if isIn {
                card.transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.34, bounce: 0.22)) { isIn = true } }
        .sensoryFeedback(.impact(weight: .light), trigger: isIn) { _, now in now }
        .sensoryFeedback(.success, trigger: phase) { _, now in now == .kept }
    }

    private var card: some View {
        VStack(spacing: 20) {
            flames
            VStack(spacing: 8) {
                Text(phase == .kept ? "Run kept" : "Save your run?")
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            if phase != .kept { buttons }
        }
        .padding(22)
        .frame(maxWidth: 360)
        .glassPanel(tint: felt.shade(0.85))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { if phase != .watching { letGo() } }
    }

    private var message: LocalizedStringKey {
        switch phase {
        case .offered, .watching: "\(run) wins in a row, ended by this game. Watch a short ad and the run carries on. The game still counts as lost."
        case .noVideo: "No video to show right now. Try again in a moment."
        case .unsent: "The ladder could not be reached. Your video counts: try again, no second ad."
        case .kept: "\(run) in a row, and your next win pays on it."
        }
    }

    /// One flame a win, out while the run is lost and caught again once it is kept.
    private var flames: some View {
        let lit = phase == .kept
        return HStack(spacing: 3) {
            ForEach(0..<min(run, Self.most), id: \.self) { index in
                Image(systemName: lit ? "flame.fill" : "flame")
                    .font(.system(size: 24 + CGFloat(index) * 2, weight: .semibold))
                    .foregroundStyle(lit ? Palette.goldLight : Palette.onTableSoft.opacity(0.6))
                    .scaleEffect(lit ? 1 : 0.86, anchor: .bottom)
                    .animation(.spring(duration: 0.45, bounce: 0.55).delay(Double(index) * 0.06), value: lit)
            }
            if run > Self.most {
                Text(verbatim: "+\(run - Self.most)")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(lit ? Palette.goldLight : Palette.onTableSoft)
            }
        }
        .accessibilityHidden(true)
    }

    private static let most = 5

    private var buttons: some View {
        VStack(spacing: 10) {
            Button(action: keep) {
                HStack(spacing: 8) {
                    if phase == .watching {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Image(systemName: phase == .unsent ? "arrow.clockwise" : "play.rectangle.fill")
                    }
                    Text(phase == .unsent ? "Try again" : "Watch an ad, keep the run")
                }
            }
            .buttonStyle(FilledButtonStyle(tint: Palette.gold, foreground: Palette.ink, minHeight: 50))
            .disabled(phase == .watching)
            Button(action: letGo) { Text("Let it go") }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
                .disabled(phase == .watching)
        }
    }
}

#if DEBUG
/// `-keepRun 4` puts the offer up over the cloth on launch, and plays it through on a tap:
/// the video, then the run caught again.
struct KeepRunRehearsal: View {
    let run: Int
    @State private var phase: KeepRunCard.Phase? = .offered

    var body: some View {
        ZStack {
            TableGround().ignoresSafeArea()
            if let phase {
                KeepRunCard(run: run, phase: phase, keep: keep) { self.phase = nil }
            }
        }
    }

    private func keep() {
        phase = .watching
        Task {
            try? await Task.sleep(for: .seconds(1))
            phase = .kept
        }
    }
}
#endif
