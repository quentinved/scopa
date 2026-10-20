import Foundation

/// Where an opt-in video is offered. Each offer since the denari ones has a unit of its own,
/// so the AdMob console says what every offer earns rather than one sum for them all.
enum RewardedSlot: String, CaseIterable {
    /// Denari in the shop, the wheel's extra turn and a game paid twice, on the first unit.
    case denari
    /// Today's card drawn at the winner's odds, after a deal lost to Hugo.
    case dailyCard
    /// A deck or a cloth worn for one game before it is bought.
    case tryOn
    /// A ranked run carried past the loss that broke it.
    case keepRun
}

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

        static func rewarded(_ slot: RewardedSlot) -> String {
            switch slot {
            case .denari: "ca-app-pub-6919645046065024/1742283428"
            case .dailyCard: "ca-app-pub-6919645046065024/5329328154"
            case .tryOn: "ca-app-pub-6919645046065024/8464039215"
            case .keepRun: "ca-app-pub-6919645046065024/5200590785"
            }
        }
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
    static func rewarded(_ slot: RewardedSlot) -> String {
        DebugLaunch.usesLiveAds ? Live.rewarded(slot) : Test.rewarded
    }
    #else
    static let banner = Live.banner
    static let interstitial = Live.interstitial
    static func rewarded(_ slot: RewardedSlot) -> String { Live.rewarded(slot) }
    #endif
}
