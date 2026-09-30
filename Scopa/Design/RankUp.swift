import SwiftUI
import ScopaCore
import ScopaRewards

/// Which league is owed its ceremony, and whether the ceremony is on screen.
///
/// A league is celebrated once, ever: leagues are never lost, so the highest one shown is
/// all there is to remember. The ranked summary asks as soon as its bar has run, and the
/// lobby asks whenever it comes back, which catches a result the ladder settled late.
@Observable
final class LadderCeremony {
    struct Showing: Equatable {
        let league: League
        /// What the medal turns over from. Nil for Bronze, which arrives on its own.
        let from: League?
        /// Leagues below it reached without a ceremony of their own.
        let skipped: Int
    }

    private(set) var showing: Showing?

    /// Shows the ceremony for a league reached and not yet celebrated, if there is one.
    func check() {
        guard showing == nil, !Self.isQuiet, let owed = LadderPrizes.owed else { return }
        present(owed)
    }

    /// Checks once whatever is arriving on screen has settled.
    func checkSoon() {
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            check()
        }
    }

    func present(_ league: League) {
        let before = LadderPrizes.celebrated
        LadderPrizes.markCelebrated(league)
        let skipped = league.rawValue - (before.map { $0.rawValue + 1 } ?? 0)
        let from = league == .bronze ? nil : League(rawValue: league.rawValue - 1)
        withAnimation(.easeOut(duration: 0.3)) {
            showing = Showing(league: league, from: from, skipped: max(skipped, 0))
        }
    }

    func close() {
        withAnimation(.easeIn(duration: 0.25)) { showing = nil }
    }

    /// Screenshots are taken with `-noGameCenter`, often with `-rank` planting a league, and
    /// must not be covered by a ceremony nobody asked for. `-rankUp` asks for one.
    private static var isQuiet: Bool {
        #if DEBUG
        DebugLaunch.staysSignedOut && !DebugLaunch.forcesRankUp
        #else
        false
        #endif
    }
}

extension View {
    /// Hangs the new-league ceremony over everything. Applied once, at the root.
    func ladderCeremony(store: TableStore) -> some View {
        modifier(LadderCeremonyHost(store: store))
    }
}

private struct LadderCeremonyHost: ViewModifier {
    @Bindable var store: TableStore
    @State private var ceremony = LadderCeremony()
    @State private var showsRoad = false

    func body(content: Content) -> some View {
        content
            .environment(ceremony)
            .overlay {
                if let showing = ceremony.showing {
                    RankUpCeremony(showing: showing, name: store.playerName, livery: store.livery,
                                   mark: $store.seatMark,
                                   road: { ceremony.close(); showsRoad = true },
                                   close: { ceremony.close() })
                        .transition(.opacity)
                }
            }
            .sheet(isPresented: $showsRoad) { LadderRoadSheet(store: store) }
            .task { await arrive() }
            .onChange(of: store.rank) { if store.route == .lobby { ceremony.check() } }
            .onChange(of: store.route) { _, route in if route == .lobby { ceremony.checkSoon() } }
    }

    /// Picks up a league cached by a build older than the prizes, then checks.
    private func arrive() async {
        LadderPrizes.remember(store.rank)
        #if DEBUG
        if DebugLaunch.forcesRankUp {
            // After `-rank` has planted its league.
            try? await Task.sleep(for: .seconds(1))
            if let league = store.rank.flatMap({ League(rawValue: $0.standing.league) }) { ceremony.present(league) }
            return
        }
        #endif
        if store.route == .lobby { ceremony.checkSoon() }
    }
}

