import SwiftUI

extension EnvironmentValues {
    /// True on a page dressed for the patron: glass edges and captions are laid in gold leaf.
    /// See `patronDress`.
    @Entry var gilded: Bool = false
}

extension View {
    /// Dresses a page for someone who owns the no-ads purchase: the night vault behind it,
    /// glass shaded in the blue of the Notte cloth, and the edges and captions in gold leaf.
    /// Off, it is the house table and nothing else changes.
    ///
    /// Everything here is still at rest: the vault is rasterised once, and nothing on it moves.
    func patronDress(_ isOn: Bool) -> some View {
        modifier(PatronDressing(isOn: isOn))
    }
}

private struct PatronDressing: ViewModifier {
    let isOn: Bool

    @Environment(\.tableFelt) private var felt

    func body(content: Content) -> some View {
        content
            .background { if isOn { PatronGround() } else { TableGround() } }
            .environment(\.gilded, isOn)
            // Glass and anything drawn on the cloth ask the felt for their shade, so the
            // patron's page answers them in blue rather than leaving green on lapis.
            .environment(\.tableFelt, isOn ? .notte : felt)
    }
}

/// Gold leaf as the patron's pages wear it, flat: no lettering is struck in metal.
nonisolated enum PatronLeaf {
    /// The hairline round a slab of glass, catching the light at its top left.
    static let edge = LinearGradient(colors: [PatronTone.goldPale.opacity(0.95), PatronTone.gold.opacity(0.6),
                                              PatronTone.goldLight.opacity(0.85)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    /// A caption's colour: leaf seen in the dark, quiet enough to stay a caption.
    static let caption = Color(red: 0.882, green: 0.769, blue: 0.533)
}

// MARK: The vault

/// The patron's ground: lapis lit from the top left as the table is, deepening to night,
/// under a vault of gold stars set in rings that tighten towards the top, as they do over
/// Galla Placidia's tomb. The stars are struck, not lit: no glow, nothing twinkles.
struct PatronGround: View {
    /// How far the ground runs past the view it backs, as `TableGround`'s does.
    private static let bleed: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Under the texture, for the same reason `TableGround` lays its gradient twice:
                // a sheet set in from the screen's edge clips a rasterised layer short.
                base
                vault
            }
            .frame(width: proxy.size.width + Self.bleed * 2, height: proxy.size.height + Self.bleed * 2)
            .offset(x: -Self.bleed, y: -Self.bleed)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var base: some View {
        LinearGradient(colors: [Self.light, PatronTone.lapis, PatronTone.lapisDeep, PatronTone.night],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var vault: some View {
        ZStack {
            base
            RadialGradient(colors: [.white.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.14, y: 0.06), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [PatronTone.night.opacity(0.8), .clear],
                           center: UnitPoint(x: 0.94, y: 0.98), startRadius: 0, endRadius: 720)
            Canvas { context, size in
                VaultStars.set(in: &context, size: size, bleed: Self.bleed)
            }
        }
        .drawingGroup(opaque: true)
    }

    /// The lit corner: lapis, a shade brighter than the stone.
    private static let light = Color(red: 0.165, green: 0.259, blue: 0.541)
}

/// Where the vault's stars fall. Seeded, so the sky is the same on every page and every
/// redraw, and the glass that frosts over it does not see it shift.
private enum VaultStars {
    static func set(in context: inout GraphicsContext, size: CGSize, bleed: CGFloat) {
        var random = StarRandom(state: 0x6A11A_9C1A)
        // The rings centre above the top of the screen, so the page reads as the inside of a
        // dome seen from under its edge.
        let centre = CGPoint(x: size.width / 2, y: bleed - 260)
        let farthest = hypot(size.width / 2, size.height) + 40
        var reach: CGFloat = 300
        var ring = 0
        var hairlines = Path()
        while reach < farthest {
            hairlines.addEllipse(in: CGRect(x: centre.x - reach, y: centre.y - reach, width: reach * 2, height: reach * 2))
            let spacing: CGFloat = 66 + CGFloat(ring) * 3
            let count = Int(2 * .pi * reach / spacing)
            let offset = random.unit() * 2 * .pi
            for index in 0..<count {
                guard random.unit() > 0.2 else { continue }
                let angle = offset + (Double(index) + (random.unit() - 0.5) * 0.5) / Double(count) * 2 * .pi
                let lean = reach + CGFloat(random.unit() - 0.5) * 14
                let point = CGPoint(x: centre.x + cos(angle) * lean, y: centre.y + sin(angle) * lean)
                guard point.x > -10, point.x < size.width + 10, point.y > -10, point.y < size.height + 10 else { continue }
                // Smaller nearer the crown of the dome, a few bigger ones among them.
                let grade = min(Double(ring) / 9, 1)
                let radius = CGFloat(random.unit() > 0.93 ? 6.2 : 2.2 + grade * 1.6 + random.unit() * 1.4)
                // Quiet enough that one falling behind a line of type does not trip the eye.
                PatronStar.strike(in: &context, at: point, radius: radius, faceted: radius > 3.4,
                                  opacity: 0.38 + random.unit() * 0.32)
            }
            reach += 92
            ring += 1
        }
        // The rings themselves, engraved so faintly they are felt more than seen.
        context.stroke(hairlines, with: .color(PatronTone.goldLight.opacity(0.07)), lineWidth: 0.75)
    }
}

/// Xorshift, as the table's grain uses.
private struct StarRandom {
    var state: UInt64

    mutating func unit() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: Gold leaf

/// Gold leaf laid the way a gilder lays it: square sheets in rows, each a shade off its
/// neighbours, the seams showing where one overlaps the next. For the celebration's plaque.
struct LeafSheets: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [PatronTone.goldPale, PatronTone.goldLight, PatronTone.gold, PatronTone.goldDeep]),
                startPoint: .zero, endPoint: CGPoint(x: size.width * 0.8, y: size.height)))
            sheets(&context, size)
        }
        .drawingGroup(opaque: true)
        .accessibilityHidden(true)
    }

    private func sheets(_ context: inout GraphicsContext, _ size: CGSize) {
        var random = StarRandom(state: 0x601D_1EAF)
        let side: CGFloat = 46
        var brighter = Path(), duller = Path(), seams = Path(), lips = Path()
        var y: CGFloat = -6
        while y < size.height {
            var x = -CGFloat(random.unit()) * side
            while x < size.width {
                let sheet = CGRect(x: x, y: y, width: side + CGFloat(random.unit()) * 4, height: side)
                let shade = random.unit()
                if shade > 0.66 { brighter.addRect(sheet) } else if shade < 0.3 { duller.addRect(sheet) }
                seams.move(to: CGPoint(x: sheet.minX, y: sheet.maxY))
                seams.addLine(to: CGPoint(x: sheet.minX, y: sheet.minY))
                seams.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY))
                lips.move(to: CGPoint(x: sheet.minX + 0.8, y: sheet.maxY))
                lips.addLine(to: CGPoint(x: sheet.minX + 0.8, y: sheet.minY + 0.8))
                lips.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + 0.8))
                x = sheet.maxX - 2
            }
            y += side - 2
        }
        context.fill(brighter, with: .color(PatronTone.goldPale.opacity(0.11)))
        context.fill(duller, with: .color(PatronTone.goldShadow.opacity(0.06)))
        context.stroke(seams, with: .color(PatronTone.goldShadow.opacity(0.13)), lineWidth: 0.5)
        context.stroke(lips, with: .color(PatronTone.goldPale.opacity(0.22)), lineWidth: 0.5)
    }
}

