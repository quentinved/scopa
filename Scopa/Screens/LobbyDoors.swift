import SwiftUI
import ScopaCore

/// The glass a lobby door stands on. One place, so the four of them line up however
/// differently they are filled in.
private extension View {
    func doorPlate(lift: CGFloat, tint: Color?, league: Int?) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: tint, hairline: league == nil)
            .overlay {
                if let league {
                    LeagueRim(shape: RoundedRectangle(cornerRadius: GlassRadius.panel, style: .continuous),
                              league: league, weight: lift)
                }
            }
    }
}

/// What a door says: its mark and its name on one line, and one line on what is behind it.
///
/// The mark used to stand on a line of its own above the name, which made every door two
/// thumbs tall and the lobby a wall of them. Beside the name it costs no height at all.
struct DoorWords<Mark: View>: View {
    @Environment(\.lift) private var lift
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    /// Set where the line is a figure the ladder answered rather than a sentence.
    var detailIsGold = false
    @ViewBuilder var mark: Mark

    var body: some View {
        VStack(alignment: .leading, spacing: 5 * lift) {
            HStack(spacing: 9 * lift) {
                mark.frame(width: 30 * lift, height: 30 * lift)
                Text(title)
                    .font(.system(size: 16 * lift, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5 * lift, weight: .medium))
                    .foregroundStyle(detailIsGold ? Palette.goldLight.opacity(0.9) : Palette.onTableSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One way into a game, as half a row: a mark, a name, and a line under it.
///
/// The lobby sets four of these out in two rows that each answer a different question —
/// what the game is worth on the top row, who is at the table on the bottom one. They used
/// to be one wide tile over a row of three small ones, which put the quick game and the
/// league at different sizes without saying why.
struct ModeDoor<Mark: View>: View {
    @Environment(\.lift) private var lift
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    var detailIsGold = false
    var tint: Color? = nil
    /// The league whose edge this door wears. Nil for the doors with no grade behind them.
    var league: Int? = nil
    /// A third of a row rather than half: the mark over the name, centred, and no line.
    var compact = false
    /// A compact door's grade under its name, "Gold II", struck in the league's own metal.
    var grade: String? = nil
    @ViewBuilder var mark: Mark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if compact {
                VStack(spacing: 6 * lift) {
                    mark.frame(width: 30 * lift, height: 30 * lift)
                    Text(title)
                        .font(.system(size: 13.5 * lift, weight: .bold))
                        .foregroundStyle(Palette.onTable)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let grade, let league {
                        Text(verbatim: grade)
                            .textCase(.uppercase)
                            .font(.system(size: 10 * lift, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(LeagueMetal.league(league).light)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, -3 * lift)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 12 * lift)
                .padding(.horizontal, 6 * lift)
                .glassPanel(radius: GlassRadius.control, tint: tint, hairline: league == nil)
                .overlay {
                    if let league {
                        LeagueRim(shape: RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous),
                                  league: league, weight: lift)
                    }
                }
            } else {
                DoorWords(title: title, detail: detail, detailIsGold: detailIsGold) { mark }
                .doorPlate(lift: lift, tint: tint, league: league)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The game saved on this phone, as a row across the top of the doors.
struct ResumeDoor: View {
    let saved: SavedGame
    let resume: () -> Void
    let forget: () -> Void

    var body: some View {
        ComebackRow(title: "Resume", detail: Self.detail(saved), forgetLabel: "Forget this game",
                    action: resume, forget: forget) {
            HStack(spacing: -12) {
                CardBack(width: 20).rotationEffect(.degrees(-8))
                CardBack(width: 20).rotationEffect(.degrees(6))
            }
        }
    }

    /// "Hugo · 3 – 1 · Round 2": who, where it stands, how far in.
    static func detail(_ saved: SavedGame) -> LocalizedStringKey {
        let names = saved.opponentNames.formatted(.list(type: .and, width: .short))
        return "\(names) · \(saved.ownScore) – \(saved.bestOtherScore) · Round \(saved.state.roundNumber)"
    }
}

/// A room game the app was closed in the middle of, offered back the way a saved one is.
/// It floated over the foot of the lobby once, on top of the ladder and under the thumb;
/// as a row of the column it is measured with everything else and never covers a door.
struct RejoinDoor: View {
    let hostName: String
    let rejoin: () -> Void
    let forget: () -> Void

    var body: some View {
        ComebackRow(title: "Rejoin", detail: "At \(hostName)'s table", forgetLabel: "Forget that game",
                    action: rejoin, forget: forget) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.cream)
        }
    }
}

/// A game waiting to be picked back up, as a slim terracotta row: one tap back to the
/// table, with an × to let it go. A new deal over it was a dialog in the way of the resume;
/// dealing after the × is one tap more and never loses a table by mistake.
private struct ComebackRow<Mark: View>: View {
    @Environment(\.lift) private var lift
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let forgetLabel: LocalizedStringKey
    let action: () -> Void
    let forget: () -> Void
    /// Drawn at its size on a phone and lifted with the rest on an iPad.
    @ViewBuilder var mark: Mark

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12 * lift) {
                DoorWords(title: title, detail: detail) { mark.scaleEffect(lift) }
                // Clear of the ×.
                Spacer(minLength: 28 * lift)
            }
            .padding(.horizontal, 14 * lift)
            .padding(.vertical, 12 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: Palette.terracotta.opacity(0.92))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) { forgetButton.padding(.trailing, 12 * lift) }
    }

    private var forgetButton: some View {
        Button(action: forget) {
            Image(systemName: "xmark")
                .font(.system(size: 11 * lift, weight: .bold))
                .foregroundStyle(Palette.cream.opacity(0.9))
                .frame(width: 28 * lift, height: 28 * lift)
                .background { Circle().fill(Palette.ink.opacity(0.2)) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(forgetLabel)
    }
}

/// The table a quick game deals, as one chip: a tap turns it to the next size round. A chip
/// only changes the size and the deal is the words beside it, so a thumb reaching for a
/// four-hander never starts a two-hander by mistake. The pick is kept, so the table played
/// most is the one waiting.
struct QuickTableChip: View {
    @Environment(\.lift) private var lift
    @Binding var table: QuickTable

    var body: some View {
        Button {
            let all = QuickTable.allCases
            table = all[((all.firstIndex(of: table) ?? 0) + 1) % all.count]
            Audio.shared.play(.tap)
        } label: {
            HStack(spacing: 5 * lift) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10 * lift, weight: .semibold))
                Text(verbatim: table.pillLabel)
                    .font(.system(size: 12.5 * lift, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5 * lift, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10 * lift)
            .frame(height: 24 * lift)
            .background { Capsule().fill(Palette.goldSheen) }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(table.spokenLabel)
        .animation(.snappy(duration: 0.25), value: table)
    }
}

/// Everything that is not the league or the road, across the width like them: a quick game
/// against the bots, or a table with friends on this phone, by a code, or through Game Center.
struct FriendsDoor: View {
    @Environment(\.lift) private var lift
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12 * lift) {
                DoorWords(title: "Friends & bots", detail: "A quick game against the bots, or a table with friends.") {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22 * lift, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                }
                PlayPill()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14 * lift)
            .padding(.vertical, 12 * lift)
            .glassPanel(radius: GlassRadius.panel)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The solo campaign: a road through Italy, stage after stage, the bots getting sharper on
/// the way. Sea glaze rather than felt or metal, so it reads as a journey and not a grade.
///
/// Laid out as the ranked door is, a seal where the medal stands and the road where the
/// division bar runs, so the two ways to play alone stand at one size.
struct CampaignDoor: View {
    @Environment(\.lift) private var lift
    let book: CampaignBook
    let open: () -> Void

    private var started: Bool { book.totalStars > 0 }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14 * lift) {
                CampaignSeal(size: 54 * lift)
                    .frame(width: 58 * lift)
                VStack(alignment: .leading, spacing: 5 * lift) {
                    heading
                    VStack(alignment: .leading, spacing: 6 * lift) {
                        place
                        RoadMotif().frame(height: 14 * lift)
                        footer
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14 * lift)
            .padding(.vertical, 14 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: Palette.seaGlaze.opacity(0.55))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var heading: some View {
        HStack(spacing: 8 * lift) {
            Text("Campaign")
                .font(.system(size: 19 * lift, weight: .bold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
            Spacer(minLength: 4 * lift)
            PlayPill()
        }
    }

    /// Where the road has reached, once a stage is won; until then the door sells the trip.
    private var place: some View {
        let stage = book.current
        let line: LocalizedStringKey = started ? "Stage \(stage.number) · \(stage.region.title)"
                                               : "A journey through Italy"
        return Text(line)
            .textCase(.uppercase)
            .font(.system(size: 12.5 * lift, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Palette.onTable)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// The stars won so far, or where the first table is before there are any.
    private var footer: some View {
        let first = Campaign.stages[0]
        let line: LocalizedStringKey = started ? "\(book.totalStars) of \(CampaignBook.maxStars) stars"
                                               : "Stage \(first.number) · \(first.region.title)"
        return Text(line)
            .font(.system(size: 11.5 * lift, weight: .semibold))
            .foregroundStyle(Palette.goldLight.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// The campaign's answer to the league medal: the map struck on a sea-glaze coin with a
/// gold rim. Metal on the edge only, since the road is a journey and not a grade.
private struct CampaignSeal: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Palette.seaGlaze)
            .overlay { Circle().fill(Palette.ink.opacity(0.18)).padding(size * 0.12) }
            .overlay { Circle().strokeBorder(Palette.goldSheen, lineWidth: size * 0.06) }
            .overlay {
                Image(systemName: "map.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            }
            .frame(width: size, height: size)
            .shadow(color: Palette.ink.opacity(0.3), radius: size * 0.06, y: size * 0.04)
    }
}

/// A road drawn across the door: a dotted line winding between stops, the first ones
/// passed in gold, the next one ringed, and a pennant at the far end. Still, by design.
private struct RoadMotif: View {
    @Environment(\.lift) private var lift

    /// Where the stops sit, as fractions of the frame, left to right.
    private static let stops: [CGPoint] = [.init(x: 0.06, y: 0.78), .init(x: 0.34, y: 0.38),
                                           .init(x: 0.62, y: 0.70), .init(x: 0.9, y: 0.28)]

    var body: some View {
        GeometryReader { proxy in
            let points = Self.stops.map { CGPoint(x: $0.x * proxy.size.width, y: $0.y * proxy.size.height) }
            ZStack {
                road(through: points)
                    .stroke(Palette.cream.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2 * lift, lineCap: .round, dash: [0.1, 5 * lift]))
                ForEach(points.indices.dropLast(), id: \.self) { index in
                    stop(passed: index < 2).position(points[index])
                }
                Image(systemName: "flag.fill")
                    .font(.system(size: 13 * lift, weight: .bold))
                    .foregroundStyle(Palette.terracotta)
                    .position(x: points[3].x + 3 * lift, y: points[3].y - 6 * lift)
            }
        }
    }

    /// A gentle curve through every stop: each leg bends through the midpoint's level.
    private func road(through points: [CGPoint]) -> Path {
        Path { path in
            path.move(to: points[0])
            for (from, to) in zip(points, points.dropFirst()) {
                let mid = (from.x + to.x) / 2
                path.addCurve(to: to, control1: CGPoint(x: mid, y: from.y), control2: CGPoint(x: mid, y: to.y))
            }
        }
    }

    private func stop(passed: Bool) -> some View {
        Circle()
            .fill(passed ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink.opacity(0.35)))
            .overlay { Circle().strokeBorder(passed ? Palette.goldDeep : Palette.goldLight, lineWidth: 1.5 * lift) }
            .frame(width: 10 * lift, height: 10 * lift)
    }
}

/// "Play" on a gold pill, at the end of each of the three ways to play. A chevron there read
/// as "more about this", so the league looked like a stats card rather than a game to sit at.
/// The door around it is the button; this only says what it does.
struct PlayPill: View {
    @Environment(\.lift) private var lift

    var body: some View {
        HStack(spacing: 5 * lift) {
            Image(systemName: "play.fill")
                .font(.system(size: 10 * lift, weight: .bold))
            Text("Play")
                .textCase(.uppercase)
                .font(.system(size: 12 * lift, weight: .heavy))
                .tracking(0.8)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 11 * lift)
        .frame(height: 28 * lift)
        .background { Capsule().fill(Palette.goldSheen) }
        .accessibilityHidden(true)
    }
}

/// Ranked, as the lobby's first door: the medal, the grade, how often you win and what the
/// next division costs.
///
/// It was a small square in a row of three, under a plate beneath the wordmark that said the
/// grade a second time. The league is what keeps a player coming back past the first week,
/// so it has the width now, and the plate has folded into it.
struct RankedHero: View {
    @Environment(\.lift) private var lift
    @Environment(\.locale) private var locale
    let rank: Ladder.RankAnswer?
    let open: () -> Void

    private var played: Bool { (rank?.games ?? 0) > 0 }
    /// Nil until a ranked game has actually been played: an unranked door must not wear
    /// bronze, which is a grade somebody earned.
    private var league: Int? { played ? rank?.standing.league : nil }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14 * lift) {
                LeagueMedal(league: league ?? 0, size: 54 * lift)
                    .opacity(played ? 1 : 0.5)
                    .grayscale(played ? 0 : 0.8)
                    .frame(width: 58 * lift)
                VStack(alignment: .leading, spacing: 5 * lift) {
                    heading
                    if let rank, played { standing(rank) } else { unranked }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14 * lift)
            .padding(.vertical, 14 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: league.map { LeagueMetal.league($0).base.opacity(0.16) },
                        hairline: league == nil)
            .overlay {
                if let league {
                    LeagueRim(shape: RoundedRectangle(cornerRadius: GlassRadius.panel, style: .continuous),
                              league: league, weight: lift)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Ranked"))
        .accessibilityValue(Text(verbatim: played
                                 ? rank?.standing.leagueTitle(locale: locale) ?? ""
                                 : String(localized: "Unranked", locale: locale)))
        .animation(.easeInOut(duration: 0.3), value: league)
    }

    private var heading: some View {
        HStack(spacing: 8 * lift) {
            Text("Ranked")
                .font(.system(size: 19 * lift, weight: .bold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
            Spacer(minLength: 4 * lift)
            PlayPill()
        }
    }

    /// The grade in the house voice with the win rate across from it, then the division's
    /// bar and what the next one costs.
    private func standing(_ rank: Ladder.RankAnswer) -> some View {
        VStack(alignment: .leading, spacing: 6 * lift) {
            HStack(alignment: .firstTextBaseline, spacing: 8 * lift) {
                grade(rank.standing.leagueTitle(locale: locale))
                Spacer(minLength: 0)
                if let rate = Ladder.winRate(wins: rank.wins, games: rank.games, locale: locale) {
                    Text("\(rate) win rate")
                        .font(.system(size: 11.5 * lift, weight: .semibold))
                        .foregroundStyle(Palette.onTableSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            DivisionRoad(rating: rank.rating, metal: LeagueMetal.league(rank.standing.league))
            HStack(spacing: 8 * lift) {
                Text(verbatim: Ranking.climb(from: rank.rating, locale: locale))
                    .font(.system(size: 11.5 * lift, weight: .semibold))
                    .foregroundStyle(Palette.goldLight.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                NextStop(rating: rank.rating)
            }
        }
    }

    private var unranked: some View {
        VStack(alignment: .leading, spacing: 4 * lift) {
            grade(String(localized: "Unranked", locale: locale))
            Text("One ranked game and the ladder has you")
                .font(.system(size: 11.5 * lift, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "PLATINUM III", tracked, in the table's own ink: the metal is on the medal, not the type.
    private func grade(_ title: String) -> some View {
        Text(verbatim: title)
            .textCase(.uppercase)
            .font(.system(size: 12.5 * lift, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Palette.onTable)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// How far through the division you are, in the league's metal. Fixed width, so the chip
/// does not breathe as the rating moves.
struct LeagueBar: View {
    @Environment(\.lift) private var lift
    let metal: LeagueMetal
    let progress: Double
    var width: CGFloat = 46

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(felt.shade(0.45))
            Capsule().fill(metal.sheen)
                .frame(width: max(width * lift * min(max(progress, 0), 1), progress > 0 ? 5 : 0))
        }
        .frame(width: width * lift, height: 5 * lift)
        .overlay { Capsule().strokeBorder(metal.dark.opacity(0.5), lineWidth: 0.5) }
        .animation(.snappy, value: progress)
    }
}

#Preview("The doors") {
    @Previewable @State var table = QuickTable.two
    VStack(spacing: 10) {
        RankedHero(rank: nil) {}
        CampaignDoor(book: CampaignBook()) {}
        FriendsDoor {}
        QuickTableChip(table: $table)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
