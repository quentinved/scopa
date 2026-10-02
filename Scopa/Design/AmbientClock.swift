import SwiftUI

/// The clock for the few things that move on their own for as long as they are on screen:
/// a metal rim's turning light, a burst of rays, a trophy breathing.
///
/// Thirty ticks a second rather than `repeatForever`, which runs at the display's full 120
/// for as long as the view lives and keeps the whole screen compositing under its glass. A
/// slow turn or a breath looks the same at thirty and costs a quarter of the frames.
///
/// Hands the content the time in seconds, or a still 0 under Reduce Motion.
struct AmbientClock<Content: View>: View {
    @ViewBuilder let content: (TimeInterval) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            content(reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
        }
    }
}

extension TimeInterval {
    /// How far through a cycle of `period` seconds this moment is, from 0 up to 1.
    func cycle(of period: TimeInterval) -> Double {
        (self / period).truncatingRemainder(dividingBy: 1)
    }
}
