import Foundation

/// Which taps a reveal listens to.
///
/// A card takes about half a second to go over, and a tap inside that half second was meant
/// for the card going over: a tap to hurry it that arrived just after its wait ran out on
/// its own, or the second half of a double tap. Read as "next", it threw the card away
/// before anybody had seen it. So each beat a reveal moves on closes the door behind it for
/// a moment, and a tap before it opens again is dropped rather than queued.
///
/// Measured against the clock rather than an animation's completion, so nothing has to run
/// for it to open again, and a reveal left alone costs nothing.
struct RevealTaps {
    private var quietUntil = Date.distantPast

    /// Whether a tap now moves the reveal on.
    var isOpen: Bool { Date.now >= quietUntil }

    /// Something has just started going over, by a tap or by its own wait. Nothing taps
    /// past it until it has landed face up.
    mutating func turned(reduceMotion: Bool) {
        hold(reduceMotion ? 0.25 : 0.5)
    }

    /// The next thing has just been put down. The tail of a double tap does not hurry it
    /// over before it has had a moment face down.
    mutating func moved() {
        hold(0.3)
    }

    private mutating func hold(_ seconds: TimeInterval) {
        quietUntil = max(quietUntil, Date.now.addingTimeInterval(seconds))
    }
}
