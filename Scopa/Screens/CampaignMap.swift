import SwiftUI
import ScopaCore
import ScopaRewards

/// Where everything on the campaign map sits, for one width. Pure arithmetic, shared by the
/// grounds, the road and the medallions so the three always agree.
struct CampaignLayout {
    let width: CGFloat

    static let bannerHeight: CGFloat = 112
    static let rowHeight: CGFloat = 122
    static let footHeight: CGFloat = 40
    /// Across the map, left to right, for the six tables of every region. A road that
    /// swings, not a ladder.
    private static let swing: [CGFloat] = [0.5, 0.76, 0.5, 0.24, 0.42, 0.7]

    /// What to scroll to for a stage or a region.
    static func anchor(_ id: String) -> String { "anchor.\(id)" }

    static var regionHeight: CGFloat { bannerHeight + rowHeight * CGFloat(CampaignRegion.perRegion) }

    var height: CGFloat { Self.regionHeight * CGFloat(CampaignRegion.allCases.count) + Self.footHeight }

    func top(of region: CampaignRegion) -> CGFloat { Self.regionHeight * CGFloat(region.index) }

    func centre(of stage: CampaignStage) -> CGPoint {
        let offset = (stage.number - 1) % CampaignRegion.perRegion
        let x = Self.swing[offset] * width
        let y = top(of: stage.region) + Self.bannerHeight + Self.rowHeight * (CGFloat(offset) + 0.42)
        return CGPoint(x: x, y: y)
    }

    /// The road from the first table up to `stage`, or all of it.
    func road(through stage: CampaignStage? = nil) -> Path {
        let stages = Campaign.stages.prefix { stage == nil || $0.number <= stage!.number }
        var path = Path()
        guard let first = stages.first else { return path }
        path.move(to: CGPoint(x: centre(of: first).x, y: Self.bannerHeight * 0.7))
        path.addLine(to: centre(of: first))
        for (from, to) in zip(stages, stages.dropFirst()) { path.addPath(segment(from, to)) }
        return path
    }

    /// One stretch of road, leaving and arriving vertically so it reads as a winding way.
    func segment(_ from: CampaignStage, _ to: CampaignStage) -> Path {
        let a = centre(of: from), b = centre(of: to)
        let pull = (b.y - a.y) * 0.55
        var path = Path()
        path.move(to: a)
        path.addCurve(to: b, control1: CGPoint(x: a.x, y: a.y + pull), control2: CGPoint(x: b.x, y: b.y - pull))
        return path
    }
}

/// The map itself: the regions' plates, the road across them, and a medallion per table.
struct CampaignMap: View {
    let book: CampaignBook
    /// The column the road is laid in: a phone's width, centred on an iPad.
    let width: CGFloat
    /// The whole sheet across, which the grounds fill so the map is the sheet's surface.
    let span: CGFloat
    let selected: CampaignStage?
    /// What the walk-back moment is holding back: stars not yet struck, a road not yet drawn.
    let moment: CampaignMoment
    let you: SeatBadge
    /// Who else sits at each table, by stage number, off the ladder.
    var tables: [Int: Ladder.CampaignTable] = [:]
    let tap: (CampaignStage) -> Void