/// A plaque of gold leaf with an engraved border: two rules and a row of punched beads.
struct GildedPlaque<Content: View>: View {
    var radius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .background { LeafSheets().clipShape(shape) }
            .overlay { border }
            .shadow(color: PatronTone.night.opacity(0.55), radius: 18, y: 10)
    }

    private var border: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(PatronTone.goldShadow.opacity(0.75), lineWidth: 1.2)
            RoundedRectangle(cornerRadius: radius - 7, style: .continuous)
                .inset(by: 0.75)
                .stroke(PatronTone.goldDeep, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [0, 6.5]))
                .padding(7)
            RoundedRectangle(cornerRadius: radius - 12, style: .continuous)
                .strokeBorder(PatronTone.goldShadow.opacity(0.6), lineWidth: 0.7)
                .padding(12)
        }
        .allowsHitTesting(false)
    }
}

/// A round window of night sky cut into the gold, its rim ruled twice: where the crest sits.
struct VaultRoundel: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [PatronTone.lapisLight, PatronTone.lapis, PatronTone.lapisDeep],
                                     center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.62))
            Canvas { context, canvas in
                let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                var random = StarRandom(state: 0x5EA1)
                for index in 0..<18 {
                    let angle = Double(index) / 18 * 2 * .pi + random.unit() * 0.2
                    let reach = canvas.width * (0.40 + CGFloat(random.unit()) * 0.05)
                    PatronStar.strike(in: &context, at: CGPoint(x: c.x + cos(angle) * reach, y: c.y + sin(angle) * reach),
                                      radius: 2 + random.unit() * 1.8, faceted: false, opacity: 0.85)
                }
            }
            Circle().strokeBorder(PatronTone.goldShadow, lineWidth: 3)
            Circle().strokeBorder(PatronTone.goldPale.opacity(0.7), lineWidth: 1).padding(3)
        }
        .frame(width: size, height: size)
        .shadow(color: PatronTone.goldShadow.opacity(0.6), radius: 1, y: -1)
        .accessibilityHidden(true)
    }
}

#Preview("The patron's ground") {
    ZStack {
        PatronGround()
        VStack(spacing: 24) {
            GildedPlaque {
                ZStack {
                    VaultRoundel(size: 190)
                    PatronCrest(size: 150)
                }
                .padding(.vertical, 26)
            }
            Caption(text: "Patron of the house")
        }
        .padding(24)
        .environment(\.gilded, true)
    }
}
