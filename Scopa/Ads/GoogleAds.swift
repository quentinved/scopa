import GoogleMobileAds
import Observation
import os
import SwiftUI
import UIKit

/// AdMob, behind the gateway. The only file in the app that imports an ad framework.
///
/// AdMob is used directly, with no mediation layer: at this volume the extra dashboard and
/// binary size buy demand already in AdMob's exchange. Adding one later changes only this file.
@MainActor
@Observable
final class GoogleAds: AdsGateway {
    private(set) var bannerHeight: CGFloat = 0
    private(set) var isRewardedReady = false

    @ObservationIgnored private var hasBegun = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var rewarded: RewardedAd?
    @ObservationIgnored private var isLoadingInterstitial = false
    @ObservationIgnored private var isLoadingRewarded = false
    /// The ad holds its delegate weakly, so the presentation has to be retained here until
    /// the player dismisses it.
    @ObservationIgnored private var presentation: FullScreen?
    /// The banner, kept here rather than in a strip so it can move between them.
    @ObservationIgnored fileprivate lazy var keeper = BannerKeeper { [weak self] height in
        self?.bannerFilled(to: height)
    }

    func begin() {
        guard !hasBegun else { return }
        hasBegun = true
        Log.ads.info("SDK up; asking for banner \(AdUnits.banner, privacy: .public), interstitial \(AdUnits.interstitial, privacy: .public), rewarded \(AdUnits.rewarded, privacy: .public)")
        // Nothing full screen is warmed at launch: a session that never reaches a game the
        // pacing would interrupt asked for an ad it could not show. The table warms it.
    }

    #if DEBUG
    /// Google's own request log, over the app: every request, whether it filled, and who
    /// answered.
    static func presentInspector() {
        MobileAds.shared.presentAdInspector(from: nil) { _ in }
    }
    #endif

    // MARK: The strip

    func bannerBody() -> AnyView {
        // The creative stops at its own edge, so the felt fills the rest of the strip and
        // the band the home indicator sits in.
        AnyView(
            GoogleBanner(ads: self)
                .background {
                    // Only once an ad has arrived, or the felt would be the empty band the
                    // zero height is there to avoid.
                    if bannerHeight > 0 { BannerGround() }
                }
        )
    }

    /// AdMob presents its own view controller, so the app draws nothing full screen.
    func overlayBody() -> AnyView {
        AnyView(EmptyView())
    }

    fileprivate func bannerFilled(to height: CGFloat) {
        guard bannerHeight != height else { return }
        withAnimation(.easeInOut(duration: 0.3)) { bannerHeight = height }
    }

    // MARK: The interruption

    /// When the waiting interstitial arrived. AdMob expires one after an hour, and an
    /// expired ad fails to present, so a stale one is dropped and fetched again.
    @ObservationIgnored private var interstitialLoadedAt: Date?

    /// Comfortably inside AdMob's one hour, which applies to the opt-in ad as well.
    private static let shelfLife: TimeInterval = 50 * 60

    private static func isStale(_ loadedAt: Date?) -> Bool {
        guard let loadedAt else { return false }
        return Date.now.timeIntervalSince(loadedAt) > shelfLife
    }

    private var interstitialIsStale: Bool { Self.isStale(interstitialLoadedAt) }

    func preloadInterstitial() {
        if interstitial != nil, interstitialIsStale {
            Log.ads.info("Interstitial older than its shelf life; fetching a fresh one")
            interstitial = nil
        }
        guard hasBegun, interstitial == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        Task { [weak self] in
            var ad: InterstitialAd?
            do {
                ad = try await InterstitialAd.load(with: AdUnits.interstitial, request: Request())
                Log.ads.info("Interstitial ready")
            } catch {
                Log.ads.error("Interstitial did not load: \(AdTrouble.words(for: error), privacy: .public)")
            }
            guard let self else { return }
            isLoadingInterstitial = false
            interstitial = ad
            interstitialLoadedAt = ad == nil ? nil : .now
        }
    }

    @discardableResult
    func showInterstitial() async -> Bool {
        preloadInterstitial()
        guard let ad = interstitial else {
            // Never stall the player waiting for a load: the game is over and they are
            // leaving the table.
            Log.ads.info("The pacing allowed an interstitial but none was loaded")
            return false
        }
        interstitial = nil
        let host = await FullScreen.settledHost()
        do {
            try ad.canPresent(from: host)
        } catch {
            Log.ads.error("Interstitial could not present: \(AdTrouble.words(for: error), privacy: .public)")
            preloadInterstitial()
            return false
        }
        let shown = await present(ad, from: host)
        preloadInterstitial()
        return shown
    }

