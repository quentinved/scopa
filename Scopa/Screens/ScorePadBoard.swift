import SwiftUI
import ScopaCore

/// The running score, the hand being counted, and the hands already counted.
struct ScorePadBoard: View {
    @Binding var pad: ScorePad
    /// Throws the pad away and goes back to choosing who plays.
    var reset: () -> Void

    @State private var hand: ScorePad.Hand

    init(pad: Binding<ScorePad>, reset: @escaping () -> Void) {
        _pad = pad
        self.reset = reset
        _hand = State(initialValue: ScorePad.Hand(sides: pad.wrappedValue.sides.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                standings
                if pad.winner == nil { entry }
                if !pad.hands.isEmpty { history }
            }
            .padding(20)
        }
        .softScrollEdge(.top)
        .safeAreaInset(edge: .bottom) { action }
        .toolbar { menu }
        .sensoryFeedback(.success, trigger: pad.winner) { _, winner in winner != nil }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: pad)
    }

    // MARK: The score

    private var standings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "First to \(pad.target)")
            let totals = pad.totals
            ForEach(pad.sides.indices, id: \.self) { side in
                StandingRow(name: pad.sides[side], tint: Palette.seat(side), total: totals[side],
                            gained: hand.points(sides: pad.sides.count)[side], won: pad.winner == side)
            }
        }
    }

    // MARK: This hand

    private var entry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Caption(text: "Hand \(pad.hands.count + 1)")
            PointPicker(title: "Most cards", sides: pad.sides, selection: $hand.cards)
            PointPicker(title: "Most coins", sides: pad.sides, selection: $hand.coins)
            PointPicker(title: "Seven of coins", sides: pad.sides, selection: $hand.settebello)
            PointPicker(title: "Primiera", sides: pad.sides, selection: $hand.primiera)
            scope
            SheetNote("A point you ended level on is nobody's: leave it unpicked.")
        }
    }

    private var scope: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scope")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            ForEach(pad.sides.indices, id: \.self) { side in
                HStack {
                    Text(verbatim: pad.sides[side])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.onTable)
                        .lineLimit(1)
                    Spacer()
                    CountStepper(value: $hand.scope[side])
                }
            }
        }
    }

    // MARK: The hands so far

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caption(text: "Hands played")
                Spacer()
                Button("Undo the last hand") { pad.undo() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.terracotta)
            }
            ForEach(pad.hands.indices.reversed(), id: \.self) { index in
                HandLine(number: index + 1, sides: pad.sides,
                         points: pad.hands[index].points(sides: pad.sides.count))
            }
        }
    }

    // MARK: Actions

    @ViewBuilder private var action: some View {
        Group {
            if pad.winner == nil {
                Button("Add the hand") {
                    pad.add(hand)
                    hand = ScorePad.Hand(sides: pad.sides.count)
                }
            } else {
                Button("New game") { pad.restart() }
            }
        }
        .buttonStyle(FilledButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("New game", systemImage: "arrow.counterclockwise") { pad.restart() }
                Button("Change players", systemImage: "person.2") { reset() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .tint(Palette.onTable)
        }
    }
}

/// One side's total, with what the hand being counted would add to it.
private struct StandingRow: View {
    let name: String
    let tint: Color
    let total: Int
    let gained: Int
    let won: Bool

    var body: some View {
        HStack(spacing: 12) {
            SeatBadge(name: name, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                if won {
                    Text("Wins the game")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.goldLight)
                }
            }
            Spacer(minLength: 0)
            if gained > 0 {
                Text(verbatim: "+\(gained)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            }
            Text(verbatim: "\(total)")
                .font(.display(30))
                .foregroundStyle(Palette.onTable)
                .contentTransition(.numericText())
                .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassPanel(radius: GlassRadius.control, tint: won ? Palette.gold.opacity(0.55) : nil)
    }
}

/// Who took one of the four points. Tapping the chosen side again takes it back.
private struct PointPicker: View {
    let title: LocalizedStringKey
    let sides: [String]
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTable)
            HStack(spacing: 6) {
                ForEach(sides.indices, id: \.self) { side in chip(side) }
            }
        }
    }

    private func chip(_ side: Int) -> some View {
        let picked = selection == side
        return Button {
            selection = picked ? nil : side
        } label: {
            Text(verbatim: sides[side])
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(picked ? Palette.cream : Palette.onTable)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, 6)
                .glassCapsule(tint: picked ? Palette.seat(side).opacity(0.9) : nil, interactive: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: picked)
    }
}

/// A small count with a minus and a plus, for the scope of one side.
private struct CountStepper: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            button("minus", by: -1).disabled(value == 0)
            Text(verbatim: "\(value)")
                .font(.display(22))
                .foregroundStyle(Palette.onTable)
                .frame(minWidth: 24)
                .contentTransition(.numericText())
            button("plus", by: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .glassCapsule()
    }

    private func button(_ symbol: String, by step: Int) -> some View {
        Button { value = max(0, value + step) } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.terracotta)
    }
}

/// One counted hand: its number and what each side took from it.
private struct HandLine: View {
    let number: Int
    let sides: [String]
    let points: [Int]

    var body: some View {
        HStack(spacing: 10) {
            Text("Hand \(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(minWidth: 56, alignment: .leading)
            ForEach(sides.indices, id: \.self) { side in
                HStack(spacing: 4) {
                    Circle().fill(Palette.seat(side)).frame(width: 8, height: 8)
                    Text(verbatim: "+\(points[side])")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassPanel(radius: GlassRadius.control)
    }
}
