import SwiftUI
import UIKit
import os

/// The app icon only the no-ads purchase gives: the house icon in lapis and gold leaf, with
/// the patron's crest on the coin. Set from Settings and from the celebration, like the
/// ladder's metals, and only while the purchase is owned.
enum PatronIcon {
    /// The icon set's name in the asset catalogue, and in the build setting that ships it.
    static let assetName = "AppIcon-Patron"

    static var isInUse: Bool { UIApplication.shared.alternateIconName == assetName }

    /// Puts it on the home screen. iOS says so itself with an alert of its own.
    static func use() async {
        guard LadderIcon.isSupported, !isInUse else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(assetName)
        } catch {
            Log.table.error("Could not change the icon: \(error.localizedDescription)")
        }
    }

    /// The classic icon back, for someone wearing this one who no longer owns the purchase:
    /// a refund, or a restore on an Apple account that never bought it.
    static func returnIfUnowned(owned: Bool) async {
        guard !owned, isInUse else { return }
        await LadderIcon.use(nil)
    }
}

/// The patron's icon as the home screen shows it, at any size.
struct PatronIconArt: View {
    var size: CGFloat = 44

    var body: some View {
        IconArtwork(size: size, finish: .patron)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .drawingGroup()
    }
}
