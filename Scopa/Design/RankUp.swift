import SwiftUI
import ScopaCore
import ScopaRewards

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
            Text(promise)
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

    /// What the league means, under its name. Gran Maestro's is a different kind of place,
    /// so it says how: points with no top, and a title for the few at the head of them.
    private var promise: LocalizedStringKey {
        if showing.from == nil { return "One ranked game, and the ladder has you." }
        if league == .granMaestro {
            return "No more divisions: points from here on, with no top. The season's ten best are its Campioni."
        }
        return "Yours for good. Seasons end, leagues stay."
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
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(SeasonReward.denari(forLeague: league).coins) for every season you finish here")
                if league == .granMaestro {
                    Text("+\(SeasonReward.campioneBonus.coins) more for a season finished as a Campione")
                }
            }
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
            Text(league == .granMaestro ? "See the road" : "See the road to Maestro")
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

#Preview("Gold, reached") {
    @Previewable @State var mark = SeatMark.initial
    RankUpCeremony(showing: .init(league: .gold, from: .silver, skipped: 0), name: "Quentin", livery: .tavolo,
                   mark: $mark, road: {}, close: {})
}

#Preview("Gran Maestro, reached") {
    @Previewable @State var mark = SeatMark.initial
    RankUpCeremony(showing: .init(league: .granMaestro, from: .maestro, skipped: 0), name: "Quentin",
                   livery: .tavolo, mark: $mark, road: {}, close: {})
}

#Preview("The first ranked game") {
    @Previewable @State var mark = SeatMark.initial
    RankUpCeremony(showing: .init(league: .bronze, from: nil, skipped: 0), name: "Quentin", livery: .tavolo,
                   mark: $mark, road: {}, close: {})
}
