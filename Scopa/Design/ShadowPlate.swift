import SwiftUI

/// A drop shadow drawn once and then laid down as a picture.
///
/// A live `.shadow` is a blur worked out again on every frame anything near it moves, and
/// one around glass renders the glass off screen as well. On the table in mid move, the
/// shadows around the turn pill and the last-move chip were a quarter of what the screen
/// cost to draw. This is the same shadow, rendered by SwiftUI itself the first time a shape
/// is asked for and kept, then stretched sideways to whatever width the slab has.
///
/// Made to sit behind a view of exactly `size`, the way `.background` lays it.
struct ShadowPlate: View {
    let size: CGSize
    let cornerRadius: CGFloat
    let color: Color
    let radius: CGFloat
    var y: CGFloat = 0

    var body: some View {
        if let plate = ShadowPlates.plate(size: size, cornerRadius: cornerRadius, color: color, radius: radius) {
            Image(decorative: plate.image, scale: ShadowPlates.scale)
                .resizable(capInsets: EdgeInsets(top: 0, leading: plate.cap, bottom: 0, trailing: plate.cap))
                .frame(width: size.width + plate.reach * 2, height: size.height + plate.reach * 2)
                .offset(y: y)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// `.shadow` as a `ShadowPlate`, for a slab only sized at layout: a pill, a chip, a
    /// panel. A capsule unless given a corner. Laid behind everything the view already has,
    /// glass included, which is where `.shadow` draws it.
    func plateShadow(color: Color, radius: CGFloat, y: CGFloat = 0, cornerRadius: CGFloat? = nil) -> some View {
        background {
            GeometryReader { proxy in
                ShadowPlate(size: proxy.size,
                            cornerRadius: cornerRadius ?? min(proxy.size.width, proxy.size.height) / 2,
                            color: color, radius: radius, y: y)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

@MainActor
private enum ShadowPlates {
    /// A blur has no edge to keep sharp, so twice is plenty even on a 3x screen.
    static let scale: CGFloat = 2

    struct Plate {
        let image: CGImage
        /// How far the blur reaches past the shape.
        let reach: CGFloat
        /// The ends that keep their shape while the middle stretches. Zero when the plate
        /// was drawn at the slab's own width and is not stretched at all.
        let cap: CGFloat
    }

    private struct Key: Hashable {
        let width: Int
        let height: Int
        let corner: Int
        let radius: Int
        let color: Color
    }

    private static var kept: [Key: Plate] = [:]

    /// One plate per height and shape, however wide the slab. Only a slab too narrow to
    /// have a straight run between its corners is drawn at its own width.
    static func plate(size: CGSize, cornerRadius: CGFloat, color: Color, radius: CGFloat) -> Plate? {
        let reach = (radius * 2.5).rounded(.up)
        // The narrowest slab whose middle is far enough from both corners that their blur
        // never reaches it, so that middle can be stretched without bending anything.
        let straight = cornerRadius * 2 + reach * 2 + 2
        let width = min(size.width, straight)
        let key = Key(width: quarters(width), height: quarters(size.height), corner: quarters(cornerRadius),
                      radius: quarters(radius), color: color)
        if let plate = kept[key] { return plate }
        // A narrow slab that resizes smoothly would otherwise keep one of these per frame.
        if kept.count > 96 { kept.removeAll() }
        guard let image = render(size: CGSize(width: width, height: size.height), cornerRadius: cornerRadius,
                                 color: color, radius: radius, reach: reach)
        else { return nil }
        let plate = Plate(image: image, reach: reach, cap: width < straight ? 0 : reach * 2 + cornerRadius)
        kept[key] = plate
        return plate
    }

    private static func quarters(_ points: CGFloat) -> Int { Int((points * 4).rounded()) }

    /// The shadow on its own: the shape is pushed out of the frame and its shadow pulled
    /// back into it, so nothing but SwiftUI's own blur is drawn. Two and a half radii is
    /// where that blur has faded to nothing.
    private static func render(size: CGSize, cornerRadius: CGFloat, color: Color, radius: CGFloat,
                               reach: CGFloat) -> CGImage? {
        let away = size.width + reach * 2 + 1
        let shadow = RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .offset(x: -away)
            .shadow(color: color, radius: radius, x: away)
            .padding(reach)
        let renderer = ImageRenderer(content: shadow)
        renderer.scale = scale
        return renderer.cgImage
    }
}
