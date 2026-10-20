import SwiftUI
import ScopaCore

/// The whole deal laid open: your hand, what each bot holds, and the stock in the order it
/// will be dealt, hand by hand and seat by seat. A card of yours and a card still to come,
/// tapped one after the other in either order, trade places.
struct ScatouchDeckSheet: View {
    let scatouch: ScatouchTable

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    /// Each card keeps one identity across the sheet, so a swap is seen crossing it.
    @Namespace private var places
    @State private var mine: Card?
    @State private var wanted: Card?
    @State private var swaps = 0
    /// Opened tall: the stock is the reason to be here, and it is below the hands.
    @State private var detent = PresentationDetent.large

    private static let handWidth: CGFloat = 56
    private static let deckWidth: CGFloat = 44
    private static let nameWidth: CGFloat = 70

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                botSwitch
                if let state = scatouch.state { laidOpen(state) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { TableGround() }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .animation(.spring(duration: 0.5, bounce: 0.18), value: scatouch.state)
        .animation(.snappy(duration: 0.2), value: [mine, wanted])
        .sensoryFeedback(Haptic.swap, trigger: swaps)
        .sensoryFeedback(trigger: [mine, wanted]) { _, picked in picked.contains { $0 != nil } ? Haptic.pick : nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: "Scatouch")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            }
            Text(instruction)
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    /// Off until asked for: making every bot's move makes a long game of it.
    private var botSwitch: some View {
        SettingsToggle(title: "Play for the bots",
                       line: "Each bot waits for you to pick its card, or for you to let it play",
                       isOn: Binding(get: { scatouch.playsForBots }, set: { scatouch.playForBots($0) }))
            .glassPanel(radius: GlassRadius.control)
    }

    private var instruction: LocalizedStringKey {
        if mine != nil { return "Now the card still to come that you want instead." }
        if wanted != nil { return "Now the card of yours it takes the place of." }
        return "Every card at the table, face up. Tap one of yours, then one still to come, and they trade places."
    }

    @ViewBuilder private func laidOpen(_ state: GameState) -> some View {
        let canSwap = state.phase == .playing && !(state.round?.stock.isEmpty ?? true)
        let hands = state.round?.hands ?? []
        section(Text("Your hand")) {
            row(hands[safe: scatouch.homeSeat] ?? [], width: Self.handWidth, picked: mine,
                pick: canSwap ? { pick(mine: $0) } : nil)
        }
        ForEach(scatouch.bots.sorted(), id: \.self) { seat in
            section(Text("\(name(ofSeat: seat, in: state)) holds")) {
                row(hands[safe: seat] ?? [], width: Self.handWidth)
            }
        }
        section(Text("Still to come")) { stock(state, canSwap: canSwap) }
    }

    @ViewBuilder private func stock(_ state: GameState, canSwap: Bool) -> some View {
        let deals = state.upcomingDeals
        if deals.isEmpty {
            Text("Every card has been dealt.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.onTableSoft)
        }
        let next = state.view(forSeat: scatouch.homeSeat).handNumber + 1
        ForEach(Array(deals.enumerated()), id: \.offset) { index, deal in
            VStack(alignment: .leading, spacing: 8) {
                Text("Hand \(next + index)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
                ForEach(Array(deal.enumerated()), id: \.offset) { seat, cards in
                    HStack(spacing: 10) {
                        Text(verbatim: name(ofSeat: seat, in: state))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.onTable)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: Self.nameWidth, alignment: .leading)
                        row(cards, width: Self.deckWidth, picked: wanted, pick: canSwap ? { pick(wanted: $0) } : nil)
                    }
                }
            }
        }
    }

    private func section(_ title: Text, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.system(size: 13, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.onTableSoft)
            content()
        }
    }

    /// A line of cards, each tappable when `pick` is given. The picked one stands up out of it.
    private func row(_ cards: [Card], width: CGFloat, picked: Card? = nil,
                     pick: ((Card) -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            ForEach(cards, id: \.self) { card in
                CardView(card: card, width: width, highlighted: card == picked)
                    .offset(y: card == picked ? -6 : 0)
                    .matchedGeometryEffect(id: card, in: places)
                    .onTapGesture { pick?(card) }
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: card.spoken))
                    .accessibilityAddTraits(pick == nil ? [] : .isButton)
            }
        }
        .padding(.top, 6)
    }

    private func name(ofSeat seat: Int, in state: GameState) -> String {
        guard seat != scatouch.homeSeat else { return String(localized: "You", locale: locale) }
        return (state.configuration.players[safe: seat]?.name ?? "").shortName(9)
    }

    private func pick(mine card: Card) {
        mine = mine == card ? nil : card
        swapIfReady()
    }

    private func pick(wanted card: Card) {
        wanted = wanted == card ? nil : card
        swapIfReady()
    }

    private func swapIfReady() {
        guard let mine, let wanted else { return }
        scatouch.swap(mine, for: wanted)
        self.mine = nil
        self.wanted = nil
        swaps += 1
    }
}
