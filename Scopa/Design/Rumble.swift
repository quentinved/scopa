import CoreHaptics
import UIKit

/// Core Haptics patterns for the moments one tap cannot carry: your turn, a pile of cards
/// arriving, and a sweep.
///
/// `SensoryFeedback`, which is all `Haptic` offers, fires one canned tap, and one more soft
/// tap is lost among a game's worth of them. Falls back to repeated impact generators
/// where Core Haptics is unavailable (older iPhones, iPad, Mac).
@MainActor
final class Rumble {
    static let shared = Rumble()

    private var engine: CHHapticEngine?
    private var isBroken = false

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    /// Your turn: two soft swells. Smooth and blunt, so it cannot be mistaken for one of
    /// the taps a card makes, and carries to a phone lying face down.
    func yourTurn() {
        let beats: [Beat] = [
            Beat.swell(from: Self.firstSwell, duration: Self.swellLength, intensity: 0.95, sharpness: 0.1),
            Beat.swell(from: Self.secondSwell, duration: Self.swellLength, intensity: 0.95, sharpness: 0.1),
        ]
        let fallback: [UIImpactFeedbackGenerator.FeedbackStyle] = [.soft, .soft]
        play(beats, curves: [Self.envelope(at: [Self.firstSwell, Self.secondSwell], length: Self.swellLength)],
             fallback: fallback, gap: .milliseconds(320))
    }

    /// Where the two swells sit, and how long each runs.
    private static let firstSwell: TimeInterval = 0
    private static let secondSwell: TimeInterval = 0.32
    private static let swellLength: TimeInterval = 0.2

    /// Fades a continuous event up and back down. Held flat it is a buzz, which reads as
    /// something being wrong rather than as a roll.
    private static func envelope(at starts: [TimeInterval], length: TimeInterval) -> CHHapticParameterCurve {
        let points = starts.flatMap { start in
            [CHHapticParameterCurve.ControlPoint(relativeTime: start, value: 0),
             CHHapticParameterCurve.ControlPoint(relativeTime: start + length * 0.35, value: 1),
             CHHapticParameterCurve.ControlPoint(relativeTime: start + length * 0.62, value: 1),
             CHHapticParameterCurve.ControlPoint(relativeTime: start + length, value: 0)]
        }
        return CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: 0)
    }

    /// A pile of cards landing in front of you. Fired when the flight arrives, about a
    /// second after the move was made.
    func gather(count: Int) {
        let taps = min(max(count, 2), 4)
        let beats: [Beat] = (0..<taps).map { index in
            let rise = Float(index) * 0.12
            return Beat.transient(at: Double(index) * 0.06, intensity: 0.55 + rise, sharpness: 0.45)
        }
        let fallback: [UIImpactFeedbackGenerator.FeedbackStyle] = Array(repeating: .soft, count: taps)
        play(beats, fallback: fallback)
    }

    /// A card set down on the felt: one dull tap, well under a gathered pile. Quiet,
    /// because it is the game's commonest move. Somebody else's is quieter again.
    func lay(mine: Bool) {
        play([.transient(at: 0, intensity: mine ? 0.42 : 0.24, sharpness: 0.15)],
             fallback: [.soft])
    }

    /// A sweep: a brush that builds, a crack where the table comes up empty, and a roll
    /// that fades. Nothing else in the game builds, so it is known before the banner is
    /// read. Somebody else's is the same stroke at half weight, without the roll.
    func sweep(mine: Bool) {
        let level: Float = mine ? 1 : 0.45
        var beats: [Beat] = [
            .swell(from: 0, duration: Self.brush, intensity: 0.8 * level, sharpness: 0.2),
            .transient(at: Self.crack, intensity: level, sharpness: 0.85),
        ]
        if mine {
            beats.append(.swell(from: Self.roll, duration: Self.rollLength,
                                intensity: 0.55, sharpness: 0.1))
        }
        let fallback: [UIImpactFeedbackGenerator.FeedbackStyle] = mine
            ? [.light, .medium, .heavy]
            : [.light, .soft]
        play(beats, curves: [Self.sweepIntensity, Self.sweepSharpness],
             fallback: fallback, gap: .milliseconds(90))
    }

    /// Where a sweep's three parts sit. Half a second end to end, so it is over before
    /// the next card is played.
    private static let brush: TimeInterval = 0.24
    private static let crack: TimeInterval = 0.25
    private static let roll: TimeInterval = 0.3
    private static let rollLength: TimeInterval = 0.2

    /// The rise and fall of a sweep. Core Haptics dynamic parameters are not per event,
    /// so one curve has to cover the brush, the crack and the roll together.
    private static var sweepIntensity: CHHapticParameterCurve {
        curve(.hapticIntensityControl,
              [(0, 0), (0.1, 0.3), (0.19, 0.8), (crack, 1), (roll, 1), (roll + rollLength, 0)])
    }

    /// Dull under the brush, bright at the crack, dull again for the roll. Sharpness is
    /// what makes the crack read as an edge rather than a louder thump.
    private static var sweepSharpness: CHHapticParameterCurve {
        curve(.hapticSharpnessControl,
              [(0, -0.4), (0.19, 0.2), (crack, 0.3), (roll + 0.04, -0.6), (roll + rollLength, -0.6)])
    }

    private static func curve(_ parameter: CHHapticDynamicParameter.ID,
                              _ points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(
            parameterID: parameter,
            controlPoints: points.map { CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1) },
            relativeTime: 0)
    }

    // MARK: The engine

    private func play(_ beats: [Beat], curves: [CHHapticParameterCurve] = [],
                      fallback: [UIImpactFeedbackGenerator.FeedbackStyle],
                      gap: Duration = .milliseconds(110)) {
        guard supportsHaptics, !isBroken else { return knock(fallback, gap: gap) }
        do {
            let engine = try running()
            let pattern = try CHHapticPattern(events: beats.map(\.event), parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // One failure is enough: a phone that cannot play a pattern will not start to.
            isBroken = true
            knock(fallback, gap: gap)
        }
    }

    private func running() throws -> CHHapticEngine {
        if let engine {
            try engine.start()
            return engine
        }
        let engine = try CHHapticEngine()
        // Powers down between turns instead of holding the hardware awake for a whole
        // game. The `start()` above wakes it again in time.
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        engine.stoppedHandler = { _ in }
        try engine.start()
        self.engine = engine
        return engine
    }

    /// The coarse fallback: the same shape beaten out with impact generators. An impact
    /// cannot swell, so the softest style carries it at the pattern's spacing.
    private func knock(_ styles: [UIImpactFeedbackGenerator.FeedbackStyle], gap: Duration) {
        Task { @MainActor in
            for style in styles {
                UIImpactFeedbackGenerator(style: style).impactOccurred()
                try? await Task.sleep(for: gap)
            }
        }
    }

    /// One event of a pattern, in this file's terms rather than Core Haptics'.
    private enum Beat {
        case transient(at: TimeInterval, intensity: Float, sharpness: Float)
        case swell(from: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float)

        var event: CHHapticEvent {
            switch self {
            case .transient(let time, let intensity, let sharpness):
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ], relativeTime: time)
            case .swell(let time, let duration, let intensity, let sharpness):
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ], relativeTime: time, duration: duration)
            }
        }
    }
}
