import SwiftUI
import ScopaCore

/// Corner radii shared by everything made of glass, so a control sitting inside a panel
/// stays concentric with it.
enum GlassRadius {
    static let chip: CGFloat = 14
    static let control: CGFloat = 18
    static let panel: CGFloat = 26
}

/// Liquid Glass arrived with iOS 26, and the app runs back to iOS 18. Everything below
/// draws the real thing where it exists and a tinted material where it does not, so no
/// screen has to know which it is standing on.
enum LiquidGlass {
    /// True on iOS 26 and later, where the system draws the glass itself.
    static var isAvailable: Bool {
        if #available(iOS 26, *) { return true } else { return false }
    }
}

/// A slab of glass, described without naming `Glass`, which does not exist on iOS 18.
struct GlassStyle: Equatable {
    var tint: Color?
    var interactive: Bool
    /// Draws nothing at all. Used where a control is glass only while it is selected.
    var isIdentity = false

    static let identity = GlassStyle(tint: nil, interactive: false, isIdentity: true)

    /// `Glass.regular`, optionally tinted and made pressable.
    ///
    /// Untinted glass over the table comes out pale and cream lettering vanishes on it, so
    /// the default takes a little of the table's own shadow.
    static func riviera(tint: Color? = nil, interactive: Bool = false) -> GlassStyle {
        GlassStyle(tint: tint, interactive: interactive)
    }

    /// The colour the slab carries, once the default shadow is filled in. Untinted glass
    /// takes the shadow of whichever cloth is on the table, so a panel over the wine felt
    /// is not shaded green.
    func fillTint(on felt: TableFelt) -> Color { tint ?? felt.shade(0.45) }
}

@available(iOS 26, *)
extension GlassStyle {
    func liquid(on felt: TableFelt) -> Glass {
        if isIdentity { return .identity }
        let glass = Glass.regular.tint(fillTint(on: felt))
        return interactive ? glass.interactive() : glass
    }
}

/// Draws the slab. A modifier rather than a plain `background`, because the default tint
/// is the cloth's, and only a view can read which cloth that is.
private struct Glazing<S: Shape>: ViewModifier {
    let style: GlassStyle
    let shape: S

    @Environment(\.tableFelt) private var felt

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(style.liquid(on: felt), in: shape)
        } else if style.isIdentity {
            content
        } else {
            content.background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(style.fillTint(on: felt))
                    shape.stroke(Palette.cream.opacity(0.10), lineWidth: 1)
                }
            }
        }
    }
}

extension View {
    /// Liquid Glass on iOS 26. On iOS 18, a dark material carrying the same tint.
    func glass(_ style: GlassStyle, in shape: some Shape) -> some View {
        modifier(Glazing(style: style, shape: shape))
    }

    /// Keeps a piece of glass's identity as it moves between layouts, where the system
    /// can morph it. Nothing to do where the system cannot.
    @ViewBuilder
    func glassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// Glass that materialises rather than fades when it appears.
    @ViewBuilder
    func glassMaterialize() -> some View {
        if #available(iOS 26, *) {
            glassEffectTransition(.materialize)
        } else {
            self
        }
    }

    /// Content dissolving softly under whatever is pinned over that edge of a scroll view.
    @ViewBuilder
    func softScrollEdge(_ edge: Edge.Set) -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: edge)
        } else {
            self
        }
    }

    /// Floats the view above the table on a slab of glass.
    ///
    /// The `contentShape` is required: glass draws behind the view and contributes nothing
    /// hit-testable, so without it a button is only tappable on its own lettering.
    ///
    /// `hairline` is off only where something else draws the edge — a `LeagueRim`, say —
    /// since two lines a point apart read as a smudge rather than as two.
    func glassPanel(radius: CGFloat = GlassRadius.panel, tint: Color? = nil, interactive: Bool = false,
                    hairline: Bool = true) -> some View {
        glass(.riviera(tint: tint, interactive: interactive), in: .rect(cornerRadius: radius))
            .overlay {
                if hairline {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(Palette.gold.opacity(0.30), lineWidth: 1)
                }
            }
            .contentShape(.rect(cornerRadius: radius))
    }

    /// The same, fully rounded, for chips, pills and badges.
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        glass(.riviera(tint: tint, interactive: interactive), in: .capsule)
            .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.30), lineWidth: 1) }
            .contentShape(.capsule)
    }
}

/// Neighbouring pieces of glass that may merge and morph into one another. On iOS 18 it
/// is only the layout it wraps.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// The table ground: bottle green lit from the top left, deepening into the bottom right,
/// with a gold burst behind the middle.
///
/// The gradients also give Liquid Glass something to refract. Over flat linen it read as
/// frosted plastic.
struct TableGround: View {
    /// How far the ground runs past the view it backs: enough to cover any safe area, the
    /// deepest being the banner strip at under 90 points, and no more. The ground is
    /// rasterised whole, so every point of bleed costs pixels on each side.
    private static let bleed: CGFloat = 120

