import Foundation

/// The AdMob identifiers. Unit ids are not secrets: they ship inside the app.
///
/// A debug build asks for Google's test units, so that tapping an ad on your own phone can
/// never be taken for click fraud on the live account. `-liveAds` points a debug build at
/// the real units instead, for checking ids and fill without archiving. Only use it on a
/// phone listed under Test devices in the AdMob console, where live units serve test ads.
enum AdUnits {
    /// The units this app earns from, from the AdMob console. The matching app id is
    /// `GADApplicationIdentifier` in `Scopa-Info.plist`, without which the SDK will not start.
    private enum Live {
        static let banner = "ca-app-pub-6919645046065024/6385799119"
        static let interstitial = "ca-app-pub-6919645046065024/1342345674"
        static let rewarded = "ca-app-pub-6919645046065024/1742283428"
    }

    #if DEBUG
    /// Google's public test units, the same for every app. They always fill, so pacing can
    /// be judged honestly, and they pay nothing.
    private enum Test {
        static let banner = "ca-app-pub-3940256099942544/2435281174"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    }

    static var banner: String { DebugLaunch.usesLiveAds ? Live.banner : Test.banner }
    static var interstitial: String { DebugLaunch.usesLiveAds ? Live.interstitial : Test.interstitial }
    static var rewarded: String { DebugLaunch.usesLiveAds ? Live.rewarded : Test.rewarded }
    #else
    static let banner = Live.banner
    static let interstitial = Live.interstitial
    static let rewarded = Live.rewarded
    #endif
}
