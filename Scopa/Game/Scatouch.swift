import Foundation
import Observation

/// The quick game's god mode: every hand face up, the deck in order, your own cards picked
/// from it, and the bots' moves made for them. Unlocked by a phrase typed in the shop's code
/// field and kept on this phone: never synced, never sent. A game played with it pays nothing.
@MainActor
@Observable
final class Scatouch {
    static let shared = Scatouch()

    private static let unlockedKey = "scatouch.unlocked"
    private static let onKey = "scatouch.on"
    private static let botsKey = "scatouch.playsForBots"

    /// The phrase has been typed on this phone, which is what puts the switch in the settings.
    private(set) var isUnlocked: Bool {
        didSet { UserDefaults.standard.set(isUnlocked, forKey: Self.unlockedKey) }
    }

    /// Whether the next quick game is dealt with it on.
    var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: Self.onKey) }
    }

    /// Whether each bot waits for the player to make its move. Off, they play as usual.
    var playsForBots: Bool {
        didSet { UserDefaults.standard.set(playsForBots, forKey: Self.botsKey) }
    }

    private init() {
        let unlocked = UserDefaults.standard.bool(forKey: Self.unlockedKey)
        isUnlocked = unlocked
        isOn = unlocked && UserDefaults.standard.bool(forKey: Self.onKey)
        playsForBots = UserDefaults.standard.bool(forKey: Self.botsKey)
    }

    /// The phrase, typed: the first time it unlocks and turns on, after that it flips the
    /// switch. Says whether it is now on.
    func answerPhrase() -> Bool {
        if isUnlocked {
            isOn.toggle()
        } else {
            isUnlocked = true
            isOn = true
        }
        return isOn
    }
}
