import ScopaCore
import ScopaRewards
import SwiftUI

/// How rarity is drawn: one palette for the cards in the album, one for the things on the
/// shelves, and one ribbon that prints either.
///
/// The two scales are deliberately different colours. A card's rarity is a fact about the
/// deck — everybody's settebello is the same card — so it is drawn in the game's own gold
/// and terracotta. A shop grade is a fact about how few people have the thing, so it climbs
/// through cold colours to gold, which is the one colour both scales end on because both
/// scales end on "the best there is".
enum Rarities {
    // MARK: Cards

    static func tint(_ rarity: Rarity) -> Color {
        switch rarity {
        case .plain: Palette.onTableSoft
        // Lighter than `Palette.seaGlaze`, which is mixed for a cream ground and vanishes
        // on the cloth at tag size.
        case .court: Color(red: 0.561, green: 0.729, blue: 0.878)
        case .prime: Color(red: 0.918, green: 0.502, blue: 0.396)
        case .settebello: Palette.goldLight
        }
    }

    /// The band behind a card as it turns over. Flat for a numeral, because a numeral is
    /// not an event; a sweep of light for everything above it.
    static func sheen(_ rarity: Rarity) -> AnyShapeStyle {
        switch rarity {
        case .plain:
            AnyShapeStyle(tint(rarity).opacity(0.5))
        case .settebello:
            AnyShapeStyle(AngularGradient(
                colors: [Palette.goldLight, .white, Palette.gold, Palette.goldLight,
                         .white, Palette.goldDeep, Palette.goldLight],
                center: .center))
        default:
            AnyShapeStyle(LinearGradient(colors: [tint(rarity), tint(rarity).opacity(0.35)],
                                         startPoint: .top, endPoint: .bottom))
        }
    }

    /// How many rays go behind a card of this rarity when it turns over, and nothing at
    /// all for a numeral. A pack of three numerals should look like three numerals.
    static func rays(_ rarity: Rarity) -> Int {
        switch rarity {
        case .plain: 0
        case .court: 12
        case .prime: 18
        case .settebello: 28
        }
    }

    /// What a card of this rarity is called on a tile, in the interface's own language.
    static func title(_ rarity: Rarity, locale: Locale) -> String {
        switch rarity {
        case .plain: String(localized: "Numeral", locale: locale)
        case .court: String(localized: "Court", locale: locale)
        case .prime: String(localized: "Seven", locale: locale)
        // A name, and the same word everywhere.
        case .settebello: "Settebello"
        }
    }

    // MARK: Shop grades

    static func tint(_ grade: Grade) -> Color {
        switch grade {
        case .comune: Palette.onTableSoft
        case .raro: Color(red: 0.561, green: 0.729, blue: 0.878)
        case .prezioso: Color(red: 0.757, green: 0.565, blue: 0.886)
        case .leggendario: Palette.goldLight
        }
    }

    static func sheen(_ grade: Grade) -> AnyShapeStyle {
        switch grade {
        case .comune:
            AnyShapeStyle(tint(grade).opacity(0.45))
        case .leggendario:
            AnyShapeStyle(AngularGradient(
                colors: [Palette.goldLight, .white, Palette.gold, Palette.goldLight,
                         .white, Palette.goldDeep, Palette.goldLight],
                center: .center))
        default:
            AnyShapeStyle(LinearGradient(colors: [tint(grade), tint(grade).opacity(0.35)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

/// The little uppercase word that names a rarity or a grade.
///
/// One view for both scales, taking the words and the colour rather than the enum, so the
/// album and the shop cannot drift into printing the same idea two ways.
struct RarityTag: View {
    var text: String
    var tint: Color
    var sheen: AnyShapeStyle?
    var size: CGFloat = 10.5
    /// Filled tags are for the moment a thing is won; outlined ones are for a shelf, where
    /// a page of filled tags would be a page of shouting.
    var filled = false

    var body: some View {
        Text(verbatim: text.uppercased())
            .font(.system(size: size, weight: .heavy))
            .tracking(1.1)
            // "Settebello" and "Leggendario" are twice the length of "Raro" and these tags
            // sit in rows sized for the short ones.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(filled ? Palette.ink : tint)
            .padding(.horizontal, size * 0.72)
            .padding(.vertical, size * 0.26)
            .background {
                if filled {
                    Capsule().fill(sheen ?? AnyShapeStyle(tint))
                } else {
                    Capsule().strokeBorder(tint.opacity(0.75), lineWidth: 1)
                }
            }
            .accessibilityLabel(Text(verbatim: text))
    }
}

extension RarityTag {
    init(_ rarity: Rarity, locale: Locale, size: CGFloat = 10.5, filled: Bool = false) {
        self.init(text: Rarities.title(rarity, locale: locale), tint: Rarities.tint(rarity),
                  sheen: Rarities.sheen(rarity), size: size, filled: filled)
    }

    init(_ grade: Grade, size: CGFloat = 10.5, filled: Bool = false) {
        self.init(text: grade.title, tint: Rarities.tint(grade), sheen: Rarities.sheen(grade),
                  size: size, filled: filled)
    }
}

/// Rays behind something that has just been turned over, at the weight its rarity asks for.
///
/// Drawn rather than animated per ray: one rotation and one scale over the whole wheel,
/// which is the difference between a burst and twenty-eight things to keep in step.
struct RarityBurst: View {
    var count: Int
    var tint: Color
    var size: CGFloat

    @State private var turn: Double = 0
    @State private var bloom: CGFloat = 0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 {
            ZStack {
                RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.0)],
                               center: .center, startRadius: 0, endRadius: size * 0.55)
                Rays(count: count)
                    .fill(RadialGradient(colors: [tint.opacity(0.0), tint.opacity(0.7), tint.opacity(0.0)],
                                         center: .center, startRadius: size * 0.16,
                                         endRadius: size * 0.6))
                    .rotationEffect(.degrees(turn))
            }
            .frame(width: size, height: size)
            .scaleEffect(bloom)
            .opacity(Double(min(bloom, 1)))
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(duration: 0.55, bounce: 0.3)) { bloom = 1 }
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                    turn = 360
                }
            }
        }
    }

    private struct Rays: Shape {
        var count: Int

        func path(in rect: CGRect) -> Path {
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) * 0.5
            let half = .pi / Double(count) * 0.38
            var path = Path()
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * .pi
                path.move(to: centre)
                path.addLine(to: CGPoint(x: centre.x + cos(angle - half) * outer,
                                         y: centre.y + sin(angle - half) * outer))
                path.addLine(to: CGPoint(x: centre.x + cos(angle + half) * outer,
                                         y: centre.y + sin(angle + half) * outer))
                path.closeSubpath()
            }
            return path
        }
    }
}
