import SwiftUI

/// The clock for the few things that move on their own: a metal rim's turning light, a
/// burst of rays, a trophy breathing.
///
/// Thirty ticks a second rather than `repeatForever`, which runs at the display's full 120
/// for as long as the view lives and keeps the whole screen compositing under its glass. A
/// slow turn or a breath looks the same at thirty and costs a quarter of the frames.
///
/// Moves for a spell each time it comes into view, then rests. A light left turning for as
/// long as a screen stays open turns mostly for nobody, and every tick redraws the screen.
/// Stopped as well while it is scrolled out of sight, covered by a sheet, or the app is not
/// in front. Given a `period`, it rests at the end of a cycle, where the content is still.
///
/// Hands the content the time in seconds, or a still 0 under Reduce Motion.
struct AmbientClock<Content: View>: View {
    var period: TimeInterval? = nil
    @ViewBuilder let content: (TimeInterval) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isUnderSheet) private var isUnderSheet
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = true
    @State private var reading = Reading()

    /// How long it moves each time it comes into view, before running on to a cycle's end.
    static var spell: TimeInterval { 12 }

    private var isSeen: Bool {
        !reduceMotion && !isUnderSheet && isOnScreen && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isSeen || reading.stoppedAt != nil)) { timeline in
            content(reduceMotion ? 0 : reading.time(at: timeline.date))
        }
        .reportsOnScreen(into: $isOnScreen)
        .task(id: isSeen) { await moveForASpell() }
    }

    private func moveForASpell() async {
        guard isSeen else { return }
        // Picks up from where it rested, so nothing jumps.
        if let stopped = reading.stoppedAt { reading = Reading(value: reading.time(at: stopped)) }
        var end = reading.time(at: .now) + Self.spell
        if let period { end = (end / period).rounded(.up) * period }
        try? await Task.sleep(for: .seconds(end - reading.time(at: .now)))
        guard !Task.isCancelled else { return }
        reading.stoppedAt = reading.from.addingTimeInterval(end - reading.value)
    }

    /// The clock's time: `value` at the moment `from`, running on from there until it stops.
    /// Starts on the wall clock, so two clocks that appear together move together.
    private struct Reading {
        var value = Date.now.timeIntervalSinceReferenceDate
        var from = Date.now
        var stoppedAt: Date?

        func time(at date: Date) -> TimeInterval {
            value + (stoppedAt ?? date).timeIntervalSince(from)
        }
    }
}

extension TimeInterval {
    /// How far through a cycle of `period` seconds this moment is, from 0 up to 1.
    func cycle(of period: TimeInterval) -> Double {
        (self / period).truncatingRemainder(dividingBy: 1)
    }
}

extension EnvironmentValues {
    /// The page is covered by a sheet, so nothing on it needs to move.
    @Entry var isUnderSheet = false
}

extension View {
    /// Whether any of the view lies inside the scroll views round it, kept up to date as
    /// they scroll. Always true outside a scroll view.
    func reportsOnScreen(into isOnScreen: Binding<Bool>) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            let own = CGRect(origin: .zero, size: proxy.size)
            return [Axis.vertical, .horizontal].allSatisfy { axis in
                proxy.bounds(of: .scrollView(axis: axis))?.intersects(own) ?? true
            }
        } action: { isOnScreen.wrappedValue = $0 }
    }
}
