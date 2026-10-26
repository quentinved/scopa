import SwiftUI
import ScopaCore

/// One of the second road's modes, explained the way a house rule is: a page of its own,
/// drawn with real cards where there are cards to draw. `HouseRuleLesson` stacks it with
/// the rules, the first time a table brings it in and whenever the stage card asks.
struct CampaignModePage: View {
    let mode: CampaignMode

    var body: some View {
        switch mode {
        case .rimonta: rimonta
        case .unaMano: unaMano
        case .carteScoperte: carteScoperte
        case .torneo: torneo
        }
    }

    private var rimonta: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Rimonta", detail: "A comeback: the game starts with the others already ahead.")
            HStack(spacing: 34) {
                StartingScore(name: "You", points: 0, tint: Palette.seat(0))
                StartingScore(name: "Them", points: 2, tint: Palette.seat(1))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassPanel(radius: GlassRadius.control)
            Paragraph("Their points are on the board before a card is dealt. Every round is counted the classic way, and the first to the target with the lead still wins.")
            Paragraph("Win by two and the second star is yours: on a comeback, two is plenty.")
        }
    }

    private var unaMano: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Una mano", detail: "One round decides the game.")
            // Everything a round can be won with, all of it in play at once.
            FlowRow(spacing: 8) {
                Pill(text: "Cards")
                Pill(text: "Coins")
                Pill(text: "Settebello")
                Pill(text: "Primiera")
                Pill(text: "Scope")
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassPanel(radius: GlassRadius.control)
            Paragraph("When the cards run out, whoever has more points wins. End level and another round is dealt, the totals carried on.")
            Paragraph("Nothing can be saved for later, so every card you take counts now.")
        }
    }

    private var carteScoperte: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Carte scoperte", detail: "Every hand is dealt face up.")
            VStack(spacing: 18) {
                hand([Card(.seven, of: .cups), Card(.three, of: .coins), Card(.king, of: .swords)], "Their hand")
                hand([Card(.four, of: .clubs), Card(.seven, of: .coins), Card(.knave, of: .cups)], "Your hand")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassPanel(radius: GlassRadius.control)
            Paragraph("You see what they hold, and they see what you hold. Only the deck stays hidden.")
            Paragraph("So the deal is the only luck: count what is left, and leave them nothing their cards can take.")
        }
    }

    private func hand(_ cards: [Card], _ caption: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            SeatHand(count: cards.count, cards: cards, width: 34)
            Caption(text: caption)
        }
    }

    private var torneo: some View {
        VStack(alignment: .leading, spacing: 22) {
            Heading("Torneo", detail: "Three games in a row, each against somebody new.")
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { game in
                    if game > 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.onTableSoft)
                    }
                    BotFace(tint: Palette.seat(game), size: 40)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassPanel(radius: GlassRadius.control)
            Paragraph("Win and the next player sits down. Lose and the torneo starts again from the first, whoever beat you.")
            Paragraph("How far you have got is kept between games, so you can stop for a coffee. The stars are counted in the last game.")
        }
    }
}

/// A side's points before the first card: a big number over its name.
private struct StartingScore: View {
    let name: LocalizedStringKey
    let points: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: "\(points)")
                .font(.display(44))
                .monospacedDigit()
                .foregroundStyle(tint)
            Caption(text: name)
        }
    }
}
