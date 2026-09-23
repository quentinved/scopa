import SwiftUI

/// A row on a sheet that is a whole choice: a symbol in its own colour, a name, a line.
struct SheetChoice: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SheetChoiceLabel(symbol: symbol, tint: tint, title: title, detail: detail, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct SheetChoiceLabel: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var isSelected = false

    var body: some View {
        HStack(spacing: 14) {
            SymbolCoin(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.cream : Palette.onTable)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Palette.cream.opacity(0.85) : Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if isSelected {
                Text("Stop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cream)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glassPanel(radius: GlassRadius.control,
                    tint: isSelected ? Palette.terracotta.opacity(0.75) : nil, interactive: true)
    }
}

/// A symbol on a small disc of its colour, so a list of choices scans by eye.
struct SymbolCoin: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 38

    var body: some View {
        Circle()
            .fill(tint.opacity(0.9))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Palette.cream)
            }
            .overlay { Circle().strokeBorder(Palette.cream.opacity(0.25), lineWidth: 1) }
    }
}

/// What the app is doing while an online table is being found, and a way to stop waiting.
///
/// A ranked search is the one wait in the app that knows its own length, so it gets a line
/// that runs out over exactly that and says what is at the end of it. Every other wait keeps
/// the spinner, which is the honest thing to show for one with no end in sight.
struct OnlineProgressLine: View {
    let store: TableStore
    let status: TableStore.OnlineStatus
    var waiting: LocalizedStringKey = "Looking for players"

    private var search: TableStore.RankedSearch? { status == .searching ? store.rankedSearch : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                if search == nil { ProgressView().tint(Palette.onTable) }
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
                Button("Stop") { store.cancelOnline() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
            }
            if let search { SearchCountdown(search: search) }
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control)
        .animation(.easeInOut(duration: 0.25), value: search?.isWidened)
    }

    private var label: LocalizedStringKey {
        switch status {
        case .signingIn: return "Signing in to Game Center"
        case .opening: return "Opening your table"
        case .searching:
            guard let search else { return waiting }
            return search.isWidened ? "Looking anywhere" : "Looking in your league"
        case .seating: return "Taking your seats"
        }
    }
}

/// The line under a ranked search: gold that runs out over exactly the seconds the search
/// has, and one line saying who sits down when it does.
///
/// Drawn from the clock rather than animated from a stored fraction, so a sheet redrawn
/// mid-search — the stage widening does that — picks the line up where it actually is
/// instead of starting it over.
private struct SearchCountdown: View {
    let search: TableStore.RankedSearch

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Thirty a second, not every frame the display can draw: a line this short moves
            // a pixel or two between ticks, and the panel sits over a lobby of glass that has
            // to be recomposited for each one.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                track(left: timeLeft(at: timeline.date))
            }
            // The line is the sentence drawn; VoiceOver reads the sentence.
            .accessibilityHidden(true)
            Text("The house takes the chair if nobody is found.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    /// How much of the search is still to come, 1 at the start and 0 at the end.
    private func timeLeft(at now: Date) -> Double {
        guard search.length > 0 else { return 0 }
        let gone = now.timeIntervalSince(search.startedAt) / search.length
        return min(max(1 - gone, 0), 1)
    }

    private func track(left: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(felt.shade(0.6))
                Capsule()
                    .fill(Palette.goldSheen)
                    .frame(width: max(geometry.size.width * left, 0))
            }
        }
        .frame(height: 6)
    }
}

/// The small print under a sheet's choices.
struct SheetNote: View {
    let text: LocalizedStringKey
    var size: CGFloat = 12

    init(_ text: LocalizedStringKey, size: CGFloat = 12) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.system(size: size))
            .foregroundStyle(Palette.onTableSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The chrome a play sheet stands in: the table behind it, its name in the display face, a
/// gold rule under that, and a round way out on the same line.
///
/// The sheets were navigation bars with an inline title, which is the chrome a settings
/// page wears — correct, and completely silent about what the sheet is for. These are rooms
/// you walk into: the stakes, the league, the ladder, the week. They get a headline.
struct SheetScaffold<Content: View, Bottom: View>: View {
    let title: LocalizedStringKey
    /// One line under the title. What the room is for, not an instruction.
    var subtitle: LocalizedStringKey? = nil
    /// Nil where the sheet must not be left — a search with a stake already on the table.
    var close: (() -> Void)? = nil
    @ViewBuilder var content: Content
    /// Pinned under the scroll: the sheet's own action, where it has one.
    @ViewBuilder var bottom: Bottom

    var body: some View {
        // The ground is a layer of the stack rather than a `.background` of the column.
        // Backing the column, it came out narrower than the sheet — a hand's width of the
        // lobby's own felt left standing down each side, which read as a bar on the right.
        ZStack {
            TableGround()
            VStack(spacing: 0) {
                header
                rule
                ScrollView { content }
                    .softScrollEdge(.top)
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom) { bottom }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The name on its own line with the way out beside it, and the line under it running
    /// the whole width of the sheet.
    ///
    /// The subtitle used to share a column with the close button, which left it a hand's
    /// width short: a sentence that would have fitted broke, and broke badly — five words
    /// on the first line and two on the second, under a headline set in the display face.
    /// Nothing sits beside the subtitle, so nothing needs to be kept clear of it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
                if let close { closeButton(close) }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// A hairline that fades out at both ends, so the header is ruled off without the sheet
    /// looking like a table with a border round it.
    private var rule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Palette.gold.opacity(0.55), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    private func closeButton(_ close: @escaping () -> Void) -> some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.onTable)
                .frame(width: 34, height: 34)
                .glass(.riviera(interactive: true), in: .circle)
                .overlay { Circle().strokeBorder(Palette.gold.opacity(0.30), lineWidth: 1) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

extension SheetScaffold where Bottom == EmptyView {
    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, close: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, close: close, content: content, bottom: { EmptyView() })
    }
}

/// A two- or three-way pick, in the app's own glass rather than the system's grey slab.
///
/// `.pickerStyle(.segmented)` is a light control, and on a lit green table it reads as a
/// piece of somebody else's app dropped on the felt. This is the same choice in gold on
/// glass, with the lit half sliding between the options rather than blinking across.
struct GlassSegments<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> LocalizedStringKey
    /// What a reader hears, where the segment is a figure rather than a word: "1v1" is read
    /// out as the letter v. Defaults to the segment's own text.
    var spoken: ((Value) -> LocalizedStringKey)?
    /// Off while the choice cannot be changed — a search already under way.
    var isEnabled = true

    @Namespace private var lit

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                    Audio.shared.play(.tap)
                } label: {
                    Text(title(option))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(option == selection ? Palette.ink : Palette.onTable)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if option == selection {
                                Capsule().fill(Palette.goldSheen)
                                    .matchedGeometryEffect(id: "lit", in: lit)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spoken?(option) ?? title(option))
                .accessibilityAddTraits(option == selection ? [.isSelected] : [])
            }
        }
        .padding(4)
        .glassCapsule()
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .animation(.snappy(duration: 0.28), value: selection)
    }
}