    private func present(_ ad: InterstitialAd, from host: UIViewController?) async -> Bool {
        var shown = false
        await withCheckedContinuation { resume in
            let presentation = FullScreen { didShow in
                shown = didShow
                resume.resume()
            }
            self.presentation = presentation
            ad.fullScreenContentDelegate = presentation
            ad.present(from: host)
        }
        presentation = nil
        if !shown { Log.ads.error("Interstitial was handed over but never appeared") }
        return shown
    }

    // MARK: The one they choose

    /// When the waiting opt-in ad arrived. One held past the hour fails to present, and the
    /// player's tap on "double" would do nothing at all.
    @ObservationIgnored private var rewardedLoadedAt: Date?

    func preloadRewarded() {
        if rewarded != nil, Self.isStale(rewardedLoadedAt) {
            Log.ads.info("Rewarded ad older than its shelf life; fetching a fresh one")
            rewarded = nil
            isRewardedReady = false
        }
        guard hasBegun, rewarded == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        Task { [weak self] in
            var ad: RewardedAd?
            do {
                ad = try await RewardedAd.load(with: AdUnits.rewarded, request: Request())
                Log.ads.info("Rewarded ad ready")
            } catch {
                Log.ads.error("Rewarded ad did not load: \(AdTrouble.words(for: error), privacy: .public)")
            }
            guard let self else { return }
            isLoadingRewarded = false
            rewarded = ad
            rewardedLoadedAt = ad == nil ? nil : .now
            isRewardedReady = ad != nil
        }
    }

    func showRewarded() async -> Bool {
        guard let ad = rewarded else { return false }
        rewarded = nil
        isRewardedReady = false
        // The reward lands in a callback of its own, before the ad is dismissed.
        let earned = Earned()
        await withCheckedContinuation { resume in
            let presentation = FullScreen { _ in resume.resume() }
            self.presentation = presentation
            ad.fullScreenContentDelegate = presentation
            ad.present(from: nil) { earned.value = true }
        }
        presentation = nil
        preloadRewarded()
        return earned.value
    }
}

/// Whether the player watched far enough to be paid. A reference type so the reward
/// callback and the code awaiting dismissal share one answer.
@MainActor
private final class Earned {
    var value = false
}

/// Watches one full screen presentation to its end, whether it was dismissed or failed to
/// present. It must resume exactly once, or the caller's continuation never returns.
@MainActor
private final class FullScreen: NSObject, FullScreenContentDelegate {
    private var finish: ((Bool) -> Void)?
    private var didShow = false

    init(finish: @escaping (Bool) -> Void) {
        self.finish = finish
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        didShow = true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        end()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        end()
    }

    private func end() {
        guard let finish else { return }
        self.finish = nil
        finish(didShow)
    }

    /// The top view controller once nothing is mid-transition, waiting up to a second. A
    /// sheet still sliding away refuses a new presentation, and the ad is then lost.
    static func settledHost() async -> UIViewController? {
        for _ in 0..<10 {
            guard let top = topController() else { return nil }
            let moving = top.isBeingDismissed || top.isBeingPresented || top.transitionCoordinator != nil
            if !moving { return top }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return topController()
    }

    private static func topController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

// MARK: - The banner

/// Fills the strip either side of a narrow creative, and the band below it, with the
/// darkest shade of the current felt.
private struct BannerGround: View {
    @Environment(\.tableFelt) private var felt

    var body: some View {
        felt.deep.ignoresSafeArea(edges: .bottom)
    }
}

/// The strip, sized by the network rather than by a guess.
private struct GoogleBanner: UIViewRepresentable {
    let ads: GoogleAds

    func makeUIView(context: Context) -> BannerHost {
        BannerHost(keeper: ads.keeper)
    }

    func updateUIView(_ host: BannerHost, context: Context) {}

    /// The width comes from the proposal, not the view's bounds: with no ad the strip has
    /// zero height, is never laid out, and `layoutSubviews` would never report a width.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView host: BannerHost, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        host.prepare(width: width)
        return CGSize(width: width, height: host.keeper.filledHeight)
    }

    static func dismantleUIView(_ host: BannerHost, coordinator: ()) {
        host.stop()
    }
}

/// One strip's place for the banner. Nothing is reserved up front, so a failed load leaves
/// the lobby as it was drawn.
private final class BannerHost: UIView {
    let keeper: BannerKeeper
    private var width: CGFloat = 0

    init(keeper: BannerKeeper) {
        self.keeper = keeper
        super.init(frame: .zero)
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        for banner in subviews { banner.center = CGPoint(x: bounds.midX, y: bounds.midY) }
    }

