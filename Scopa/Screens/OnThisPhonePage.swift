import SwiftUI
import ScopaCore

/// Setting up the table that is played on one phone: any seat can be a friend who takes
/// the phone when their turn comes, or a bot that plays itself. One screen for both, since
/// a game of three can be you, a friend and a hand for the machine.
struct OnThisPhonePage: View {
    let you: String
    /// Whether the house tie rule is one this phone has been told about. Everybody else is
    /// dealt the rulebook without ever being shown that there was a choice.
    let knowsTieRules: Bool
    var start: (Table) -> Void

    /// Everything the page settles before the cards go out.
    struct Table {
        var seats: [LocalSeat]
        var teams: Bool
        var clock: TurnClock
        var target: Int
        var primiera: PrimieraRule
        var ties: TieRule
    }

    /// The seats after yours. Yours is always the first, and always a person.
    @State private var others: [Chair] = [Chair(name: Chair.botNames[0], isBot: true)]
    @State private var teams = false
    @State private var clock = TurnClock.default
    @State private var target = 11
    @State private var primiera = PrimieraRule.default
    @State private var ties = TieRule.default

    fileprivate struct Chair: Identifiable, Hashable {
        static let botNames = BotNames.all
        let id = UUID()
        var name: String
        var isBot: Bool

        static func suggestedName(seat: Int, isBot: Bool) -> String {
            isBot ? botNames[(seat - 1) % botNames.count] : "Player \(seat + 1)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                seats
                settings
            }
            .padding(20)
        }
        .softScrollEdge(.top)
        .safeAreaInset(edge: .bottom) {
            Button("Deal the cards") { start(table) }
                .buttonStyle(FilledButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(TableGround())
        .navigationTitle("Pass the phone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var table: Table {
        Table(seats: [.person(name: you)] + others.map { $0.isBot ? .bot(name: $0.name) : .person(name: $0.name) },
              teams: teams, clock: clock, target: target, primiera: primiera, ties: ties)
    }

    // MARK: The seats

    private var seats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Who is playing")
            yourSeat
            ForEach($others) { chair in
                let seat = (others.firstIndex { $0.id == chair.id } ?? 0) + 1
                ChairRow(chair: chair, seat: seat, teams: teams)
            }
            addAndRemove
            Text("A bot plays its own hand. Everyone else takes the phone when their turn comes round.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: others)
    }

    private var yourSeat: some View {
        HStack(spacing: 12) {
            SeatBadge(name: you, tint: Palette.seat(0), size: 34)
            Text(you)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("You")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.onTableSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control)
    }

    private var addAndRemove: some View {
        HStack(spacing: 10) {
            Button {
                let seat = others.count + 1
                others.append(Chair(name: Chair.suggestedName(seat: seat, isBot: true), isBot: true))
            } label: {
                Label("Add a seat", systemImage: "plus")
            }
            .disabled(others.count >= GameConfiguration.playerRange.upperBound - 1)

            Button {
                others.removeLast()
                teams = false
            } label: {
                Label("Remove", systemImage: "minus")
            }
            .disabled(others.count <= 1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Palette.terracotta)
        .padding(.top, 2)
    }

    // MARK: The rules of the table

    private var settings: some View {
        VStack(alignment: .leading, spacing: 20) {
            if others.count == 3 {
                Toggle("Play in teams", isOn: $teams)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.onTable)
                    .tint(Palette.terracotta)
            }
            choice("Time to play a card", selection: $clock, cases: TurnClock.allCases)
            choice("The primiera", selection: $primiera, cases: PrimieraRule.allCases)
            // The house rule, for the tables of whoever knows the words. Nobody else is
            // shown it: an option that is not on the box is better missing than greyed out.
            if knowsTieRules {
                choice("Level between you", selection: $ties, cases: TieRule.allCases)
            }
            HStack {
                Caption(text: "Play to")
                Spacer()
                ScoreStepper(value: target) { target = $0 }
            }
        }
    }

    /// One rule of the table: a caption, the choices, and what the chosen one means.
    private func choice<Rule: TableRule>(_ title: LocalizedStringKey, selection: Binding<Rule>,
                                         cases: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(text: title)
            Picker(title, selection: selection) {
                ForEach(cases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(selection.wrappedValue.explanation)
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
        }
    }
}

/// One seat that is not yours: a name, and whether anybody is sitting in it.
private struct ChairRow: View {
    @Binding var chair: OnThisPhonePage.Chair
    let seat: Int
    /// Whether the chairs are paired off, which is what decides their colour.
    let teams: Bool

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(spacing: 12) {
            PlayerBadge(name: chair.name, isBot: chair.isBot,
                        tint: Palette.seat(seat, teams: teams), size: 34)
            TextField("", text: $chair.name,
                      prompt: Text("Name").foregroundStyle(Palette.onTableSoft))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.onTable)
                .textFieldStyle(.plain)
                .lineLimit(1)
            kindPicker
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(radius: GlassRadius.control)
    }

    private var kindPicker: some View {
        HStack(spacing: 2) {
            chip("Friend", isBot: false)
            chip("Bot", isBot: true)
        }
        .padding(3)
        .background(Capsule().fill(felt.shade(0.45)))
    }

    private func chip(_ title: LocalizedStringKey, isBot: Bool) -> some View {
        let picked = chair.isBot == isBot
        return Button {
            // A name nobody has bothered to change follows the kind of seat it is.
            if chair.name == OnThisPhonePage.Chair.suggestedName(seat: seat, isBot: chair.isBot) {
                chair.name = OnThisPhonePage.Chair.suggestedName(seat: seat, isBot: isBot)
            }
            chair.isBot = isBot
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(height: 28)
                .padding(.horizontal, 12)
                .foregroundStyle(picked ? Palette.cream : Palette.onTableSoft)
                .background {
                    if picked { Capsule().fill(Palette.terracotta) }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: chair.isBot)
    }
}

/// A rule of the table that one segmented picker can set. `label` and `explanation` come
/// from `Language.swift`.
protocol TableRule: Hashable {
    var label: LocalizedStringKey { get }
    var explanation: LocalizedStringKey { get }
}

extension TurnClock: TableRule {}
extension PrimieraRule: TableRule {}
extension TieRule: TableRule {}
