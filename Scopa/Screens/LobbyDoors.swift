import SwiftUI
import ScopaCore

/// The glass a lobby door stands on. One place, so the four of them line up however
/// differently they are filled in.
private extension View {
    func doorPlate(lift: CGFloat, tint: Color?, league: Int?) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: tint, interactive: true, hairline: league == nil)
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 12 * lift)
                .padding(.horizontal, 6 * lift)
                .glassPanel(radius: GlassRadius.control, tint: tint, interactive: true, hairline: league == nil)
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

/// The quick game, which asks its one question on the tile rather than on a sheet.
///
/// It is the door called quick, and it used to open a sheet with a segmented picker, a
/// toggle, a note and a button on it before a single card was dealt. The four tables it can
/// deal — two, three, four, and four as two sides — are four pills, and the tile above them
/// deals whichever is lit. The pick is kept, so the table played most is the one waiting.
///
/// No line under the name: the tin head says it is the machine and the lit pill says how
/// many of them, so a sentence saying both is the third time.
struct QuickDoor: View {
    @Environment(\.lift) private var lift
    @Binding var table: QuickTable
    let deal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * lift) {
            Button(action: deal) {
                DoorWords(title: "Quick game") { BotFace(tint: Palette.goldLight, size: 30 * lift) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Deals against the bots"))
            sizes
        }
        .doorPlate(lift: lift, tint: Palette.terracotta.opacity(0.78), league: nil)
        .animation(.snappy(duration: 0.25), value: table)
    }

    /// One pill per table. A pill only changes the size: the deal is the tile above it, so
    /// a thumb reaching for a four-hander never starts a two-hander by mistake.
    private var sizes: some View {
        HStack(spacing: 5 * lift) {
            ForEach(QuickTable.allCases) { option in
                Button {
                    table = option
                    Audio.shared.play(.tap)
                } label: {
                    pill(option)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.spokenLabel)
                .accessibilityAddTraits(option == table ? [.isSelected] : [])
            }
        }
    }

    private func pill(_ option: QuickTable) -> some View {
        let picked = option == table
        return Text(verbatim: option.pillLabel)
            .font(.system(size: 12 * lift, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(picked ? Palette.ink : Palette.cream.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 26 * lift)
            .background {
                Capsule().fill(picked ? AnyShapeStyle(Palette.goldSheen) : AnyShapeStyle(Palette.ink.opacity(0.22)))
            }
            .overlay {
                Capsule().strokeBorder(Palette.cream.opacity(picked ? 0 : 0.18), lineWidth: 1)
            }
            .contentShape(.capsule)
    }
}

/// Where you stand, on a plate wearing its own league's edge.
///
/// The head count that used to sit beside it is gone. It was the loudest thing on the
/// masthead and almost all of it was invented; the grade is what the plate is for, and the
/// border now says which grade it is before the lettering is read.
struct RankPlate: View {
    @Environment(\.lift) private var lift
    @Environment(\.locale) private var locale
    let rank: Ladder.RankAnswer?
    let open: () -> Void

    private var played: Bool { (rank?.games ?? 0) > 0 }
    /// The league to dress the plate in. Nil until a ranked game has actually been played:
    /// an unranked plate must not wear bronze, which is a grade somebody earned.
    private var league: Int? { played ? rank?.standing.league : nil }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 11 * lift) {
                LeagueMedal(league: league ?? 0, size: 28 * lift)
                    .opacity(played ? 1 : 0.5)
                    .grayscale(played ? 0 : 0.8)
                words
            }
            .padding(.leading, 10 * lift)
            .padding(.trailing, 16 * lift)
            .padding(.vertical, 8 * lift)
            .glass(.riviera(interactive: true), in: .capsule)
            .overlay {
                if let league {
                    LeagueRim(shape: Capsule(), league: league, weight: lift)
                } else {
                    Capsule().strokeBorder(Palette.onTableSoft.opacity(0.4), lineWidth: 1 * lift)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Ranked"))
        .accessibilityValue(Text(verbatim: played
                                 ? rank?.standing.leagueTitle(locale: locale) ?? ""
                                 : String(localized: "Unranked", locale: locale)))
        .animation(.easeInOut(duration: 0.3), value: league)
    }

    @ViewBuilder private var words: some View {
        if let rank, played {
            VStack(alignment: .leading, spacing: 5 * lift) {
                Text(verbatim: rank.standing.leagueTitle(locale: locale))
                    .textCase(.uppercase)
                    .font(.system(size: 13 * lift, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Palette.onTable)
                    // "PLATINUM III" must not wrap.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                LeagueBar(metal: LeagueMetal.league(rank.standing.league),
                          progress: Double(rank.standing.progress) / 100, width: 92)
            }
            .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: 2 * lift) {
                Text("Unranked")
                    .textCase(.uppercase)
                    .font(.system(size: 13 * lift, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Palette.onTable)
                Text("One ranked game and the ladder has you")
                    .font(.system(size: 10.5 * lift, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
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

/// One way into a game, laid on its side across a whole row. The resumed game is the last
/// tile that still wants the width: it carries a scoreline and a way to throw it away.
struct DoorTile<Icon: View>: View {
    @Environment(\.lift) private var lift
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var tint: Color?
    var wide = false
    /// Off for a tile that carries its own trailing button.
    var showsChevron = true
    @ViewBuilder var icon: Icon
    let action: () -> Void

    private var isTinted: Bool { tint != nil }

    var body: some View {
        Button(action: action) {
            Group {
                if wide { row } else { cell }
            }
            .padding(12 * lift)
            .glassPanel(radius: GlassRadius.panel, tint: tint?.opacity(0.78), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var row: some View {
        HStack(spacing: 14 * lift) {
            icon.frame(width: 32 * lift, height: 32 * lift)
            words
            // Without the chevron the words still stop short of the trailing button.
            Spacer(minLength: showsChevron ? 0 : 34)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14 * lift, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cell: some View {
        VStack(alignment: .leading, spacing: 0 * lift) {
            icon.frame(width: 32 * lift, height: 32 * lift)
            Spacer(minLength: 10 * lift)
            words
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2 * lift) {
            Text(title)
                .font(.system(size: 17 * lift, weight: .bold))
                .foregroundStyle(isTinted ? Palette.cream : Palette.onTable)
            Text(detail)
                .font(.system(size: 12 * lift, weight: .medium))
                .foregroundStyle(isTinted ? Palette.cream.opacity(0.85) : Palette.onTableSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Three cards of the deck in use, fanned behind the broom.
struct MastheadFan: View {
    @Environment(\.lift) private var lift
    let width: CGFloat

    private static let cards = [Card(.ace, of: .clubs), Card.settebello, Card(.knight, of: .cups)]

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        ZStack {
            ForEach(Array(Self.cards.enumerated()), id: \.element) { index, card in
                let position = Double(index) - 1
                CardView(card: card, width: width)
                    .rotationEffect(.degrees(position * 18), anchor: .bottom)
                    .offset(x: position * width * 0.34)
            }
        }
        .shadow(color: felt.shade(0.5), radius: 10, y: 6)
    }
}

#Preview("The doors") {
    @Previewable @State var table = QuickTable.two
    VStack(spacing: 10) {
        RankPlate(rank: nil) {}
        HStack(spacing: 10) {
            ModeDoor(title: "Ranked", detail: "45 to Gold III", detailIsGold: true, league: 2) {
                LeagueMedal(league: 2, size: 28)
            } action: {}
            ModeDoor(title: "For denari", detail: "Coins on the table") {
                DenariMark(size: 26)
            } action: {}
        }
        .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 10) {
            QuickDoor(table: $table) {}
            ModeDoor(title: "With friends", detail: "This phone, a code, or Game Center") {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            } action: {}
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