    @Environment(\.tableFelt) private var felt
    @Environment(\.tapis) private var tapis

    var body: some View {
        // Not `ignoresSafeArea`: a background that ignores it drags the content out with
        // it, which put the score row under the Dynamic Island. Oversizing and centring
        // bleeds just as well and leaves the layout alone.
        GeometryReader { proxy in
            ZStack {
                // The cloth's own gradient, laid under the texture and never baked into
                // it. A rasterised layer inside a presented sheet is clipped to the bounds
                // it was measured at, and iOS 26 sets a sheet in from the edge of the
                // screen, which left a strip down the sheet's right-hand side with the
                // system's own dark backing showing through it. Drawn at the same size as
                // the texture over it, so the two line up and that strip is still felt.
                // One gradient is nothing to blend: it is the three over it and the grain
                // that are worth baking.
                base
                ground
            }
            .frame(width: proxy.size.width + Self.bleed * 2,
                   height: proxy.size.height + Self.bleed * 2)
            .offset(x: -Self.bleed, y: -Self.bleed)
        }
        .allowsHitTesting(false)
    }

    private var base: some View {
        LinearGradient(colors: [felt.light, felt.base, felt.deep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rasterised into one opaque texture, redrawn only when the felt or the screen
    /// changes. Left live, the gradients and the grain are five full-screen surfaces to
    /// blend on every frame anything on the table moves — which is what a table does.
    ///
    /// It carries the base gradient again rather than sitting on the one below: the
    /// texture is opaque and covers it, and a sheet where the texture is clipped short is
    /// the only place the lower one is ever seen.
    private var ground: some View {
        ZStack {
            base
            RadialGradient(colors: [.white.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.14, y: 0.08), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [felt.deep.opacity(0.85), .clear],
                           center: UnitPoint(x: 0.94, y: 0.98), startRadius: 0, endRadius: 720)
            RadialGradient(colors: [Palette.gold.opacity(0.13), .clear],
                           center: UnitPoint(x: 0.5, y: 0.34), startRadius: 0, endRadius: 480)
            // Under the grain, and told about the bleed so its border lands on the edge of
            // the screen rather than the edge of the oversized texture.
            TapisWeave(tapis: tapis, bleed: Self.bleed)
            Grain()
        }
        .drawingGroup(opaque: true)
    }
}

/// A sparse dot grain. Seeded rather than random, so it holds still while glass moves over it.
private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            // One path and one fill: separate fills would be a draw call per dot.
            var generator = Seeded(state: 0x5C09A_B411)
            var dots = Path()
            for _ in 0..<Int(size.width * size.height / 900) {
                let x = CGFloat.random(in: 0..<size.width, using: &generator)
                let y = CGFloat.random(in: 0..<size.height, using: &generator)
                dots.addEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
            }
            context.fill(dots, with: .color(Palette.cream.opacity(0.05)))
        }
        .allowsHitTesting(false)
    }
}

/// Xorshift, so the grain is the same every redraw.
private struct Seeded: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private extension View {
    /// The press response interactive glass gives on iOS 26, drawn by hand on iOS 18.
    func pressed(_ isPressed: Bool) -> some View {
        let pressed = isPressed && !LiquidGlass.isAvailable
        return scaleEffect(pressed ? 0.97 : 1)
            .opacity(pressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

/// The primary action, in tinted glass. `interactive` hands the press response to the
/// system on iOS 26, so this style only adds one of its own where the system has none.
struct FilledButtonStyle: ButtonStyle {
    var tint: Color = Palette.terracotta
    var foreground: Color = Palette.cream
    var minHeight: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .glassPanel(radius: GlassRadius.control, tint: tint, interactive: true)
            .pressed(configuration.isPressed)
    }
}

/// The secondary action: clear glass, ink lettering.
struct OutlineButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.onTable)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .glassPanel(radius: GlassRadius.control, interactive: true)
            .pressed(configuration.isPressed)
    }
}

/// A round seat badge carrying an initial. Stays solid rather than glass: it is an
/// identity token and has to keep its colour wherever it lands.
///
/// An earned mark wears its `Prestige` round the circle, plates behind and a rim over the
/// edge. Both overflow the frame without changing it. See `Prestige.reach`.
struct SeatBadge: View {
    var name: String
    var tint: Color
    var size: CGFloat = 36
    /// What sits in the circle: the initial unless the player chose a mark.
    var mark: SeatMark = .initial
    /// Finished the week's challenge. Drawn outside everything else, see `HonourWreath`.
    var honoured = false
    /// What they bought to go round it, in cloth and paint rather than metal.
    var cornice: Cornice = .none
    /// The colour the circle is struck in. `tavolo` keeps `tint`, which is the chair the
    /// table dealt them, so every badge that never asks for a livery looks as it always did.
    var livery: SeatLivery = .tavolo