/// A new league, reached in ranked: the old medal turns over and comes back struck in the
/// new metal, the light and the sparks go off behind it, and what the league gives is laid
/// out underneath, ready to wear.
///
/// The spectacle is all in the medal. The words stay in the house voice.
struct RankUpCeremony: View {
    let showing: LadderCeremony.Showing
    let name: String
    let livery: SeatLivery
    @Binding var mark: SeatMark
    let road: () -> Void
    let close: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.tableFelt) private var felt
    @Environment(\.screenSize) private var screenSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The league the medal is drawn in: the old one until it turns over.
    @State private var shown: League
    @State private var turn: Double = 0
    @State private var beat = Beat.dark
    @State private var flash: Double = 0
    @State private var burst = 0
    @State private var raysTurn: Double = 0
    @State private var icon = LadderIcon.current

    private enum Beat: Int, Comparable {
        case dark, medal, struck, named, prizes, done
        static func < (a: Beat, b: Beat) -> Bool { a.rawValue < b.rawValue }
    }

    init(showing: LadderCeremony.Showing, name: String, livery: SeatLivery, mark: Binding<SeatMark>,
         road: @escaping () -> Void, close: @escaping () -> Void) {
        self.showing = showing
        self.name = name
        self.livery = livery
        _mark = mark
        self.road = road
        self.close = close
        _shown = State(initialValue: showing.from ?? showing.league)
    }

    private var league: League { showing.league }
    private var metal: LeagueMetal { .league(league.rawValue) }
    private var isWide: Bool { screenSize.width > screenSize.height && screenSize.height < 500 }

    var body: some View {
        ZStack {
            backdrop
            GeometryReader { geometry in
                ScrollView {
                    layout
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .task { await tell() }
        .sensoryFeedback(.success, trigger: burst)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var layout: some View {
        if isWide {
            // Held sideways there is no room under the prizes, so Continue goes under the medal.
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    stage
                    continueButton
                }
                .frame(width: 260)
                VStack(spacing: 0) {
                    words
                    prizes
                    roadButton
                }
                .frame(maxWidth: 420)
            }
        } else {
            VStack(spacing: 0) {
                stage
                words
                prizes
                buttons
            }
            .frame(maxWidth: 400)
        }
    }

    // MARK: The ground

    /// The table dimmed, with the new metal's light pooling behind the medal once it lands.
    private var backdrop: some View {
        ZStack {
            felt.deep.opacity(0.97)
            RadialGradient(colors: [metal.base.opacity(beat >= .struck ? 0.4 : 0.1), .clear],
                           center: UnitPoint(x: 0.5, y: isWide ? 0.5 : 0.28), startRadius: 10, endRadius: 440)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    // MARK: The medal

    private var stage: some View {
        ZStack {
            if beat >= .struck { rays.transition(.opacity) }
            Circle()
                .fill(.white)
                .frame(width: 170, height: 170)
                .blur(radius: 30)
                .opacity(flash)
            LeagueMedal(league: shown.rawValue, size: 132)
                .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                .scaleEffect(beat >= .medal ? 1 : 0.4)
                .opacity(beat >= .medal ? 1 : 0)
            if burst > 0 {
                MetalSparks(metal: metal, count: 44, reach: 0.48)
                    .id(burst)
                    .frame(width: 360, height: 360)
            }
        }
        .frame(width: 230, height: 230)
        .accessibilityHidden(true)
    }

    /// Light behind the medal, turning a few degrees and then still.
    private var rays: some View {
        LightRays(count: 18)
            .fill(RadialGradient(colors: [metal.light.opacity(0.6), metal.light.opacity(0.14), .clear],
                                 center: .center, startRadius: 58, endRadius: 175))
            .frame(width: 350, height: 350)
            .rotationEffect(.degrees(raysTurn))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    // MARK: The words

    private var words: some View {
        VStack(spacing: 6) {
            Text(showing.from == nil ? "ON THE LADDER" : "NEW LEAGUE")
                .font(.system(size: 12.5, weight: .heavy))
                .tracking(2)
                .foregroundStyle(metal.light)
            Text(verbatim: league.title(locale: locale))
                .font(.display(isWide ? 46 : 58))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(showing.from == nil ? "One ranked game, and the ladder has you." : "Yours for good. Seasons end, leagues stay.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(beat >= .named ? 1 : 0)
        .offset(y: beat >= .named ? 0 : 14)
        .padding(.bottom, isWide ? 12 : 22)
        .accessibilityElement(children: .combine)
    }

    // MARK: The prizes

    private var prizes: some View {
        VStack(spacing: 12) {
            Caption(text: "Only in ranked")
            HStack(alignment: .top, spacing: 12) {
                medalTile
                if let icon = league.icon { iconTile(icon) } else { teaserTile }
            }
            .fixedSize(horizontal: false, vertical: true)
            if showing.skipped > 0 {
                Text("Every league below it gives its prizes too, and they are yours.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            seasonPay
        }
        .opacity(beat >= .prizes ? 1 : 0)
        .offset(y: beat >= .prizes ? 0 : 18)
        .padding(.bottom, isWide ? 4 : 22)
    }

    private var medalTile: some View {
        let medal = league.medal
        return PrizeTile(title: medal.title, detail: "On your seat, at every table", metal: metal,
                         action: mark == medal ? nil : "Wear it", done: mark == medal ? "Worn" : nil) {
            mark = medal
            Audio.shared.play(.toggle)
        } art: {
            SeatBadge(name: name, tint: Palette.seat(0), size: 58, mark: medal, livery: livery)
        }
    }

    private func iconTile(_ prize: LadderIcon) -> some View {
        PrizeTile(title: prize.title, detail: "On your home screen", metal: metal,
                  action: icon == prize || !LadderIcon.isSupported ? nil : "Use it",
                  done: icon == prize ? "In use" : nil) {
            Task {
                await LadderIcon.use(prize)
                icon = LadderIcon.current
            }
        } art: {
            LadderIconArt(icon: prize, size: 58)
        }
    }

    /// Bronze gives no icon. What it shows instead is the first one, and where it is won.
    private var teaserTile: some View {
        PrizeTile(title: LadderIcon.silver.title, detail: "Reach Silver", metal: metal, action: nil, done: nil) {
        } art: {
            LadderIconArt(icon: .silver, size: 58)
                .saturation(0.2)
                .opacity(0.55)
                .overlay(alignment: .bottomTrailing) { LockGlyph() }
        }
    }

    private var seasonPay: some View {
        HStack(spacing: 8) {
            DenariMark(size: 18)
            Text("+\(SeasonReward.denari(forLeague: league).coins) for every season you finish here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The way out

    private var buttons: some View {
        VStack(spacing: 6) {
            continueButton
            roadButton
        }
    }

    private var continueButton: some View {
        Button("Continue", action: close)
            .buttonStyle(FilledButtonStyle())
            .opacity(beat >= .done ? 1 : 0)
            .allowsHitTesting(beat >= .done)
    }

    private var roadButton: some View {
        Button(action: road) {
            Text("See the road to Maestro")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .opacity(beat >= .done ? 1 : 0)
        .allowsHitTesting(beat >= .done)
    }

    // MARK: The telling

    /// The medal arrives, turns over, and is struck; then the name, then the prizes.
    private func tell() async {
        guard !reduceMotion else {
            shown = league
            beat = .done
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(duration: 0.55, bounce: 0.35)) { beat = .medal }
        Audio.shared.play(.step)
        try? await Task.sleep(for: .milliseconds(750))
        if showing.from != nil { await turnOver() }
        strike()
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) { beat = .named }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { beat = .prizes }
        Audio.shared.play(.reveal)
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeOut(duration: 0.35)) { beat = .done }
    }

    /// Edge on, the old metal is swapped for the new one, which turns on round to face out.
    private func turnOver() async {
        withAnimation(.easeIn(duration: 0.22)) { turn = 90 }
        try? await Task.sleep(for: .milliseconds(220))
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            shown = league
            turn = -90
        }
        withAnimation(.spring(duration: 0.7, bounce: 0.42)) { turn = 0 }
    }

    private func strike() {
        flash = 0.85
        withAnimation(.easeOut(duration: 0.7)) { flash = 0 }
        burst += 1
        withAnimation(.easeOut(duration: 0.45)) { beat = .struck }
        withAnimation(.easeOut(duration: 9)) { raysTurn = 40 }
        Audio.shared.play(.purchase)
    }
}

/// One prize: the thing itself, its name, where it shows, and the button that puts it there.
private struct PrizeTile<Art: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let metal: LeagueMetal
    /// The button's word. Nil hides it.
    let action: LocalizedStringKey?
    /// Said in place of the button once it is done.
    let done: LocalizedStringKey?
    let perform: () -> Void
    @ViewBuilder var art: Art

    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 8) {
            art.frame(height: 66)
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(felt.shade(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(metal.base.opacity(0.5), lineWidth: 1)
                }
        }
    }

    @ViewBuilder private var footer: some View {
        if let action {
            Button(action: perform) {
                Text(action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(Palette.terracotta) }
            }
            .buttonStyle(.plain)
        } else if let done {
            Label { Text(done) } icon: { Image(systemName: "checkmark") }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(metal.light)
                .padding(.vertical, 7)
        }
    }
}

/// The padlock on a prize not won yet.
struct LockGlyph: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Palette.cream)
            .padding(5)
            .background(Palette.ink.opacity(0.75), in: Circle())
    }
}

/// Wedges of light radiating from the centre.
private struct LightRays: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.16
        let outer = min(rect.width, rect.height) * 0.5
        let half = .pi / Double(count) * 0.36
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            path.move(to: CGPoint(x: centre.x + cos(angle - half) * inner, y: centre.y + sin(angle - half) * inner))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
            path.addLine(to: CGPoint(x: centre.x + cos(angle + half) * inner, y: centre.y + sin(angle + half) * inner))
            path.closeSubpath()
        }
        return path
    }
}

#Preview("Gold, reached") {
    @Previewable @State var mark = SeatMark.initial
    RankUpCeremony(showing: .init(league: .gold, from: .silver, skipped: 0), name: "Quentin", livery: .tavolo,
                   mark: $mark, road: {}, close: {})
}

#Preview("The first ranked game") {
    @Previewable @State var mark = SeatMark.initial
    RankUpCeremony(showing: .init(league: .bronze, from: nil, skipped: 0), name: "Quentin", livery: .tavolo,
                   mark: $mark, road: {}, close: {})
}
