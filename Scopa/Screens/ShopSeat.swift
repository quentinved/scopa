import ScopaCore
import ScopaRewards
import SwiftUI

/// What the other players see of you: your badge, its colour and frame, who sits with you,
/// and what you can say.
struct ShopSeat: View {
    @Bindable var store: TableStore
    let purse: PurseStore
    let counter: ShopCounter

    var body: some View {
        ShopSection(title: "You", subtitle: "How the other players see you at the table.", anchor: "you") {
            marks
            liveries
            cornici
            companions
            sayings
        }
    }

    // MARK: Badge

    /// The marks for sale, then the earned ones as goals.
    private var marks: some View {
        ShopShelf(.mark) {
            marksForSale
            marksToEarn
        }
        .reactsToPick(store.seatMark)
    }

    private var marksForSale: some View {
        ForEach(SeatMark.forSale) { mark in
            let item = Cosmetics.item(for: mark)
            Button { counter.buyIfNeeded(item) { store.seatMark = mark } } label: {
                Swatch(title: mark.name, detail: mark.explanation, item: item,
                       owned: purse.owns(mark),
                       equipped: store.seatMark == mark,
                       affordable: counter.affordable(item),
                       justBought: counter.justBought(item)) {
                    SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46, mark: mark)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var marksToEarn: some View {
        ForEach(SeatMark.allCases.filter { $0.requirement != nil }) { mark in
            let earned = mark.isUnlocked(by: progress)
            Button {
                if earned { store.seatMark = mark; Audio.shared.play(.toggle) }
                else { Audio.shared.play(.refused) }
            } label: {
                Swatch(title: mark.name, detail: mark.explanation, item: nil,
                       owned: earned,
                       equipped: store.seatMark == mark,
                       affordable: true,
                       earnedBy: earned ? nil : mark.requirement?.label) {
                    SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46, mark: mark)
                        .saturation(earned ? 1 : 0)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var progress: MarkProgress {
        Achievements.markProgress(streak: store.dailyStreak, suits: store.albumBook.album.completedSuits,
                                  deck: store.albumBook.album.isComplete)
    }

    /// The badge in each colour, wearing the mark and the frame already chosen, so the tile
    /// is the player's own icon rather than a colour chip.
    private var liveries: some View {
        ShopShelf(.livery) {
            ForEach(SeatLivery.allCases) { livery in
                let item = Cosmetics.item(for: livery)
                Button { counter.buyIfNeeded(item) { store.livery = livery } } label: {
                    Swatch(title: livery.title, detail: livery.explanation, item: item,
                           owned: purse.owns(livery),
                           equipped: store.livery == livery,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item)) {
                        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 46,
                                  mark: store.seatMark, cornice: store.cornice, livery: livery)
                            // Room for whatever metal the chosen mark already wears.
                            .frame(height: 68)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.livery)
    }

    /// Previewed on the mark the player is wearing, since that is where a frame appears.
    private var cornici: some View {
        ShopShelf(.cornice) {
            ForEach(Cornice.allCases) { cornice in
                let item = Cosmetics.item(for: cornice)
                Button { counter.buyIfNeeded(item) { store.cornice = cornice } } label: {
                    Swatch(title: cornice.title, detail: cornice.explanation, item: item,
                           owned: purse.owns(cornice),
                           equipped: store.cornice == cornice,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item)) {
                        SeatBadge(name: store.playerName, tint: Palette.seat(0), size: 40,
                                  mark: store.seatMark, cornice: cornice)
                            // A badge draws outside its own size: room for the deepest ring.
                            .frame(height: 68)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.cornice)
    }

    // MARK: Company and words

    private var companions: some View {
        ShopShelf(.companion) {
            ForEach(Companion.allCases) { companion in
                let item = Cosmetics.item(for: companion)
                Button { counter.buyIfNeeded(item) { store.companion = companion } } label: {
                    Swatch(title: companion.title, detail: companion.explanation, item: item,
                           owned: purse.owns(companion),
                           equipped: store.companion == companion,
                           affordable: counter.affordable(item),
                           justBought: counter.justBought(item),
                           earnedBy: ShopEarning.fromAlbum(item)) {
                        CompanionSwatch(companion: companion, felt: store.tableFelt)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .reactsToPick(store.companion)
    }

    /// A set equips nothing: its phrases simply appear in the row at the table.
    private var sayings: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShelfHeading(.reactions)
            VStack(spacing: 10) {
                ForEach(Cosmetics.reactionPacks) { pack in
                    Button { if !purse.owns(pack) { counter.ask(for: pack.item) {} } } label: {
                        ReactionPackRow(pack: pack, owned: purse.owns(pack),
                                        affordable: purse.canAfford(pack.item),
                                        justBought: counter.bought == pack.id)
                    }
                    .buttonStyle(.plain)
                    .disabled(purse.owns(pack))
                }
            }
        }
    }
}

/// A set of phrases, with its four lines printed in the bubbles they arrive in.
private struct ReactionPackRow: View {
    let pack: Cosmetics.ReactionPack
    let owned: Bool
    let affordable: Bool
    let justBought: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: pack.title)
                        .font(.display(19))
                        .foregroundStyle(Palette.onTable)
                    Text(pack.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                price
            }
            lines
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
        .overlay { if justBought { Gilding().id(justBought) } }
        .opacity(owned || affordable ? 1 : 0.75)
        .contentShape(.rect(cornerRadius: GlassRadius.control))
    }

    @ViewBuilder private var price: some View {
        if owned {
            Label("Owned", systemImage: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else {
            DenariLabel(amount: pack.price, size: 15,
                        tint: affordable ? Palette.goldLight : Palette.onTableSoft)
        }
    }

    /// Two columns: a single row of four ran off the edge of a phone.
    private var lines: some View {
        let split = pack.reactions.count / 2 + pack.reactions.count % 2
        return HStack(alignment: .top, spacing: 8) {
            column(Array(pack.reactions.prefix(split)))
            column(Array(pack.reactions.dropFirst(split)))
        }
    }

    private func column(_ reactions: [Reaction]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(reactions, id: \.self) { reaction in
                SaidLine(reaction: reaction, size: 13, tint: Palette.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.22)))
                    .overlay { Capsule().strokeBorder(Palette.gold.opacity(0.28)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
