import ScopaRewards
import SwiftUI

/// A present from the house: a box in patterned paper, tied with a gold ribbon, a wax seal
/// on the front and a tag with the player's name. Opened, the lid lifts away and what was
/// inside rises out of it in a fan.
///
/// The spectacle is the object. Nothing is imported: paper, ribbon and wax are shapes and
/// gradients, so it draws at any width.
struct Parcel: View {
    var width: CGFloat
    var isOpen = false
    /// Written on the tag.
    var name: String
    /// What rises out of it once it is open.
    var packs: [PackTier] = []

    @Environment(\.tableFelt) private var felt

    private var boxHeight: CGFloat { width * 0.6 }
    private var lidHeight: CGFloat { width * 0.2 }

    var body: some View {
        ZStack(alignment: .bottom) {
            contents
            box
                .offset(y: isOpen ? width * 0.04 : 0)
            top
                .offset(y: -(boxHeight - width * 0.03))
                .offset(x: isOpen ? width * 0.35 : 0, y: isOpen ? -width * 0.75 : 0)
                .rotationEffect(.degrees(isOpen ? 24 : 0))
                .opacity(isOpen ? 0 : 1)
        }
        // Taller once open, for what rises out of it.
        .frame(width: width * 1.5, height: width * (isOpen ? 1.3 : 0.95), alignment: .bottom)
    }

    // MARK: The box

    private var box: some View {
        ZStack {
            WrappingPaper(width: width, height: boxHeight)
            ribbon(height: boxHeight)
            WaxSeal(size: width * 0.24)
        }
        .frame(width: width, height: boxHeight)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.04))
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.04)
                .strokeBorder(Palette.linenDeep.opacity(0.9), lineWidth: width * 0.008)
        }
        .shadow(color: felt.shade(0.55), radius: width * 0.06, y: width * 0.04)
    }

    private func ribbon(height: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [Palette.goldDeep, Palette.goldLight, Palette.gold, Palette.goldDeep],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: width * 0.15, height: height)
    }

    // MARK: The lid, the bow and the tag

    private var top: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                WrappingPaper(width: width * 1.08, height: lidHeight, shade: 0.12)
                ribbon(height: lidHeight)
            }
            .frame(width: width * 1.08, height: lidHeight)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.035))
            .shadow(color: Palette.ink.opacity(0.25), radius: width * 0.015, y: width * 0.012)
            Bow(width: width * 0.5)
                .offset(y: -lidHeight * 0.7)
            Tag(name: name, width: width * 0.3)
                .rotationEffect(.degrees(-9), anchor: .top)
                .offset(x: width * 0.36, y: lidHeight * 0.9)
        }
    }

    // MARK: What was inside

    private var contents: some View {
        let middle = CGFloat(packs.count - 1) / 2
        // Laid out at the packs' own height, so they stand with their feet in the box.
        return ZStack {
            ForEach(Array(packs.enumerated()), id: \.offset) { place, tier in
                let lean = CGFloat(place) - middle
                PackArt(tier: tier, width: width * 0.28)
                    .rotationEffect(.degrees(isOpen ? Double(lean) * 10 : 0))
                    .offset(x: isOpen ? lean * width * 0.27 : 0, y: isOpen ? abs(lean) * width * 0.05 : 0)
                    .zIndex(-Double(abs(lean)))
            }
        }
        .frame(height: width * 0.6)
        .offset(y: isOpen ? -boxHeight * 0.72 : boxHeight * 0.1)
        .opacity(isOpen ? 1 : 0)
    }
}

/// Cream paper with a small lattice of terracotta lozenges, lit from the top left.
private struct WrappingPaper: View {
    let width: CGFloat
    let height: CGFloat
    /// How much darker than the box, for the lid's turned edge.
    var shade: Double = 0

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Palette.cream, Palette.linen, Palette.linenDeep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { lattice }
            .overlay { Palette.ink.opacity(shade) }
            .frame(width: width, height: height)
    }

    private var lattice: some View {
        Canvas { context, size in
            let step = max(size.width / 9, 8)
            let half = step * 0.13
            var row = 0
            for y in stride(from: step * 0.3, through: size.height, by: step * 0.62) {
                let shift = row.isMultiple(of: 2) ? 0 : step / 2
                for x in stride(from: shift, through: size.width, by: step) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y - half * 1.5))
                    path.addLine(to: CGPoint(x: x + half, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + half * 1.5))
                    path.addLine(to: CGPoint(x: x - half, y: y))
                    path.closeSubpath()
                    context.fill(path, with: .color(Palette.terracotta.opacity(0.55)))
                }
                row += 1
            }
        }
    }
}

