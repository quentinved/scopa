import ScopaRewards
import SwiftUI
import UIKit
import os

/// The app icon only the album's last volume gives: the house icon on a tarot card's gold
/// leaf, tooled like the Visconti deck Tarocchi is drawn after. Set from Settings, and only
/// once Tarocchi is full. Never sold, never in a pack.
enum ViscontiIcon {
    /// The icon set's name in the asset catalogue, and in the build setting that ships it.
    static let assetName = "AppIcon-Visconti"

    /// What the album calls the prize, the same word in every language.
    static let title = "Visconti"

    /// The volume that pays it.
    static let volume = Volume.tarocchi

    static var isInUse: Bool { UIApplication.shared.alternateIconName == assetName }

    static func isEarned(_ book: AlbumBook) -> Bool { book.album(volume).isComplete }

    /// Puts it on the home screen. iOS says so itself with an alert of its own.
    static func use() async {
        guard LadderIcon.isSupported, !isInUse else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(assetName)
        } catch {
            Log.table.error("Could not change the icon: \(error.localizedDescription)")
        }
    }

    /// The classic icon back for someone wearing this one without the album to show for it:
    /// a reinstall that has not synced the album back yet, say.
    static func returnIfUnearned(_ earned: Bool) async {
        guard !earned, isInUse else { return }
        await LadderIcon.use(nil)
    }
}

/// The Visconti icon as the home screen shows it, at any size.
struct ViscontiIconArt: View {
    var size: CGFloat = 44

    var body: some View {
        IconArtwork(size: size, finish: .visconti)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .drawingGroup()
    }
}
