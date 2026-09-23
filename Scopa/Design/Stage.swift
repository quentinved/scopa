import SwiftUI

/// Which way the screen is being held.
///
/// The table stacks downwards, so the screens branch on height rather than width:
/// landscape has about 390 points to work with instead of 850.
enum Stage: Equatable {
    /// Portrait: room downwards, one column read top to bottom.
    case tall
    /// Landscape: room across, none to spare downwards.
    case wide

    /// Reads the shape of the screen where it is given one, and the size class alone where
    /// it is not — which is what the screens away from the table still pass.
    ///
    /// An iPad is `.regular` both ways round, so it used to take the tall column whichever
    /// way it was turned. On its side that column does not fit: it wants about 870 points
    /// and an 11-inch iPad in landscape has around 730, so the score chips were cut off the
    /// top and the coach's line off the bottom. A landscape iPad has the same shape of
    /// problem as a landscape phone — width to spare, not enough height — so it folds the
    /// same way rather than being squeezed.
    init(_ heightClass: UserInterfaceSizeClass?, size: CGSize = .zero) {
        self = heightClass == .compact || size.width > size.height ? .wide : .tall
    }

    var isWide: Bool { self == .wide }

    /// Picks between two values without spelling out the branch at every call site.
    func pick<T>(tall: T, wide: T) -> T { self == .wide ? wide : tall }

    /// The widest a portrait column grows. Every phone is narrower, so this only bites on
    /// an iPad or a Mac window, where it keeps the layout centred at its design size.
    static let columnWidth: CGFloat = 600

    /// How much bigger the table is drawn where there is room for it.
    ///
    /// Sizes on the cloth are point values rather than fractions of the screen (see
    /// `TableScreen.tableCardWidth`), so one factor over all of them is the whole scaling.
    /// Both size classes are checked: a Max phone in landscape is `.regular` across too,
    /// and it is the screen with the least height to give.
    ///
    /// 1.55 is as far as it goes because of the cloth: six cards at 76 points and a gap
    /// between each is the widest row an iPad's 834 points across will take.
    static func lift(_ widthClass: UserInterfaceSizeClass?,
                     _ heightClass: UserInterfaceSizeClass?) -> CGFloat {
        isRoomy(widthClass, heightClass) ? 1.55 : 1
    }

    /// A screen with room to spare both ways: an iPad, as against a phone on its side,
    /// which is `.regular` across but has no height to give.
    static func isRoomy(_ widthClass: UserInterfaceSizeClass?,
                        _ heightClass: UserInterfaceSizeClass?) -> Bool {
        widthClass == .regular && heightClass != .compact
    }

    /// The widest a landscape table spreads, before the lift: a rail, the cloth, a rail.
    /// Only an iPad is wider than this, and there it buys nothing — left to fill the screen
    /// the two seats ended up out at the bezels, a hand's width from the cards they are
    /// playing. Every phone is narrower, so this only bites on an iPad.
    static let spreadWidth: CGFloat = 700

    /// The landscape table at the width that screen should have it.
    static func spread(_ widthClass: UserInterfaceSizeClass?,
                       _ heightClass: UserInterfaceSizeClass?) -> CGFloat? {
        isRoomy(widthClass, heightClass) ? spreadWidth * lift(widthClass, heightClass) : nil
    }

    /// Carries the lift to views too deep to read the size classes themselves. It is 1
    /// unless an ancestor sets it, so multiplying by it is a no-op everywhere else.
    fileprivate struct LiftKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }

    /// Carries the screen's own shape down from the root, because the size classes cannot
    /// tell an iPad on its side from one upright: it is `.regular` both ways. Zero until
    /// the first layout pass, where the size classes decide on their own as they used to.
    fileprivate struct SizeKey: EnvironmentKey { static let defaultValue: CGSize = .zero }

    /// The column at the width that screen should have it.
    static func column(_ widthClass: UserInterfaceSizeClass?,
                       _ heightClass: UserInterfaceSizeClass?) -> CGFloat {
        columnWidth * lift(widthClass, heightClass)
    }
}

extension EnvironmentValues {
    /// How much bigger this part of the screen is drawn. See `Stage.lift(_:_:)`.
    var lift: CGFloat {
        get { self[Stage.LiftKey.self] }
        set { self[Stage.LiftKey.self] = newValue }
    }

    /// The whole screen, measured at the root. See `Stage.init(_:size:)`.
    var screenSize: CGSize {
        get { self[Stage.SizeKey.self] }
        set { self[Stage.SizeKey.self] = newValue }
    }
}
