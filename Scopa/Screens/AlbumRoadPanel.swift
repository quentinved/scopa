import ScopaCore
import ScopaRewards
import SwiftUI

/// The album's road: a stop every ten cards found across the volumes, each paid once.
///
/// Drawn as the stretch the open volume is on, three coins and a pack at its end, the way a
/// ranked division's road sits on its bar. A stop passed keeps its mark, dimmed. The stop
/// just paid stays lit with a line saying what it paid until the page is closed.
struct AlbumRoadPanel: View {
    let book: AlbumBook
    let purse: PurseStore
    /// Something is up over the page. A stop is paid once it has gone, so it is seen.
    var holding = false

    @Environment(\.tableFelt) private var felt
    @State private var paid: AlbumRoadPayout.Paid?
    @State private var rung = 0

    private var found: Int { book.foundInAll }

    /// The first card of the stretch on show: the paid stop's, or the next stop's.
    private var start: Int {
        let anchor = paid?.stop ?? min(found + 1, AlbumRoad.length)
        return (anchor - 1) / Album.size * Album.size
    }

    private var progress: Double { min(max(Double(found - start) / Double(Album.size), 0), 1) }
    private var stops: [Int] { AlbumRoad.stops.filter { $0 > start && $0 <= start + Album.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Caption(text: "Every ten cards")
                Spacer(minLength: 0)
                Text("\(found) of \(AlbumRoad.length)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            track
            AlbumRoadLine(found: found, paid: paid)
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
        .sensoryFeedback(Haptic.prize, trigger: rung)
        .task(id: [found, holding ? 1 : 0, purse.isReady ? 1 : 0]) { await settle() }
    }

    // MARK: The bar

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 18
            ZStack(alignment: .topLeading) {
                bar.frame(width: width).position(x: width / 2, y: 9)
                ForEach(stops, id: \.self) { stop in
                    let x = width * Double(stop - start) / Double(Album.size)
                    AlbumRoadStop(stop: stop, passed: found >= stop, lit: paid?.stop == stop, rung: rung)
                        .position(x: min(x, proxy.size.width - 9), y: 9)
                    Text(verbatim: "\(stop)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.onTableSoft)
                        .position(x: min(x, proxy.size.width - 9), y: 27)
                }
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private var bar: some View {
        Capsule()
            .fill(felt.shade(0.45))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Palette.goldSheen)
                        .frame(width: max(proxy.size.width * progress, progress > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
            .animation(.snappy, value: progress)
    }

    // MARK: Paying

    private func settle() async {
        #if DEBUG
        if let shown = DebugLaunch.albumMilestone {
            guard paid == nil else { return }
            try? await Task.sleep(for: .milliseconds(600))
            await announce(.init(stop: shown.stop, prize: AlbumRoad.prize(at: shown.stop), isCatchUp: shown.late))
            return
        }
        #endif
        guard !holding, let fresh = await AlbumRoadPayout.settle(book: book, purse: purse) else { return }
        try? await Task.sleep(for: .milliseconds(350))
        await announce(fresh)
    }

    /// Turns the bar to the stop's stretch, then rings it once the marks are there to ring.
    private func announce(_ fresh: AlbumRoadPayout.Paid) async {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { paid = fresh }
        try? await Task.sleep(for: .milliseconds(200))
        rung += 1
        if case .pack = fresh.prize { Audio.shared.play(.purchase) } else { Audio.shared.play(.denaro) }
    }
}

/// One stop on the bar: a coin, or the gift at a volume's end. Passed, it dims; just paid,
/// it rises once with a ring and settles.
private struct AlbumRoadStop: View {
    let stop: Int
    let passed: Bool
    let lit: Bool
    let rung: Int

    var body: some View {
        mark
            .opacity(passed && !lit ? 0.45 : 1)
            .saturation(passed && !lit ? 0.2 : 1)
            .background {
                if lit {
                    // Starts and ends spent, so it is only ever seen on its way out.
                    Circle().strokeBorder(Palette.goldLight, lineWidth: 1.5)
                        .keyframeAnimator(initialValue: 1.0, trigger: rung) { ring, value in
                            ring.scaleEffect(1 + value * 1.4).opacity(1 - value)
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(0, duration: 0.01)
                                CubicKeyframe(1, duration: 0.7)
                            }
                        }
                }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: rung) { view, scale in
                view.scaleEffect(lit ? scale : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.7, duration: 0.22)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
    }

    @ViewBuilder private var mark: some View {
        switch AlbumRoad.prize(at: stop) {
        case .denari: DenariMark(size: 15)
        case .pack:
            Image(systemName: "gift.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.goldLight)
                .frame(width: 18, height: 18)
        }
    }
}
