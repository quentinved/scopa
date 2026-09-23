import SwiftUI

extension View {
    /// Plays a sound when something changes, shaped like `.sensoryFeedback` so the two
    /// read as one line. Return `nil` to keep a change silent.
    func sound<T: Equatable>(trigger: T, _ choose: @escaping (T, T) -> Sound?) -> some View {
        onChange(of: trigger) { old, new in
            guard let sound = choose(old, new) else { return }
            Audio.shared.play(sound)
        }
    }

    /// The same, for a change that always plays the same sound.
    func sound<T: Equatable>(_ sound: Sound, trigger: T) -> some View {
        onChange(of: trigger) { _, _ in Audio.shared.play(sound) }
    }

    /// The loop that plays while this view is up. Asking for the track already on is
    /// free, so a screen can state it on every appearance.
    func score(_ track: Track?) -> some View {
        onAppear { Audio.shared.music(track) }
    }
}
