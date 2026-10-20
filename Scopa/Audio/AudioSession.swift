import AVFoundation
import os

/// The one place the app's audio session is shaped, claimed and let go.
///
/// Every shape mixes with other apps, so music the player already has on, from Spotify or
/// anywhere else, is played over and never stopped. Both alternatives stop it the moment
/// anything claims the session: the default category, solo ambient, which is what the
/// session is until the app says otherwise, and `.playback` without `.mixWithOthers`.
///
/// `nonisolated` because the claim is made off the main actor, where it is slow.
nonisolated enum AudioSession {
    enum Shape: String {
        /// The game: heard with the ring switch off, as the player asked, over their music.
        case game
        /// An ad with its sound on: silenced by the ring switch, as the ads SDK's own handling
        /// was, but under the player's music rather than in place of it.
        case ad
    }

    /// Sets the shape without claiming the session, so nothing is heard and nobody is stopped.
    static func shape(_ shape: Shape, why: String) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch shape {
            case .game: try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            case .ad: try session.setCategory(.ambient, mode: .default)
            }
        } catch {
            Log.audio.error("Session not shaped for \(why, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        Log.audio.info("Session \(shape.rawValue, privacy: .public) for \(why, privacy: .public): \(describe(session), privacy: .public)")
    }

    /// Shapes the session and claims it. Refused when the shape did not take: a claim on a
    /// session that does not mix is exactly what stops the player's music.
    static func claim(_ shape: Shape, why: String) -> Bool {
        self.shape(shape, why: why)
        let session = AVAudioSession.sharedInstance()
        guard mixes(session) else {
            Log.audio.error("Session left unclaimed for \(why, privacy: .public): it would not mix")
            return false
        }
        do {
            try session.setActive(true)
            Log.audio.info("Session claimed for \(why, privacy: .public); others playing: \(session.isOtherAudioPlaying)")
            return true
        } catch {
            Log.audio.error("Session not claimed for \(why, privacy: .public): \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Lets the session go. Other apps are told, so one that did stop for something resumes.
    static func release(why: String) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            Log.audio.info("Session released for \(why, privacy: .public)")
        } catch {
            Log.audio.error("Session not released for \(why, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    /// Whether the player has audio of their own on. The hint is Apple's signal for a game to
    /// drop its soundtrack and keep its effects; `isOtherAudioPlaying` also catches audio
    /// that mixes, as the app always checked before starting a loop.
    static var playerHasMusic: Bool {
        let session = AVAudioSession.sharedInstance()
        return session.secondaryAudioShouldBeSilencedHint || session.isOtherAudioPlaying
    }

    /// Ambient mixes without saying so in its options.
    private static func mixes(_ session: AVAudioSession) -> Bool {
        session.category == .ambient || session.categoryOptions.contains(.mixWithOthers)
    }

    private static func describe(_ session: AVAudioSession) -> String {
        "\(session.category.rawValue), options \(session.categoryOptions.rawValue), mixes \(mixes(session))"
    }
}
