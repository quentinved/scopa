import Foundation
import Observation
import ScopaRewards
import SwiftUI

/// Everything the app knows about ads: whether they are on, which gateway is live, whether
/// consent has been settled, and the pacing so far. Views read this and never the gateway.
@MainActor
@Observable
final class AdsStore {
    /// False once the player has removed ads. Stored on the device.
    private(set) var adsAreOn: Bool

    private(set) var gateway: any AdsGateway

    let consent = AdsConsent()

    /// When an ad may interrupt, and how often.
    private var policy = AdPolicy()

    static let sweptKey = "adsAreSwept"

    /// Whether the passphrase has ever been entered on this device. Anything else the
    /// phrase unlocks reads this rather than asking for it again.
    static var wasSwept: Bool { UserDefaults.standard.bool(forKey: sweptKey) }

    init(adsAreOn: Bool? = nil) {
        #if DEBUG
        // `-noAds` removes ads for this launch only, writing nothing down.
        let swept = DebugLaunch.hidesAds
        #else
        let swept = false
        #endif
        let on = !swept && (adsAreOn ?? !UserDefaults.standard.bool(forKey: Self.sweptKey))
        self.adsAreOn = on
        self.gateway = on ? Self.liveGateway() : SweptAds()
    }

    private static func liveGateway() -> any AdsGateway {
        #if DEBUG
        if DebugLaunch.usesPlaceholderAds { return PlaceholderAds() }
        #endif
        return GoogleAds()
    }

    // MARK: Getting going

    /// Settles consent, then lets the gateway start loading. Called once, from the top of
    /// the app.
    func start() async {
        guard adsAreOn else { return }
        #if DEBUG
        // The placeholder has nothing to consent to and no SDK to start.
        if DebugLaunch.usesPlaceholderAds {
            consentWasSkipped = true
            gateway.begin()
            return
        }
        #endif
        await consent.gather()
        guard consent.isReady else { return }
        gateway.begin()
        // The shop may have asked for a rewarded ad before the SDK was up.
        if wantsReward { gateway.preloadRewarded() }
        #if DEBUG
        if DebugLaunch.showsAdInspector { GoogleAds.presentInspector() }
        #endif
    }

    #if DEBUG
    private var consentWasSkipped = false
    #endif

    /// Ads may be drawn: they are on and consent is settled.
    var isReady: Bool {
        guard adsAreOn else { return false }
        #if DEBUG
        if consentWasSkipped { return true }
        #endif
        return consent.isReady
    }

    /// The banner strip shows in the lobby only, never under the table.
    func showsBanner(on route: TableStore.Route) -> Bool {
        isReady && route == .lobby
    }

    // MARK: The interruption

    /// Called when a round ends, so the ad is warm by the time the game is.
    func prepareForEndOfGame() {
        guard adsAreOn else { return }
        gateway.preloadInterstitial()
    }

    /// A game ended and another was dealt at once. It counts towards the pacing, but
    /// there is no exit to put an ad on.
    func countFinishedGame() {
        guard adsAreOn else { return }
        policy.finishedGame()
    }

    /// A game is over and the player is leaving the table. `AdPolicy` decides whether an
    /// ad follows.
    func endOfGame(_ ending: GameEnding) async {
        guard adsAreOn else { return }
        policy.finishedGame()
        guard policy.allowsInterstitial(after: ending) else { return }
        // Counted only once the network confirms it appeared, so a failed presentation
        // does not spend the day's allowance.
        if await gateway.showInterstitial() { policy.showedInterstitial() }
    }

    #if DEBUG
    /// `-showAd` ignores the pacing rules and waits for a fill. Ten seconds for consent
    /// and the SDK, then ten more for an ad, and it gives up rather than hanging.
    func showInterstitialForDebugging() async {
        for _ in 0..<50 {
            if isReady { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        gateway.begin()
        gateway.preloadInterstitial()
        for _ in 0..<50 {
            if await gateway.showInterstitial() { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
    #endif

    // MARK: The one they choose

    /// Warms the opt-in ad. Called when the shop opens, the only place it is offered.
    func prepareReward() {
        guard adsAreOn else { return }
        wantsReward = true
        gateway.preloadRewarded()
    }

    /// The opt-in ad has been asked for once, so `start()` warms it as soon as the SDK is
    /// up. A game started at launch reaches its summary before consent has settled.
    private var wantsReward = false

    /// What one watched ad is worth.
    var reward: Denari { AdPolicy.reward }

    /// How many opt-in ads are left today. Zero hides the offer.
    var rewardsLeftToday: Int {
        isReady ? policy.rewardsLeftToday() : 0
    }

    /// Whether to show the offer: ads on, consent settled, one loaded, and some left today.
    var offersReward: Bool {
        isReady && gateway.isRewardedReady && rewardsLeftToday > 0
    }

    /// Lifetime count of watched opt-in ads. Keys the payment in the ledger, so the same
    /// watch cannot be paid twice.
    var rewardsWatched: Int { policy.rewardsWatched }

    /// Shows the opt-in ad and says whether it earned payment. The caller decides the
    /// amount: the shop pays `reward`, the end of a game pays the game's earnings again.
    func watchRewarded() async -> Bool {
        guard offersReward else { return false }
        guard await gateway.showRewarded() else { return false }
        policy.watchedReward()
        return true
    }

    // MARK: Coup de balai

    /// Removes ads for good if the passphrase is right.
    @discardableResult
    func coupDeBalai(_ phrase: String) -> Bool {
        guard Passphrase.isRight(phrase) else { return false }
        UserDefaults.standard.set(true, forKey: Self.sweptKey)
        adsAreOn = false
        gateway = SweptAds()
        return true
    }

    /// The same, for a device that learned of the sweep from the player's other one.
    ///
    /// No phrase is asked for: it was said once already, on whichever device said it, and
    /// `AccountSync` has just written that down. Without this the iPad would keep showing
    /// banners until the next cold launch, which reads as the sweep not having worked.
    func sweepIfSaidElsewhere() {
        guard adsAreOn, Self.wasSwept else { return }
        adsAreOn = false
        gateway = SweptAds()
    }
}

/// The banner strip under the lobby. Has no height until an ad has arrived, so a failed
/// load leaves no gap.
struct BannerSlot: View {
    let ads: AdsStore
    let isVisible: Bool

    var body: some View {
        Group {
            if isVisible && ads.adsAreOn {
                ads.gateway.bannerBody()
                    // Full width even at zero height: the network needs a width to fill.
                    .frame(maxWidth: .infinity)
                    .frame(height: ads.gateway.bannerHeight)
                    // A negative inset lets the creative run down into the home indicator's
                    // band instead of stopping above it.
                    .padding(.bottom, ads.gateway.bannerHeight > 0 ? -Self.homeIndicator : 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.easeInOut(duration: 0.3), value: ads.adsAreOn)
    }

    /// The home indicator's inset, read from the key window. Fixed per device, so no
    /// geometry reader is needed.
    @MainActor private static var homeIndicator: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }
}
