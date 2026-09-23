import SwiftUI

/// Everything the app asks of an ad network. The placeholder and the AdMob adapter both
/// sit behind this, so no view imports an ad framework and `ScopaCore` never sees one.
@MainActor
protocol AdsGateway: AnyObject {
    /// Consent is settled and the SDK is running, so the gateway may start requesting ads.
    /// Nothing may be requested before this call.
    func begin()

    // MARK: The strip

    /// How much room the banner strip takes. Zero until an ad has arrived, so a failed
    /// load leaves no empty band behind.
    var bannerHeight: CGFloat { get }

    /// The banner strip. Mount it only where it is visible: requesting ads for an off
    /// screen banner breaks AdMob's policy.
    func bannerBody() -> AnyView

    /// Anything the gateway draws full screen itself. Empty for networks that present
    /// their own view controller.
    func overlayBody() -> AnyView

    // MARK: The interruption

    /// Warms the next full screen ad. Cheap to call more than once.
    func preloadInterstitial()

    /// Shows the full screen ad and returns once it is dismissed, reporting whether one was
    /// shown at all. Returns immediately when nothing is loaded.
    @discardableResult
    func showInterstitial() async -> Bool

    // MARK: The one they choose

    /// Whether an opt-in ad is loaded right now. The offer is only shown when it is.
    var isRewardedReady: Bool { get }

    /// Warms the next opt-in ad.
    func preloadRewarded()

    /// Shows the opt-in ad and says whether it was watched far enough to be paid for.
    func showRewarded() async -> Bool
}

/// The no-ads gateway, used once ads have been removed. Every call is a no-op.
@MainActor
final class SweptAds: AdsGateway {
    func begin() {}

    var bannerHeight: CGFloat { 0 }
    func bannerBody() -> AnyView { AnyView(EmptyView()) }
    func overlayBody() -> AnyView { AnyView(EmptyView()) }

    func preloadInterstitial() {}
    func showInterstitial() async -> Bool { false }

    var isRewardedReady: Bool { false }
    func preloadRewarded() {}
    func showRewarded() async -> Bool { false }
}
