import SwiftUI
import ScopaCore

/// A house rule taught the way the rules book teaches the game: a page each, drawn with
/// real cards. The campaign opens it the first time a table brings a rule in, before the
/// cards are dealt; the stage card and the table's ? open it again whenever asked.
struct HouseRuleLesson: View {
    let rules: [HouseRule]
    /// Deals the table from the last page. Nil when the lesson is only being read again.
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var page: HouseRule?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(rules, id: \.self) { rule in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                Caption(text: onFinish == nil ? "House rule" : "New rule at this table")
                                HouseRulePage(rule: rule)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                        .tag(Optional(rule))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
            .background { TableGround() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onFinish == nil ? "Done" : "Not now") { dismiss() }
                        .tint(Palette.goldLight)
                }
            }
        }
        .onAppear { page = page ?? rules.first }
        .sensoryFeedback(.selection, trigger: page)
        .sound(.tap, trigger: page)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if rules.count > 1 {
                HStack(spacing: 7) {
                    ForEach(rules, id: \.self) { rule in
                        Capsule()
                            .fill(rule == page ? Palette.goldLight : Palette.onTableSoft.opacity(0.35))
                            .frame(width: rule == page ? 22 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.2), value: page)
            }
            Button(closing ? finishTitle : "Next", action: advance)
                .buttonStyle(FilledButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var closing: Bool { page == rules.last }

    private var finishTitle: LocalizedStringKey { onFinish == nil ? "Got it" : "Deal the cards" }

    private func advance() {
        guard let page, let index = rules.firstIndex(of: page), index + 1 < rules.count else {
            // Called before dismiss: the caller deals once the sheet is gone.
            onFinish?()
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { self.page = rules[index + 1] }
    }
}

/// One rule, explained. Also stacked on the rules book's "This table" page.
struct HouseRulePage: View {
    let rule: HouseRule

    var body: some View {
        switch rule {
        case .scopone: scopone
        case .reBello: reBello
        case .napola: napola
        case .assoPigliaTutto: asso
        }
    }

    private var scopone: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Scopone", detail: "Four of you in two teams, and the whole deck dealt at once.")
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Nothing")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.onTableSoft)
                        .frame(height: 40)
                    Caption(text: "On the table")
                }
                VStack(spacing: 8) {
                    HiddenHand(count: 10, width: 34)
                    Caption(text: "Ten in each hand")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassPanel(radius: GlassRadius.control)
            Paragraph("Your partner sits opposite. What either of you takes goes in one pile, and you score together.")
            Paragraph("The table starts empty, so the first card of the round is always laid down. With ten cards you can plan: watch what has gone, and play for your partner.")
            Paragraph("Taking, scope and points are the classic ones. There are no more deals: the round ends when the hands do.")
        }
    }

    private var reBello: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Re bello", detail: "The king of coins becomes a point of its own.")
            Point(title: "Re bello", detail: "The king of coins, worth a point like the settebello") {
                CardView(card: .reBello, width: 24)
            }
            Take(played: Card(.king, of: .cups), taking: [.reBello],
                 note: "Any king still takes it, as usual. Now it is worth fighting for.")
            Paragraph("Everything else is classic Scopa. A round has five points on the table instead of four.")
        }
    }

    private var napola: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Napola", detail: "The ace, 2 and 3 of coins in your pile score three points.")
            VStack(spacing: 10) {
                NapolaRun(ranks: [.ace, .two, .three], points: "3 points")
                NapolaRun(ranks: [.ace, .two, .three, .four, .five], points: "5 points")
                NapolaRun(ranks: [.ace, .three, .four], points: "Nothing")
            }
            Paragraph("Every coin that follows on adds a point: with the 4 it is four, with the 4 and the 5 it is five. All ten coins make ten.")
            Paragraph("It is counted at the end of the round, from the cards you took, on top of the classic points. Born in Naples, as the name says.")
        }
    }

    private var asso: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Asso piglia tutto", detail: "The ace takes everything on the table.")
            Take(played: Card(.ace, of: .cups),
                 taking: [Card(.five, of: .coins), Card(.king, of: .clubs), Card(.three, of: .swords)],
                 note: "Whatever is down, an ace sweeps it all up.")
            Paragraph("Taking it all with an ace is not a scopa: the ace did the work, not you.")
            Paragraph("On an empty table the ace is laid down, and the next ace takes it. No ace is ever dealt face up at the start.")
        }
    }
}

/// A row of coins from the ace, and what it scores as a napola.
private struct NapolaRun: View {
    let ranks: [Rank]
    let points: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ranks, id: \.self) { rank in
                CardView(card: Card(rank, of: .coins), width: 34)
            }
            Spacer(minLength: 8)
            Pill(text: points)
        }
        .padding(12)
        .glassPanel(radius: GlassRadius.control)
    }
}