    private var layout: CampaignLayout { CampaignLayout(width: width) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            anchors
            road
            ForEach(CampaignRegion.allCases) { region in
                RegionBanner(region: region, stars: book.stars(in: region),
                             isOpen: book.isUnlocked(region.stages[0]) && moment.unlocking != region.stages[0])
                    .frame(width: width - 32)
                    .position(x: width / 2, y: layout.top(of: region) + CampaignLayout.bannerHeight / 2)
            }
            ForEach(Campaign.stages) { stage in medallion(stage) }
            ForEach(Campaign.stages) { stage in crowd(stage) }
        }
        .frame(width: width, height: layout.height, alignment: .topLeading)
        .frame(width: max(span, width))
        .background(alignment: .top) { grounds }
    }

    /// Laid-out rows for `ScrollViewReader` to find. A `ForEach` lends its ids to the
    /// reader too, and a positioned medallion's frame is the whole map, so scrolling to a
    /// stage's own id always landed in the middle.
    private var anchors: some View {
        VStack(spacing: 0) {
            ForEach(CampaignRegion.allCases) { region in
                Color.clear.frame(height: CampaignLayout.bannerHeight).id(CampaignLayout.anchor(region.id))
                ForEach(region.stages) { stage in
                    Color.clear.frame(height: CampaignLayout.rowHeight).id(CampaignLayout.anchor(stage.id))
                }
            }
        }
        .frame(width: width)
    }

    private var grounds: some View {
        ZStack(alignment: .top) {
            ForEach(CampaignRegion.allCases) { region in
                RegionGround(region: region)
                    .frame(height: CampaignLayout.regionHeight + (region == .roma ? CampaignLayout.footHeight : 0))
                    .offset(y: layout.top(of: region))
            }
        }
        .frame(width: max(span, width), height: layout.height, alignment: .top)
    }

    /// The whole way dotted faint, the part travelled laid in gold over it, and the stretch
    /// just opened drawn in by the walk-back moment.
    private var road: some View {
        let reached = travelled
        return ZStack(alignment: .topLeading) {
            layout.road()
                .stroke(Palette.cream.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 9]))
            if let reached {
                // Its shadow is a wider dark stroke laid a point lower, not a blur: a blurred
                // shadow on a path the map's whole height was recomposited every scroll frame.
                let travelled = layout.road(through: reached)
                travelled
                    .stroke(Palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .offset(y: 1)
                travelled
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            if let next = moment.unlocking, let from = Campaign.stage(number: next.number - 1) {
                layout.segment(from, next)
                    .trim(from: 0, to: moment.roadDrawn ? 1 : 0)
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
        .frame(width: width, height: layout.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// The last table the gold reaches: the current one, short of a stretch still being drawn.
    private var travelled: CampaignStage? {
        let current = book.current
        guard let unlocking = moment.unlocking, unlocking == current else { return current }
        return Campaign.stage(number: unlocking.number - 1)
    }

    private func medallion(_ stage: CampaignStage) -> some View {
        let locked = !book.isUnlocked(stage) || moment.unlocking == stage
        let isCurrent = stage == book.current && !book.isCleared(stage) && !locked
        return StageMedallion(stage: stage, stars: moment.stars(of: stage, in: book), isLocked: locked,
                              isCurrent: isCurrent, isSelected: stage == selected,
                              pops: moment.popped == stage, you: isCurrent ? you : nil)
            .onTapGesture { tap(stage) }
            .position(layout.centre(of: stage))
    }
}

extension CampaignMap {
    /// Other players at a table, beside its medallion on the side away from the map's edge.
    @ViewBuilder func crowd(_ stage: CampaignStage) -> some View {
        if let table = tables[stage.number], !table.faces.isEmpty {
            let centre = layout.centre(of: stage)
            let leftward = centre.x > width * 0.55
            let reach: CGFloat = (stage.isFinale ? 33 : 27) + 10
            StageCrowd(table: table)
                .fixedSize()
                .frame(width: 0, height: 0, alignment: leftward ? .trailing : .leading)
                .opacity(book.isUnlocked(stage) ? 1 : 0.75)
                .allowsHitTesting(false)
                .position(x: centre.x + (leftward ? -reach : reach), y: centre.y)
        }
    }
}

/// The walk back from a game, frame by frame. `CampaignView` moves it along; the map only
/// draws what it says.
struct CampaignMoment: Equatable {
    var outcome: CampaignBook.Outcome?
    /// Stars struck so far at the table just played.
    var struck = 0
    /// The table being unlocked, drawn still locked until its road arrives.
    var unlocking: CampaignStage?
    var roadDrawn = false
    /// The medallion that has just opened, for its one bounce.
    var popped: CampaignStage?

    func stars(of stage: CampaignStage, in book: CampaignBook) -> Int {
        guard let outcome, outcome.stage == stage else { return book.stars(of: stage) }
        return max(outcome.before, struck)
    }
}
