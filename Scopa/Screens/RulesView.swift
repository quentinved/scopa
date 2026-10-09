import SwiftUI
import ScopaCore

/// How to play, in short chapters drawn with real cards in the chosen deck. Opens once on
/// first launch, then only from the ? buttons and the settings row.
struct RulesView: View {
    /// Set by the lobby to deal a coached hand from the last page. Nil elsewhere, where
    /// the last button only closes.
    var onFinish: (() -> Void)?
    /// The house rules of the table the book was opened from. They come first, since they
    /// are what a player at that table is most likely to be asking about.
    var house: Set<HouseRule> = []

    @Environment(\.dismiss) private var dismiss
    @State private var chapter: Chapter?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pages
                footer
            }
            .background { TableGround() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Palette.goldLight)
                }
            }
        }
        .onAppear { chapter = chapter ?? chapters.first }
        .sensoryFeedback(.selection, trigger: chapter)
        .sound(.tap, trigger: chapter)
    }

    // MARK: The chapters

    private var pages: some View {
        TabView(selection: $chapter) {
            ForEach(chapters) { chapter in
                ScrollView {
                    page(chapter)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .tag(Optional(chapter))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // A large type size or a short phone can push a page past the fold. The fade
        // says there is more where a hard edge would look like a bug.
        .mask(
            LinearGradient(stops: [.init(color: .black, location: 0),
                                   .init(color: .black, location: 0.94),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder private func page(_ chapter: Chapter) -> some View {
        switch chapter {
        case .house: thisTable
        case .goal: goal
        case .deck: deck
        case .take: take
        case .scopa: scopa
        case .deal: deal
        case .points: points
        case .ready: ready
        }
    }

    /// The whole game on one page first, then each part of it in the order it happens at the
    /// table: the cards, the deal, a turn, the sweep, the count. The closing offer is only a
    /// page when there is a table to deal.
    private var chapters: [Chapter] {
        let classic: [Chapter] = [.goal, .deck, .deal, .take, .scopa, .points] + (onFinish == nil ? [] : [.ready])
        return house.isEmpty ? classic : [.house] + classic
    }

    private var thisTable: some View {
        VStack(alignment: .leading, spacing: 34) {
            Caption(text: "This table's house rules")
            ForEach(HouseRule.allCases.filter(house.contains), id: \.self) { rule in
                HouseRulePage(rule: rule)
            }
            Paragraph("Everything else is classic Scopa, on the pages that follow.")
        }
    }

    /// The whole game before any of its parts, so each page after it answers a question
    /// the player already has.
    private var goal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("How to win",
                    detail: "Take cards from the table. The cards you take are worth points. First to 11 points wins.")
            VStack(spacing: 10) {
                Step(number: 1, text: "Play one card from your hand.")
                Step(number: 2, text: "If it matches cards on the table, you take them.")
                Step(number: 3, text: "Take every card on the table and it is a scopa: one point at once.")
                Step(number: 4, text: "When the cards run out, count what you took.")
            }
            Paragraph("The next pages show each step with real cards.")
        }
    }

    private var deck: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Forty cards",
                    detail: "Four Italian suits, numbered 1 to 10.")
            Fan()
            Paragraph("A card is worth the number in its corner. The three picture cards are 8, 9 and 10.")
            Suits()
        }
    }

    private var deal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Three cards each",
                    detail: "Four cards face up on the table, three in each hand.")
            Deal()
            Paragraph("When every hand is empty, everyone gets three more. This goes on until the deck runs out.")
        }
    }

    private var take: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Taking cards",
                    detail: "On your turn, play one card. It takes the cards it matches.")
            Take(played: Card(.four, of: .cups), taking: [Card(.four, of: .swords)],
                 note: "Same number: your 4 takes the 4.")
            Take(played: .settebello, taking: [Card(.three, of: .clubs), Card(.four, of: .coins)],
                 note: "Or several cards that add up to it: 3 + 4 = 7.")
            Take(played: Card(.two, of: .swords), taking: [],
                 note: "Nothing matches: your card stays on the table.")
            VStack(spacing: 10) {
                Tip(text: "If your card can take, it must take.")
                Tip(text: "A matching card comes before a sum: with a 7, a 3 and a 4 on the table, your 7 takes the 7.")
            }
        }
    }

    private var scopa: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Scopa!",
                    detail: "Take every card on the table and you score one point at once.")
            HStack(spacing: 18) {
                BroomMark(size: 44, tint: Palette.goldLight)
                    .padding(18)
                    .glass(.riviera(), in: .circle)
                Text("Scopa means broom in Italian: you sweep the table clean.")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Take(played: Card(.five, of: .cups), taking: [Card(.five, of: .coins)],
                 note: "The last card on the table: nothing is left, so that is a scopa.")
            Tip(text: "The very last card of the round never makes a scopa: the table empties then anyway.")
        }
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Counting points",
                    detail: "At the end of each round, look at the cards you took. Four points are up for grabs.")
            VStack(spacing: 10) {
                Point(title: "Most cards", detail: "More cards than anyone else") {
                    HStack(spacing: -11) {
                        CardBack(width: 17)
                        CardBack(width: 17).rotationEffect(.degrees(9))
                    }
                }
                Point(title: "Most coins", detail: "More coin cards than anyone else") {
                    SuitMark(.coins, size: 24)
                }
                Point(title: "The settebello", detail: "Whoever took the 7 of coins") {
                    CardView(card: .settebello, width: 24)
                }
                Point(title: "Primiera", detail: "Whoever took the most 7s") {
                    Text(verbatim: "7")
                        .font(.display(24))
                        .foregroundStyle(Palette.goldLight)
                }
            }
            VStack(spacing: 10) {
                Tip(text: "Each scopa adds one more point.")
                Tip(text: "A tie on a line: nobody gets that point.")
                Tip(text: "Cards still on the table at the end go to the last player who took.")
                Tip(text: "First to 11 points wins. Level at the top? One more round.")
            }
        }
    }

    /// The last page: the offer of a coached game, and what the two coach marks mean.
    private var ready: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Play one with me",
                    detail: "Hugo deals, and I talk you through it — one hand is usually enough.")
            HStack(spacing: 16) {
                BotFace(tint: Palette.goldLight, size: 40)
                    .padding(16)
                    .glass(.riviera(), in: .circle)
                Text("For every card you hold I say what it would take, and what it would cost. When Hugo plays, I say what he just did to you.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                MarkLine(standing: .best, text: "The card I would play")
                MarkLine(standing: .costly, text: "It can be played, but it costs you something")
            }
            Paragraph("You can turn the coach down to a quieter level, or off, in the settings whenever you have had enough of me.")
        }
    }

    // MARK: Getting through them

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(chapters) { page in
                    Capsule()
                        .fill(page == chapter ? Palette.goldLight : Palette.onTableSoft.opacity(0.35))
                        .frame(width: page == chapter ? 22 : 7, height: 7)
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.2), value: chapter)
            Button(closing ? finishTitle : "Next", action: advance)
                .buttonStyle(FilledButtonStyle())
            if closing, onFinish != nil {
                Button("Not now") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var closing: Bool { chapter == chapters.last }

    private var finishTitle: LocalizedStringKey {
        onFinish == nil ? "Let's play" : "Deal me a hand"
    }

    private func advance() {
        let pages = chapters
        guard let chapter, let index = pages.firstIndex(of: chapter), index + 1 < pages.count else {
            // Called before dismiss: the caller defers the deal until the sheet is gone.
            onFinish?()
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { self.chapter = pages[index + 1] }
    }
}

private enum Chapter: Int, CaseIterable, Identifiable {
    case deck, take, scopa, deal, points, ready
    /// The house rules of the table the book was opened from.
    case house
    case goal

    var id: Int { rawValue }
}

/// One of the two marks the coached table draws on a card, with what it means beside it.
private struct MarkLine: View {
    let standing: Coach.Standing
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            CoachMark(standing: standing)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
    }
}

