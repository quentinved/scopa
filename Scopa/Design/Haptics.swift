import SwiftUI

/// One feedback vocabulary for the whole app, kept soft for long sessions.
///
/// A sweep and a turn arriving need more than one tap, so they live in `Rumble`.
enum Haptic {
    /// A card picked up or put back.
    static let pick: SensoryFeedback = .selection
    /// Your own card landing on the table.
    static let play: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.55)
    /// Cards coming your way.
    static let take: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.85)
    /// Somebody else's cards moving. Felt, but only just.
    static let theirTake: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.4)
    /// The seven of coins changing hands, whichever side takes it.
    static let settebello: SensoryFeedback = .impact(weight: .heavy, intensity: 0.7)
    /// One line of a summary arriving.
    static let step: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.35)
    /// Your turn: firmer than any card landing, so a phone on the table is felt.
    static let yourTurn: SensoryFeedback = .impact(weight: .medium, intensity: 0.9)
    /// The winner's name at the end of a game.
    static let reveal: SensoryFeedback = .success
    /// A pack coming apart in your hands.
    static let tear: SensoryFeedback = .impact(weight: .heavy, intensity: 0.85)
    /// An ordinary card turned over out of a pack.
    static let turn: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.5)
    /// Something out of a pack that was worth waiting for.
    static let prize: SensoryFeedback = .success
}