    /// Takes the banner at this width, and again when the width changes, since a rotated
    /// strip is a different ad size.
    func prepare(width: CGFloat) {
        guard abs(width - self.width) > 1 else { return }
        self.width = width
        keeper.attach(to: self, width: width)
    }

    func hold(_ banner: BannerView) {
        addSubview(banner)
        setNeedsLayout()
    }

    /// The strip is leaving the screen.
    func stop() {
        width = 0
        keeper.detach(from: self)
    }
}

/// The one banner, handed from strip to strip. Opening or closing a sheet moves the strip
/// to a new host; passing it the ad already showing, rather than asking for another, saves
/// a request per sheet and keeps the ad on screen long enough to count.
@MainActor
private final class BannerKeeper: NSObject, BannerViewDelegate, AdSizeDelegate {
    /// Cap on the banner's height. Anchored adaptive sizes go up to 150 points, which is
    /// too much of the lobby.
    private static let maxHeight: CGFloat = 60

    /// How long the banner waits out of sight for the next strip: long enough for a sheet
    /// to open or close. Past it the banner goes, since one left refreshing off screen
    /// breaks AdMob's policy.
    private static let handOver: Duration = .seconds(1)

    private let report: (CGFloat) -> Void
    private var banner: BannerView?
    private var width: CGFloat = 0
    private weak var host: BannerHost?
    private var drop: Task<Void, Never>?

    /// How tall the ad is. Zero until one has arrived.
    private(set) var filledHeight: CGFloat = 0

    init(report: @escaping (CGFloat) -> Void) {
        self.report = report
    }

    /// Puts the banner in this strip: the one already loaded when it was asked for at this
    /// width, a fresh one otherwise.
    func attach(to host: BannerHost, width: CGFloat) {
        drop?.cancel()
        drop = nil
        self.host = host
        if let banner, abs(width - self.width) <= 1 {
            host.hold(banner)
            Log.ads.info("Banner handed to the next strip")
        } else {
            load(into: host, width: width)
        }
    }

    /// The strip is leaving. The banner steps out of sight and waits a moment for the next.
    func detach(from host: BannerHost) {
        guard self.host === host else { return }
        self.host = nil
        banner?.removeFromSuperview()
        drop = Task { [weak self] in
            try? await Task.sleep(for: Self.handOver)
            guard !Task.isCancelled else { return }
            self?.discard()
        }
    }

    private func discard() {
        banner = nil
        width = 0
        filledHeight = 0
        report(0)
    }

    private func load(into host: BannerHost, width: CGFloat) {
        banner?.removeFromSuperview()
        let banner = BannerView(adSize: inlineAdaptiveBanner(width: width, maxHeight: Self.maxHeight))
        banner.adUnitID = AdUnits.banner
        banner.rootViewController = host.window?.rootViewController
        banner.delegate = self
        // An inline adaptive ad may come back shorter than requested, reported here.
        banner.adSizeDelegate = self
        self.banner = banner
        self.width = width
        host.hold(banner)
        Log.ads.info("Banner requested at \(width, format: .fixed(precision: 0))pt wide, unit \(AdUnits.banner, privacy: .public)")
        banner.load(Request())
    }

    // MARK: BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard bannerView === banner else { return }
        // `adSize` is the size requested, not the one delivered, so the height comes from
        // `intrinsicContentSize` instead.
        let network = bannerView.responseInfo?.loadedAdNetworkResponseInfo?.adNetworkClassName
        Log.ads.info("Banner filled by \(network ?? "an unnamed network", privacy: .public), response \(bannerView.responseInfo?.responseIdentifier ?? "-", privacy: .public)")
        fill(bannerView, height: bannerView.intrinsicContentSize.height)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        guard bannerView === banner else { return }
        // On screen a failed load and no banner at all look identical, so log the reason.
        Log.ads.error("Banner did not load: \(AdTrouble.words(for: error), privacy: .public)")
        filledHeight = 0
        report(0)
    }

    // MARK: AdSizeDelegate

    /// How an inline adaptive ad announces the height it actually wants, after landing.
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        guard bannerView === banner else { return }
        fill(bannerView, height: size.size.height)
    }

    /// Takes the ad at its reported height, falling back to the requested one. A view with
    /// no intrinsic height reports −1, not zero.
    private func fill(_ bannerView: BannerView, height: CGFloat) {
        let asked = bannerView.adSize.size.height
        let actual = height > 0 ? height : asked
        filledHeight = min(actual, Self.maxHeight)
        bannerView.frame.size = CGSize(width: bannerView.adSize.size.width, height: filledHeight)
        host?.setNeedsLayout()
        report(filledHeight)
    }
}
