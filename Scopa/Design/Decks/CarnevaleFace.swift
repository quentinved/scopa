import SwiftUI
import ScopaCore

/// The Carnevale deck: an old printed Venetian deck. Ivory stock inside a harlequin band, the
/// rank in a cartouche at two corners, masked figures for the court.
struct CarnevaleFace: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width * 1.5 }
    private var isSettebello: Bool { card == .settebello }

    var body: some View {
        ZStack {
            Rectangle().fill(Carnevale.stock)
            CarnevaleFrame(suit: card.suit, width: width)
            centre
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) { CarnevaleIndex(rank: card.rank, width: width) }
        .overlay(alignment: .bottomTrailing) {
            CarnevaleIndex(rank: card.rank, width: width).rotationEffect(.degrees(180))
        }
        .overlay { CarnevaleEdge(suit: card.suit, settebello: isSettebello, width: width) }
    }

    @ViewBuilder private var centre: some View {
        if card.rank.isFace {
            CarnevaleCourt(rank: card.rank, suit: card.suit, width: width * 0.86, height: width * 1.30)
        } else if isSettebello {
            CarnevaleSettebello(width: width)
        } else if card.rank == .ace {
            ZStack {
                CarnevaleDoily(size: width * 0.80, gilt: card.suit == .coins)
                CarnevalePip(suit: card.suit, size: width * 0.56)
            }
        } else {
            CarnevalePipField(suit: card.suit, count: card.rank.rawValue,
                              area: CGSize(width: width * 0.60, height: width * 0.94))
        }
    }
}

/// The deck's inks and the namespace for its shapes.
enum Carnevale {
    static let stock = Color(red: 0.973, green: 0.949, blue: 0.890)
    static let ink = Color(red: 0.110, green: 0.086, blue: 0.082)
    /// A cloak's black, a shade off the ink so its outline still reads.
    static let cloak = Color(red: 0.180, green: 0.157, blue: 0.165)
    static let red = Color(red: 0.639, green: 0.122, blue: 0.141)
    static let gold = Color(red: 0.835, green: 0.627, blue: 0.220)
    static let paleGold = Color(red: 0.945, green: 0.812, blue: 0.459)
    static let ochre = Color(red: 0.580, green: 0.400, blue: 0.122)
    static let teal = Color(red: 0.090, green: 0.435, blue: 0.467)
    static let lacquer = Color(red: 0.235, green: 0.165, blue: 0.137)
    /// The white of a bauta, a glove, a stocking: whiter than the stock.
    static let white = Color(red: 0.996, green: 0.988, blue: 0.965)
    static let flesh = Color(red: 0.961, green: 0.851, blue: 0.749)
    static let locks = Color(red: 0.310, green: 0.204, blue: 0.141)

    static func colour(of suit: Suit) -> Color {
        switch suit {
        case .coins: gold
        case .cups: red
        case .swords: teal
        case .clubs: lacquer
        }
    }

    /// Unit coordinates inside a rect, for drawing a shape once at any size.
    static func unit(_ r: CGRect) -> (CGFloat, CGFloat) -> CGPoint {
        { x, y in CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
    }
}

/// The harlequin band inside the card edge: red and black lozenges between gold rules, gold
/// and red on a coin. A thin rule alone on small cards, where lozenges are only noise.
struct CarnevaleFrame: View {
    let suit: Suit
    let width: CGFloat

    private static let inset: CGFloat = 0.04
    private static let thickness: CGFloat = 0.05
    private var line: CGFloat { max(0.5, width * 0.010) }

    var body: some View {
        if width >= 56 {
            band
        } else {
            Rectangle()
                .strokeBorder(Carnevale.red.opacity(0.7), lineWidth: line)
                .padding(width * 0.06)
        }
    }