/// Two loops of gold ribbon and the knot between them.
private struct Bow: View {
    let width: CGFloat

    private var gold: LinearGradient {
        LinearGradient(colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            loop.rotationEffect(.degrees(-22)).offset(x: -width * 0.26)
            loop.rotationEffect(.degrees(22)).offset(x: width * 0.26)
            RoundedRectangle(cornerRadius: width * 0.06)
                .fill(gold)
                .frame(width: width * 0.2, height: width * 0.2)
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.06)
                        .strokeBorder(Palette.goldDeep.opacity(0.7), lineWidth: width * 0.015)
                }
        }
        .frame(width: width, height: width * 0.45)
        .shadow(color: Palette.ink.opacity(0.3), radius: width * 0.03, y: width * 0.02)
    }

    private var loop: some View {
        Ellipse()
            .fill(gold)
            .overlay {
                Ellipse()
                    .fill(Palette.goldDeep.opacity(0.55))
                    .padding(width * 0.07)
            }
            .overlay { Ellipse().strokeBorder(Palette.goldDeep.opacity(0.6), lineWidth: width * 0.015) }
            .frame(width: width * 0.48, height: width * 0.3)
    }
}

/// A card tag on a string, with the name written on it by hand.
private struct Tag: View {
    let name: String
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Palette.goldDeep)
                .frame(width: width * 0.025, height: width * 0.28)
            Text(verbatim: name)
                .font(.system(size: width * 0.17, weight: .semibold, design: .serif).italic())
                .foregroundStyle(Palette.ink.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, width * 0.08)
                .frame(width: width, height: width * 0.52)
                .background {
                    TagShape()
                        .fill(Palette.stock)
                        .overlay { TagShape().stroke(Palette.linenDeep, lineWidth: width * 0.02) }
                }
                .overlay(alignment: .top) {
                    Circle()
                        .strokeBorder(Palette.goldDeep, lineWidth: width * 0.02)
                        .frame(width: width * 0.08, height: width * 0.08)
                        .offset(y: -width * 0.02)
                }
        }
        .shadow(color: Palette.ink.opacity(0.25), radius: width * 0.04, y: width * 0.03)
    }
}

/// A luggage label: a rectangle with its top corners clipped.
private struct TagShape: Shape {
    func path(in r: CGRect) -> Path {
        let cut = r.height * 0.24
        var path = Path()
        path.move(to: CGPoint(x: r.minX + cut, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - cut, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + cut))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
        path.closeSubpath()
        return path
    }
}

/// A disc of red wax pressed with the broom.
private struct WaxSeal: View {
    let size: CGFloat

    private static let wax = Color(red: 0.659, green: 0.196, blue: 0.165)
    private static let waxLight = Color(red: 0.851, green: 0.404, blue: 0.353)
    private static let waxDeep = Color(red: 0.431, green: 0.106, blue: 0.086)

    var body: some View {
        ZStack {
            Cog(teeth: 11, depth: 0.08)
                .fill(RadialGradient(colors: [Self.waxLight, Self.wax, Self.waxDeep],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            Circle()
                .strokeBorder(Self.waxDeep.opacity(0.7), lineWidth: size * 0.04)
                .padding(size * 0.14)
            BroomMark(size: size * 0.5, tint: Self.waxLight.opacity(0.9))
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.ink.opacity(0.35), radius: size * 0.05, y: size * 0.04)
    }
}

#Preview("Parcel") {
    VStack(spacing: 30) {
        Parcel(width: 180, name: "Quentin")
        Parcel(width: 180, isOpen: true, name: "Quentin", packs: Releases.welcome.packs)
    }
    .padding(30)
    .background(TableGround())
}