    var body: some View {
        Circle()
            .fill(livery.style(seat: tint))
            .frame(width: size, height: size)
            .overlay { emblem }
            .overlay { Circle().strokeBorder(Palette.cream.opacity(0.35), lineWidth: size * 0.04) }
            .overlay { livery.edge(size: size) }
            .background { PrestigePlate(tier: mark.prestige, size: size) }
            .overlay { PrestigeRim(tier: mark.prestige, size: size) }
            // Outside the rim, so a hundred wins and this week's laurel can be worn at once.
            .background { if honoured { HonourWreath(size: size) } }
            // Outside all of it and last, so a bought ring never covers earned metal. The
            // outset has to clear whatever the badge already wears, out to 1.52 for armour.
            .background {
                CorniceRing(cornice: cornice, size: size,
                            outset: max(mark.prestige.reach, honoured ? 1.3 : 1))
            }
    }

    /// How far everything the badge wears reaches past its own circle, as a multiple of
    /// `size`: the widest of earned metal, the week's laurel and a bought ring.
    static func reach(mark: SeatMark = .initial, honoured: Bool = false,
                      cornice: Cornice = .none) -> CGFloat {
        let outset = max(mark.prestige.reach, honoured ? 1.3 : 1)
        return max(mark.prestige.reach,
                   honoured ? HonourWreath.reach : 1,
                   cornice == .none ? 1 : outset * cornice.spread)
    }

    /// The circle to strike a badge of nominal `size` on, where it stands in a slot cut
    /// for a laurel: a panel's corner, a pill. Everything worn then stays inside the room
    /// the bare laurel takes, so a bought ring costs the circle its own width rather than
    /// the panel it sits in.
    static func fitted(_ size: CGFloat, mark: SeatMark = .initial, honoured: Bool = false,
                       cornice: Cornice = .none) -> CGFloat {
        size * min(1, HonourWreath.reach / reach(mark: mark, honoured: honoured, cornice: cornice))
    }

    @ViewBuilder private var emblem: some View {
        switch mark {
        case .initial:
            Text(name.prefix(1).uppercased())
                .font(.display(size * 0.55))
                .foregroundStyle(livery.emblem)
        case .broom:
            BroomMark(size: size * 0.52, tint: livery.emblem)
        case .coins, .cups, .swords, .clubs:
            // The pip the cards are drawn with, in the cream every other mark is drawn in:
            // a mark is a silhouette on a coloured seat, and a gold coin on a gold seat
            // would be the one mark nobody could make out across a table.
            SuitArt(style: .moderna, suit: mark.suit ?? .coins, size: size * 0.52,
                    colour: livery.emblem, accent: livery.emblem, ink: Palette.ink)
        case .settebello:
            // The card the whole album is short of last: its pip, with its number struck
            // through the middle of it in the seat's own colour.
            SuitArt(style: .moderna, suit: .coins, size: size * 0.6,
                    colour: livery.emblem, accent: livery.emblem, ink: Palette.ink)
                .overlay {
                    Text(verbatim: "7")
                        .font(.display(size * 0.34))
                        .foregroundStyle(livery.style(seat: tint))
                }
        default:
            Image(systemName: mark.symbol ?? "circle.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(livery.emblem)
        }
    }
}

/// A small rounded label, used for piles, scopa counts and hints.
struct Pill: View {
    var text: LocalizedStringKey
    var tint: Color?
    var foreground: Color = Palette.onTable

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCapsule(tint: tint)
    }
}

/// An uppercase section label.
///
/// Takes a key rather than a `String`, because `Text(someString)` renders verbatim and
/// leaves the caption in English. Uppercasing is left to `textCase`, which uses the
/// interface locale.
struct Caption: View {
    var text: LocalizedStringKey
    /// A name that is the same word in every language, like a deck called Napoli.
    private var asIs: String?

    init(text: LocalizedStringKey) {
        self.text = text
    }

    init(verbatim: String) {
        self.text = ""
        self.asIs = verbatim
    }

    var body: some View {
        Group {
            if let asIs { Text(verbatim: asIs) } else { Text(text) }
        }
        .textCase(.uppercase)
        .font(.system(size: 12, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(Palette.onTableSoft)
    }
}

/// A hairline that survives the table. `Divider`'s system grey disappears on bottle green.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Palette.onTableSoft.opacity(0.28))
            .frame(height: 1)
    }
}
