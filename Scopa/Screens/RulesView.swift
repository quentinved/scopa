import SwiftUI
import ScopaCore

/// How to play, in short chapters drawn with real cards in the chosen deck. Opens once on
/// first launch, then only from the ? buttons and the settings row.
struct RulesView: View {
    /// Set by the lobby to deal a coached hand from the last page. Nil elsewhere, where
    /// the last button only closes.
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var chapter = Chapter.deck

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
                .tag(chapter)
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
        case .deck: deck
        case .take: take
        case .scopa: scopa
        case .deal: deal
        case .points: points
        case .ready: ready
        }
    }

    /// The closing offer is only a page when there is a table to deal.
    private var chapters: [Chapter] {
        onFinish == nil ? Chapter.allCases.filter { $0 != .ready } : Chapter.allCases
    }

    private var deck: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Forty cards",
                    detail: "Four Italian suits, one to ten. No jokers, nothing wild.")
            Fan()
            Paragraph("The number in the corner is the whole game: it is what the card takes with. The three court cards are simply 8, 9 and 10.")
            Suits()
        }
    }

    private var take: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Take, or leave it",
                    detail: "On your turn you play one card. If it can take, it takes.")
            Take(played: Card(.four, of: .cups), taking: [Card(.four, of: .swords)],
                 note: "Same number: your 4 takes the 4.")
            Take(played: .settebello, taking: [Card(.three, of: .clubs), Card(.four, of: .coins)],
                 note: "Or cards that add up to it: 3 + 4 makes 7.")
            Take(played: Card(.two, of: .swords), taking: [],
                 note: "Nothing matches and nothing adds up, so your card stays on the table.")
            Paragraph("Taking is never optional — if your card can take, you may not lay it down instead.")
            Paragraph("And one card of the same number always wins over a sum: with a 7 on the table beside a 3 and a 4, your 7 takes the 7.")
        }
    }

    private var scopa: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Scopa!",
                    detail: "Sweep the table clean and it is a point, there and then.")
            HStack(spacing: 18) {
                BroomMark(size: 44, tint: Palette.goldLight)
                    .padding(18)
                    .glass(.riviera(), in: .circle)
                Text("Scopa is the Italian for broom. It is the point everyone plays for.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Take(played: Card(.five, of: .cups), taking: [Card(.five, of: .coins)],
                 note: "The last card on the table: nothing is left, so that is a scopa.")
            Paragraph("The only sweep that does not count is the one made with the very last card of the round — by then the table is bound to empty.")
        }
    }

    private var deal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Three cards at a time",
                    detail: "Four cards go face up on the table, three into every hand.")
            Deal()
            Paragraph("When everyone has played their three, three more are dealt, and again, until the deck is empty.")
            Paragraph("Whatever is still lying on the table at the end goes to whoever took last. That one is not a scopa.")
        }
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Counting up",
                    detail: "Four points sit on the table, and every scopa adds one more.")
            VStack(spacing: 10) {
                Point(title: "Most cards", detail: "Twenty-one of the forty is enough") {
                    HStack(spacing: -11) {
                        CardBack(width: 17)
                        CardBack(width: 17).rotationEffect(.degrees(9))
                    }
                }
                Point(title: "Most coins", detail: "Six of the ten denari") {
                    SuitMark(.coins, size: 24)
                }
                Point(title: "The settebello", detail: "The 7 of coins, worth a point on its own") {
                    CardView(card: .settebello, width: 24)
                }
                Point(title: "Primiera", detail: "Your best card in each suit, added up: 7 is the best, then 6, then the ace. A table can settle it by counting sevens instead") {
                    Text(verbatim: "7")
                        .font(.display(24))
                        .foregroundStyle(Palette.goldLight)
                }
            }
            Paragraph("A category nobody wins outright scores nothing, and a tie counts as nobody. First past the target — eleven, unless the host says otherwise — wins, and a dead heat plays one more round.")
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
        guard let index = pages.firstIndex(of: chapter), index + 1 < pages.count else {
            // Called before dismiss: the caller defers the deal until the sheet is gone.
            onFinish?()
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { chapter = pages[index + 1] }
    }
}

private enum Chapter: Int, CaseIterable, Identifiable {
    case deck, take, scopa, deal, points, ready

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

private struct Heading: View {
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

private struct Paragraph: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Palette.onTableSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
private struct Take: View {
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
private struct Point<Mark: View>: View {
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
