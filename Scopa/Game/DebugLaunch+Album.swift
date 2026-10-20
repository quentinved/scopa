import Foundation

/// The album's later volumes, and what their decks cost to draw.
///
/// `-album -volume mosaico -collected 12 -packs 2` plants one like any other volume (or
/// `carnevale`, `intarsio`, `merletto`, `tarocchi`), and `-cardStyle mosaico -cardSkin
/// piacentina` (or `maiolica` and `bergamasca`, `carnevale` and `veneziana`, `intarsio` and
/// `sorrentina`, `merletto` and `buranella`, `tarocchi` and `milanese`) deals the table in it;
/// `-cornice tessere` puts the Mosaico frame on the badge, `-tapis cubi` lays the Intarsio
/// cloth and `-livery trina` strikes the badge in Merletto's lace. All of them are read
/// straight out of the arguments as stored preferences. `-icons -volume tarocchi -collected
/// 40` opens Settings on the app icons with the Visconti unlocked; without the album, locked.
/// `-deckDraft mosaico -deckBench` times every face against the other drawings, under the
/// sheet. `-albumMiddle` opens the page halfway down, where the prize is.
extension DebugLaunch {
    static var showsAlbumMiddle: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-albumMiddle")
        #else
        false
        #endif
    }

    static var deckBench: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-deckBench")
        #else
        false
        #endif
    }
}
