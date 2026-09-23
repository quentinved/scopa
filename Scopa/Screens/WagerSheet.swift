import SwiftUI
import ScopaCore
import ScopaRewards

/// Denari on the table, against whoever is online at the same stake; Hugo steps in if
/// nobody comes. Each stake says what it pays. The ones the purse cannot cover are simply
/// quiet: there is no shop behind them.
///
/// While the search runs the sheet cannot be closed, because the stake is already on the
/// table and closing would look like getting it back.
struct WagerSheet: View {
    let store: TableStore
    let purse: PurseStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var isSearching: Bool { store.stake != nil && store.onlineStatus != nil }

    var body: some View {
        // No way out while the search runs: the stake is already on the table, and a sheet
        // that can be swiped away would look like a way of getting it back.
        SheetScaffold(title: "For denari", subtitle: "Put coins down. The winner takes the pot.",
                      close: isSearching ? nil : { dismiss() }) {
            VStack(alignment: .leading, spacing: 12) {
                balance
                ForEach(Stake.allCases) { stake in
                    StakeRow(stake: stake,
                             balance: purse.isReady ? purse.balance : nil,
                             isBusy: isSearching) { sitDown(stake) }
                }
                if isSearching {
                    searching.transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let problem = purse.problem {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.terracotta)
                }
                SheetNote("Four seats at every wager table: people online who put down the same stake, and bots for the rest.")
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isSearching)
            .animation(.easeInOut(duration: 0.2), value: purse.balance)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSearching)
    }

    private var balance: some View {
        HStack(spacing: 14) {
            DenariMark(size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(purse.balance.coins, format: .number.grouping(.automatic))
                    .font(.display(30))
                    .foregroundStyle(Palette.goldSheen)
                    .contentTransition(.numericText())
                Text("In your purse")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control, tint: Palette.gold.opacity(0.16))
        .padding(.bottom, 2)
    }

    private var searching: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Palette.onTable)
            Text("Looking for players. Bots take the empty seats if nobody comes.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTable)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Bots now") { store.playBotForStake() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
    }

    private func sitDown(_ stake: Stake) {
        Task {
            let game = UUID()
            if await purse.stake(stake, gameID: game) { store.playForStake(stake, gameID: game) }
        }
    }
}

/// One stake: what goes down, what comes back if you win at two seats and at four, and —
/// on a table the purse cannot sit at yet — how near it is to being able to.
///
/// The bar is only ever on a table out of reach. A bar that is full on every row it appears
/// on says nothing, and the two stakes already paid for say what they need to in gold.
private struct StakeRow: View {
    let stake: Stake
    /// The purse, once the ledger has been read, and nil until then.
    let balance: Denari?
    let isBusy: Bool
    let sitDown: () -> Void

    private var affordable: Bool { (balance ?? .zero) >= stake.amount }
    /// What the purse is still short of this table, or nil when it can sit down — and also
    /// when the ledger has not answered yet, which is the one case with no figure to give.
    private var short: Denari? {
        guard let balance, balance < stake.amount else { return nil }
        return stake.amount - balance
    }
    /// How much of the stake is already in the purse, 0 to 1.
    private var filled: Double {
        guard let balance, stake.amount.coins > 0 else { return 0 }
        return min(max(Double(balance.coins) / Double(stake.amount.coins), 0), 1)
    }

    var body: some View {
        Button(action: sitDown) {
            words
                .padding(.horizontal, 14)
                .padding(.top, 12)
                // The bar lies in the row's own bottom margin rather than under it. Three
                // rows each a bar taller pushed the note at the foot of the sheet off the
                // medium detent, and the note is how somebody learns the seats are shared.
                .padding(.bottom, short == nil ? 12 : 16)
                .overlay(alignment: .bottom) {
                    if short != nil { reach.padding(.horizontal, 14).padding(.bottom, 5) }
                }
                .glassPanel(radius: GlassRadius.control,
                            tint: affordable ? Palette.gold.opacity(0.22) : nil, interactive: affordable)
        }
        .buttonStyle(.plain)
        .disabled(!affordable || isBusy)
        // A table out of reach is dimmed, but not as far as it used to be: it now carries
        // the figure and the bar, and a row nobody can read is a row worth nothing.
        .opacity(affordable ? 1 : 0.72)
    }

    private var words: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                DenariMark(size: 16)
                Text(verbatim: "\(stake.amount)")
                    .font(.display(24))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTable)
            }
            .frame(minWidth: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wins \(stake.payout.coins)–\(stake.payout(players: TableStore.wagerSeats).coins)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(affordable ? Palette.goldLight : Palette.onTableSoft)
                status
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    /// The figure somebody deciding whether to keep playing actually wants: not that the
    /// purse is short, but by how much.
    @ViewBuilder private var status: some View {
        if let short {
            Text("\(short.coins) more to sit down")
        } else if affordable {
            Text("Sit down")
        } else {
            Text("Not enough in the purse")
        }
    }

    /// How near the purse is to this table, in the gold it is counted in. Hidden from
    /// VoiceOver: the line above it has already said the number in words.
    private var reach: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.tableDeep.opacity(0.7))
                Capsule().fill(Palette.goldSheen)
                    .frame(width: max(geometry.size.width * filled, filled > 0 ? 5 : 0))
            }
        }
        .frame(height: 5)
        .animation(.snappy, value: filled)
        .accessibilityHidden(true)
    }
}