    private var band: some View {
        let coin = suit == .coins
        let i = Self.inset
        let t = Self.thickness
        return ZStack {
            Carnevale.HarlequinBand(inset: i, thickness: t, phase: 0).fill(coin ? Carnevale.gold : Carnevale.red)
            Carnevale.HarlequinBand(inset: i, thickness: t, phase: 1).fill(coin ? Carnevale.red : Carnevale.ink)
            Carnevale.BandCorners(inset: i, thickness: t).fill(Carnevale.gold)
            Rectangle().strokeBorder(Carnevale.gold, lineWidth: line).padding(width * i)
            Rectangle().strokeBorder(Carnevale.gold, lineWidth: line).padding(width * (i + t))
            if width >= 80 {
                Carnevale.LaceEdge(inset: i + t, span: 0.036)
                    .stroke(Carnevale.gold.opacity(0.8), lineWidth: line * 0.8)
            }
        }
    }
}

/// The rank in an ivory cartouche over the band's corner.
struct CarnevaleIndex: View {
    let rank: Rank
    let width: CGFloat

    var body: some View {
        let framed = width >= 56
        let shape = UnevenRoundedRectangle(topLeadingRadius: width * 0.06, bottomLeadingRadius: width * 0.02,
                                           bottomTrailingRadius: width * 0.06, topTrailingRadius: width * 0.02)
        VStack(spacing: width * 0.012) {
            Text(verbatim: rank.label)
                .font(.display(width * 0.26))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Carnevale.ink)
                .frame(width: width * 0.26, height: width * 0.21)
            // A six and a nine read as each other upside down, so they get a rule under them.
            if rank == .six || rank == .knight {
                Rectangle().fill(Carnevale.ink).frame(width: width * 0.12, height: max(1, width * 0.018))
            }
        }
        .frame(width: width * 0.28, height: width * 0.28)
        .background { shape.fill(Carnevale.stock) }
        .overlay { if framed { shape.stroke(Carnevale.gold, lineWidth: max(0.6, width * 0.012)) } }
        .padding(width * (framed ? 0.04 : 0.05))
    }
}

/// The edge `CardView` draws round a card, here so the draft shows it: gold on a coin,
/// heavier on the settebello.
struct CarnevaleEdge: View {
    let suit: Suit
    let settebello: Bool
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12)
            .strokeBorder(colour, lineWidth: settebello ? 2 : (suit == .coins ? 1.5 : 1))
    }

    private var colour: Color {
        if settebello { return Carnevale.gold }
        return suit == .coins ? Carnevale.gold.opacity(0.75) : Carnevale.ink.opacity(0.16)
    }
}

/// A lace doily behind an ace, gilt behind a coin.
struct CarnevaleDoily: View {
    let size: CGFloat
    var gilt = false

    var body: some View {
        let line = max(0.5, size * 0.012)
        let rim = Carnevale.Scalloped(count: 24, depth: 0.07)
        ZStack {
            rim.fill(gilt ? Carnevale.paleGold.opacity(0.32) : Carnevale.white)
            rim.stroke(Carnevale.gold, lineWidth: line)
            Carnevale.DotRing(count: 24, radius: 0.84, dot: 0.022).fill(Carnevale.gold.opacity(0.85))
            Circle().stroke(Carnevale.gold, lineWidth: line).padding(size * 0.11)
            Circle().stroke(Carnevale.gold.opacity(0.6), lineWidth: line * 0.7).padding(size * 0.135)
        }
        .frame(width: size, height: size)
    }
}

/// The seven of coins: its pips on a gilt doily, raised to leave room for its name on a ribbon.
struct CarnevaleSettebello: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            CarnevaleDoily(size: width * 0.80, gilt: true)
                .offset(y: -width * 0.11)
            CarnevalePipField(suit: .coins, count: 7, area: CGSize(width: width * 0.56, height: width * 0.74))
                .offset(y: -width * 0.11)
            if width >= 70 { ribbon.offset(y: width * 0.35) }
        }
    }

    private var ribbon: some View {
        let banner = Carnevale.Banner()
        return Text(verbatim: "SETTEBELLO")
            .font(.system(size: width * 0.058, weight: .bold, design: .serif))
            .tracking(width * 0.006)
            .foregroundStyle(Carnevale.paleGold)
            .frame(width: width * 0.56, height: width * 0.10)
            .background { banner.fill(Carnevale.red) }
            .overlay { banner.stroke(Carnevale.ink, lineWidth: max(0.5, width * 0.008)) }
    }
}
