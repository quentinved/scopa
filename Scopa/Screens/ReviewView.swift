import SwiftUI
import ScopaCore

/// The finished game read back, the way a chess app tells you where it went: how close
/// your moves came to the best there was, the ones worth going back to, and every move
/// with the table as it stood. Judged only on what you could see at the time.
struct ReviewView: View {
    let store: TableStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    /// The seat being read. Nil until somebody picks one, which on a networked table
    /// nobody can: there is only yours.
    @State private var pickedSeat: Int?

    private var seat: Int? { pickedSeat ?? store.reviewedSeat }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let review = store.review, let seat, let view = store.view {
                        if store.reviewableSeats.count > 1 { seats(in: view) }
                        headline(review.summary(forSeat: seat))
                        lessons(review.summary(forSeat: seat))
                        everyMove(review.moves(forSeat: seat))
                    } else {
                        reading
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { TableGround() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Palette.goldLight)
                }
            }
        }
    }

    // MARK: Sections

    /// On a shared phone every person at the table gets their own reading.
    private func seats(in view: PlayerView) -> some View {
        Picker("Seat", selection: Binding(get: { seat ?? 0 }, set: { pickedSeat = $0 })) {
            ForEach(store.reviewableSeats, id: \.self) { seat in
                Text(view.configuration.players[safe: seat]?.name ?? "Seat \(seat + 1)").tag(seat)
            }
        }
        .pickerStyle(.segmented)
    }

    private func headline(_ summary: GameReview.Summary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(summary.accuracy)%")
                        .font(.display(56))
                        .foregroundStyle(Palette.goldSheen)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                    Caption(text: "Accuracy")
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                Stat(value: summary.praiseCount, label: "Best moves", tint: Palette.gold)
                Stat(value: summary.lessonCount, label: "Lessons", tint: Palette.terracotta)
            }
            // The verdicts that came up, in the order they are worth hearing.
            let counts = Verdict.allCases.compactMap { verdict in
                (summary.counts[verdict] ?? 0) > 0 ? (verdict, summary.counts[verdict]!) : nil
            }
            FlowingChips(items: counts.map { CountChip(verdict: $0.0, count: $0.1) })
        }
        .padding(18)
        .glassPanel()
    }

    @ViewBuilder private func lessons(_ summary: GameReview.Summary) -> some View {
        if summary.lessons.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Caption(text: "Worth a look")
                // A near miss is not a lesson and never shows up here, so a spotless
                // game cannot be promised next to an accuracy under 100.
                if (summary.counts[.fine] ?? 0) == 0 {
                    Text("Nothing to teach you here. Every move was the one to make.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No mistakes to go back to. A few moves were near misses rather than the best there was.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Caption(text: "Worth a look")
                ForEach(summary.lessons.prefix(3)) { move in
                    MoveRow(move: move, expanded: true)
                }
            }
        }
    }

    /// Lazy, because a four-handed game is well over a hundred moves and each row draws a
    /// card or more. Built eagerly, the sheet drew every one of them before it could open.
    private func everyMove(_ moves: [MoveReview]) -> some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            Caption(text: "Every move")
            ForEach(moves) { move in
                MoveRow(move: move, expanded: false)
            }
        }
    }

    private var reading: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Palette.onTable)
            Text("Reading the game back…")
                .font(.system(size: 15))
                .foregroundStyle(Palette.onTableSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Pieces

/// A number with a word under it.
private struct Stat: View {
    let value: Int
    let label: LocalizedStringKey
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(value)")
                .font(.display(30))
                .foregroundStyle(tint)
                .monospacedDigit()
            Caption(text: label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// "3 × Best move", coloured like its verdict.
private struct CountChip: View, Identifiable {
    let verdict: Verdict
    let count: Int

    var id: Verdict { verdict }

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(count)")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
            Text(verdict.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Palette.onTable)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .glassCapsule(tint: verdict.tint.opacity(0.55))
    }
}

/// Chips that wrap onto the next line when the row is full.
private struct FlowingChips<Item: View & Identifiable>: View {
    let items: [Item]

    var body: some View {
        // Enough for a dozen chips, and it stays honest about type size.
        WrappingRow(spacing: 8, lineSpacing: 8) {
            ForEach(items) { $0 }
        }
    }
}

/// Places its children left to right and wraps like text.
private struct WrappingRow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: width == .infinity ? widest : width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// One move: the card, the verdict, what it did, and for a lesson what would have been
/// better, over the table as it stood.
private struct MoveRow: View {
    let move: MoveReview
    /// A lesson shows the table and the better move. The plain list keeps to one line.
    let expanded: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CardView(card: move.move.card, width: expanded ? 48 : 40)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(move.verdict.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(move.verdict.tint)
                    Spacer(minLength: 8)
                    Text(String(localized: "Round \(move.round)", locale: locale) + " · " +
                         String(localized: "Hand \(move.view.handNumber)", locale: locale))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                }
                Text(happened)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onTable)
                    .fixedSize(horizontal: false, vertical: true)
                if move.verdict.isLesson { better }
                if expanded || move.verdict.isLesson { table }
            }
        }
        .padding(12)
        .glassPanel(radius: GlassRadius.control,
                    tint: move.verdict.isLesson && expanded ? Palette.terracotta.opacity(0.18) : nil)
    }

    private var happened: String {
        if move.move.captures.isEmpty {
            return String(localized: "Laid it on the table", locale: locale)
        }
        if move.sweeps {
            return String(localized: "Took \(move.move.captures.rankList) and swept the table", locale: locale)
        }
        return String(localized: "Took \(move.move.captures.rankList)", locale: locale)
    }

    private var better: some View {
        HStack(spacing: 8) {
            Text("Better:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            CardView(card: move.best.card, width: 26)
            Text(move.best.captures.isEmpty
                 ? String(localized: "laid on the table", locale: locale)
                 : String(localized: "taking \(move.best.captures.rankList)", locale: locale))
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTable)
        }
        .padding(.top, 2)
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("On the table")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
            HStack(spacing: 4) {
                if move.view.table.isEmpty {
                    Text("Nothing")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                } else {
                    ForEach(move.view.table) { card in
                        CardView(card: card, width: 26, outlined: move.move.captures.contains(card))
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}
