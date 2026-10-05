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

    /// Whether the passphrase has been said, here or on the player's other device.
    private(set) var isSwept: Bool

    private(set) var gateway: any AdsGateway

    let consent = AdsConsent()

    /// The no-ads purchase. It silences the banner and the interruption; the opt-in video
    /// and everything it pays are untouched.
    let pass = AdFreePass()

    /// The banner and the full screen ad may run: ads are on and the pass is not owned.
    var interrupts: Bool { adsAreOn && !pass.isOwned }

    /// When an ad may interrupt, and how often.
    private var policy = AdPolicy()

    static let sweptKey = "adsAreSwept"

    /// Whether the passphrase has ever been entered on this device. Anything else the
    /// phrase unlocks reads this rather than asking for it again.
    static var wasSwept: Bool { UserDefaults.standard.bool(forKey: sweptKey) }

    /// Whether the phrase also takes the ads away. Off since 2026-10-01: for now it only pays
    /// its denari, and a device swept before then gets its ads back. True brings the sweep back.
    static let phraseRemovesAds = false

    init(adsAreOn: Bool? = nil) {
        #if DEBUG
        // `-noAds` removes ads for this launch only, writing nothing down.
        let hidden = DebugLaunch.hidesAds
        #else
        let hidden = false
        #endif
        let on = !hidden && (adsAreOn ?? !(Self.phraseRemovesAds && Self.wasSwept))
        self.adsAreOn = on
        self.isSwept = Self.wasSwept
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
        isReady && interrupts && route == .lobby
    }

    // MARK: The interruption

    /// Called when a round ends, so the ad is warm by the time the game is.
    func prepareForEndOfGame() {
        guard interrupts else { return }
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
        guard !pass.isOwned, policy.allowsInterstitial(after: ending) else { return }
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

    /// What one watched ad is worth, at the least.
    var reward: Denari { AdPolicy.reward }

    /// Lifetime count of watched opt-in ads on this device. Keys the payment in the ledger,
    /// beside `Device.id`, so the same watch cannot be paid twice.
    var rewardsWatched: Int { policy.rewardsWatched }

    enum RewardOutcome {
        /// Watched to the end, so it is owed.
        case watched
        /// Shown, but closed before the end.
        case closedEarly
        /// Nothing came to show, which the player is told rather than left tapping.
        case unavailable
    }

    /// Shows the opt-in ad and says whether it earned payment. The caller decides the
    /// amount: the shop pays `reward`, the end of a game its earnings again or `reward`,
    /// whichever is more.
    func watchRewarded() async -> RewardOutcome {
        guard isReady else { return .unavailable }
        guard await rewardHasLoaded() else { return .unavailable }
        guard await gateway.showRewarded() else { return .closedEarly }
        policy.watchedReward()
        return .watched
    }

    /// Asks for the opt-in ad if none is loaded and waits up to eight seconds for it. AdMob
    /// usually answers in one or two; a request it has nothing for fails sooner still.
    private func rewardHasLoaded() async -> Bool {
        gateway.preloadRewarded()
        for _ in 0..<32 {
            if gateway.isRewardedReady { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return gateway.isRewardedReady
    }

    // MARK: Coup de balai

    /// Writes the passphrase down if it is right. It pays its denari (`PurseStore.grantSweepGift`)
    /// and, while `phraseRemovesAds` says so, removes the ads for good.
    @discardableResult
    func coupDeBalai(_ phrase: String) -> Bool {
        guard Passphrase.isRight(phrase) else { return false }
        UserDefaults.standard.set(true, forKey: Self.sweptKey)
        sweep()
        return true
    }

    /// The same, for a device that learned of the sweep from the player's other one.
    ///
    /// No phrase is asked for: it was said once already, on whichever device said it, and
    /// `AccountSync` has just written that down. Without this the iPad would keep showing
    /// banners until the next cold launch, which reads as the sweep not having worked.
    func sweepIfSaidElsewhere() {
        guard !isSwept, Self.wasSwept else { return }
        sweep()
    }

    private func sweep() {
        isSwept = true
        guard Self.phraseRemovesAds, adsAreOn else { return }
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
            if isVisible && ads.interrupts {
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
        .animation(.easeInOut(duration: 0.3), value: ads.interrupts)
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

// MARK: - What covers the strip

/// How many sheets and covers are up over the lobby. The strip comes down under any of
/// them: hidden behind one it would go on refreshing ads nobody sees, which earns nothing,
/// drags down what the unit is bid, and breaks AdMob's policy.
@MainActor
@Observable
final class BannerCovers {
    private var count = 0

    var isCovered: Bool { count > 0 }

    fileprivate func cover() { count += 1 }
    fileprivate func uncover() { count = max(0, count - 1) }
}

extension EnvironmentValues {
    /// Set once at the root. Optional, since a default instance would be built off the
    /// main actor.
    @Entry var bannerCovers: BannerCovers? = nil
}

extension View {
    /// Marks a sheet or cover that can open over the lobby, so the banner steps aside while
    /// it is up. Put it on the presented content, outside any navigation stack inside it.
    func coversBanner() -> some View {
        modifier(CoversBanner())
    }
}

private struct CoversBanner: ViewModifier {
    @Environment(\.bannerCovers) private var covers
    /// Guards against an appearance being counted twice.
    @State private var isCounted = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isCounted else { return }
                isCounted = true
                covers?.cover()
            }
            .onDisappear {
                guard isCounted else { return }
                isCounted = false
                covers?.uncover()
            }
    }
}
