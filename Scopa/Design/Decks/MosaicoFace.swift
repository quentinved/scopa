import SwiftUI
import ScopaCore

/// The Mosaico deck's face: the forty cards as a Ravenna workshop would have set them.
/// Numerals on a marble ground inside a lapis border, courts on gold leaf, and the
/// settebello under Galla Placidia's starry blue.
///
/// Every tessera is placed by a generator seeded with the card, so a face is set the same
/// way each time, and drawn in one `Canvas` as a few dozen fills. Setting it is the dear
/// part, so `MosaicoSettings` does it once per card and size.
struct MosaicoFace: View {
    let card: Card
    let width: CGFloat

    private var isCourt: Bool { card.rank.isFace }
    private var isSettebello: Bool { card == .settebello }
    private var ink: Color { isSettebello ? Smalto.goldPale.colour : Smalto.lapisDeep.colour }

    var body: some View {
        let work = MosaicoSettings.face(card, width: width)
        Canvas { context, _ in work.draw(in: context) }
        .frame(width: width, height: width * 1.5)
        .overlay(alignment: .topLeading) { index }
        .overlay(alignment: .bottomTrailing) { index.rotationEffect(.degrees(180)) }
        .overlay(alignment: .bottom) { caption }
    }

    /// The rank, as every deck prints it. A court's sits on a marble tablet so the figure
    /// behind it cannot swallow it.
    private var index: some View {
        VStack(spacing: width * 0.02) {
            Text(verbatim: "\(card.rank.rawValue)")
                .font(.display(width * 0.26))
                .foregroundStyle(ink)
            // A six and a nine read as each other upside down, so they get a rule under them.
            if card.rank == .six || card.rank == .knight {
                Rectangle().fill(ink).frame(width: width * 0.13, height: max(1, width * 0.018))
            }
        }
        .padding(.horizontal, isCourt ? width * 0.025 : 0)
        .padding(.bottom, isCourt && card.rank == .knight ? width * 0.025 : 0)
        .background { if isCourt { tablet } }
        .padding(.horizontal, isCourt ? width * 0.062 : width * 0.085)
        .padding(.vertical, isCourt ? width * 0.058 : width * 0.05)
    }

    private var tablet: some View {
        RoundedRectangle(cornerRadius: width * 0.035)
            .fill(Smalto.stonePale.colour)
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.035)
                    .strokeBorder(Smalto.lapisDeep.colour, lineWidth: max(0.7, width * 0.014))
            }
    }

    @ViewBuilder private var caption: some View {
        if isSettebello && width >= 70 {
            Text(verbatim: "SETTEBELLO")
                .font(.system(size: width * 0.06, weight: .bold))
                .tracking(width * 0.006)
                .foregroundStyle(Smalto.goldPale.colour)
                .padding(.bottom, width * 0.085)
        }
    }
}

/// What goes where on one card, and how fine it is set.
struct MosaicoCard {
    let card: Card
    let size: CGSize

    private var w: CGFloat { size.width }
    private var radius: CGFloat { w * 0.12 }
    private var framePitch: CGFloat { w * 0.026 }
    private var isSettebello: Bool { card == .settebello }

    func set() -> MosaicoWork {
        var mosaic = MosaicoWork(seed: seed, detailed: w >= 50)
        let frame = frameCourses
        let inset = framePitch * CGFloat(frame.count)
        if card.rank.isFace { court(&mosaic, inset: inset) } else { numeral(&mosaic, inset: inset) }
        mosaic.frame(size, radius: radius, pitch: framePitch, courses: frame, grout: .groutNight)
        return mosaic
    }

    private var seed: UInt64 {
        UInt64(Suit.allCases.firstIndex(of: card.suit) ?? 0) * 16 + UInt64(card.rank.rawValue)
    }

    /// Lapis round every card; coins add a fillet of gold inside it.
    private var frameCourses: [Smalti] {
        if isSettebello { return [.lapisEdge, .gold] }
        if card.suit == .coins && !card.rank.isFace { return [.lapisEdge, .lapisGround, .gold] }
        return [.lapisEdge, .lapisGround]
    }

    private func numeral(_ mosaic: inout MosaicoWork, inset: CGFloat) {
        let pitch = w * 0.04
        let ground: Smalti = isSettebello ? .lapisGround : .stoneGround
        let grout: Smalto = isSettebello ? .groutNight : .groutStone
        mosaic.ground(size, radius: radius, inset: inset, pitch: pitch, material: ground, grout: grout)
        let (pip, centres) = layout
        if isSettebello {
            mosaic.stars(size, pitch: pitch * 0.8, avoiding: centres, reach: pip * 0.5 + pitch * 2.2)
        }
        // Figures are set finer than the ground behind them, and never so fine as to blur.
        // Laid flat there is no tessera to blur, so the bands keep the pip's own proportions.
        let pipPitch = mosaic.detailed ? min(max(pip * 0.085, 1.4), pitch * 0.7) : pip * 0.085
        mosaic.emblems(card.suit, at: centres, size: pip, pitch: pipPitch, ring: (ground, pitch, grout))
    }

    /// `PipField`'s rows in `CardArt`'s pip column. The ace alone is drawn larger, a slender
    /// sword or cudgel larger still.
    private var layout: (CGFloat, [CGPoint]) {
        let centre = CGPoint(x: w / 2, y: size.height / 2)
        if card.rank == .ace { return (w * (card.suit == .swords || card.suit == .clubs ? 0.86 : 0.72), [centre]) }
        let area = CGSize(width: w * 0.60, height: w * (isSettebello ? 0.86 : 0.94))
        let box = CGRect(x: centre.x - area.width / 2, y: centre.y - area.height / 2,
                         width: area.width, height: area.height)
        return MosaicoPipLayout.place(card.rank.rawValue, in: box)
    }

    private func court(_ mosaic: inout MosaicoWork, inset: CGFloat) {
        mosaic.ground(size, radius: radius, inset: inset, pitch: w * 0.036, material: .goldGround, grout: .groutGold)
        let easel = MosaicoEasel(w: w, h: size.height, pitch: w * 0.026, fine: w * 0.017)
        switch card.rank {
        case .king: mosaic.king(card.suit, easel)
        case .knight: mosaic.knight(card.suit, easel)
        default: mosaic.knave(card.suit, easel)
        }
    }
}