// MARK: - Pieces

struct Heading: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.display(42))
                .foregroundStyle(Palette.onTable)
            Text(detail)
                .font(.system(size: 16))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Paragraph: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(Palette.onTable.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One line of the game in order, numbered, for the page that sums it up.
private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background { Circle().fill(Palette.goldSheen) }
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
    }
}

/// A rule worth remembering, one sentence long, set apart from the pictures.
private struct Tip: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control)
    }
}

/// One card of each suit, spread the way a hand is.
private struct Fan: View {
    private static let cards = [Card.settebello, Card(.three, of: .cups),
                                Card(.king, of: .swords), Card(.ace, of: .clubs)]

    var body: some View {
        HStack(spacing: -14) {
            ForEach(Array(Self.cards.enumerated()), id: \.element) { index, card in
                CardView(card: card, width: 62)
                    .rotationEffect(.degrees(Double(index) * 5 - 7.5))
                    .zIndex(Double(index))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// The four suits under the names they are called by at an Italian table.
private struct Suits: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Suit.allCases, id: \.self) { suit in
                VStack(spacing: 8) {
                    SuitMark(suit, size: 30)
                    Text(suit.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .glassPanel(radius: GlassRadius.control)
    }
}

/// A take: the card played, and what it lifts off the table. Empty `taking` shows a card
/// that stays down.
struct Take: View {
    let played: Card
    let taking: [Card]
    let note: LocalizedStringKey

    private static let width: CGFloat = 50

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CardView(card: played, width: Self.width, highlighted: true)
                Image(systemName: taking.isEmpty ? "arrow.down" : "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(taking.isEmpty ? Palette.onTableSoft : Palette.goldLight)
                if taking.isEmpty {
                    Text("stays down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                } else {
                    HStack(spacing: 8) {
                        ForEach(taking) { CardView(card: $0, width: Self.width, outlined: true) }
                    }
                }
            }
            Text(note)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .glassPanel(radius: GlassRadius.control)
    }
}

/// The opening deal: four on the table, three in a hand nobody else sees.
private struct Deal: View {
    private static let table = [Card(.ace, of: .cups), Card(.six, of: .coins),
                                Card(.knave, of: .clubs), Card(.two, of: .swords)]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Self.table) { CardView(card: $0, width: 46) }
                }
                Caption(text: "On the table")
            }
            VStack(spacing: 8) {
                HiddenHand(count: 3, width: 40)
                Caption(text: "In each hand")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassPanel(radius: GlassRadius.control)
    }
}

/// One of the four points won at the end of a round.
struct Point<Mark: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let mark: Mark

    var body: some View {
        HStack(spacing: 14) {
            mark.frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Pill(text: "1 point")
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
    }
}

// MARK: - The way in

/// The round ? that opens the rules.
struct RulesButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .glass(.riviera(interactive: true), in: .circle)
                .contentShape(.circle)
        }
        .foregroundStyle(Palette.onTable)
        .accessibilityLabel("How to play")
    }
}

#Preview {
    RulesView()
}
