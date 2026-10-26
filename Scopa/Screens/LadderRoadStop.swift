import SwiftUI
import ScopaCore

enum RoadPlace { case passed, here, ahead }

/// One league on the road: its medal on the rail, the stretch of rail down to the next,
/// its name and where it starts, and what it gives.
struct RoadStop<Prizes: View>: View {
    let league: League
    let state: RoadPlace
    /// How much of the rail below this league is run, 0 to 1.
    let fill: Double
    let drawn: Bool
    let title: String
    let line: String
    /// Drawn on the rail where the fill stops.
    let pin: AnyView?
    @ViewBuilder var prizes: Prizes

    private var metal: LeagueMetal { .league(league.rawValue) }
    private var nextMetal: LeagueMetal { .league(league.next?.rawValue ?? league.rawValue) }
    private var shownFill: Double { drawn ? fill : 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rail.frame(width: 50)
            VStack(alignment: .leading, spacing: 10) {
                header
                prizes
            }
            .padding(.top, 6)
            .padding(.bottom, league.next == nil ? 6 : 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: title)
                    .font(.display(26))
                    .foregroundStyle(state == .ahead ? Palette.onTableSoft : Palette.onTable)
                Spacer(minLength: 4)
                tag
            }
            Text(verbatim: line)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
    }

    @ViewBuilder private var tag: some View {
        switch state {
        case .passed:
            Label { Text("Reached") } icon: { Image(systemName: "checkmark") }
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(metal.light)
        case .here:
            Text("You are here")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(metal.light)
        case .ahead:
            EmptyView()
        }
    }

    // MARK: The rail

    private var rail: some View {
        VStack(spacing: 0) {
            node
            GeometryReader { geometry in
                let height = geometry.size.height
                ZStack(alignment: .top) {
                    Capsule().fill(Palette.onTableSoft.opacity(0.18)).frame(width: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [metal.light, nextMetal.base], startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: height * shownFill)
                        .shadow(color: metal.light.opacity(0.7), radius: 4)
                    if let pin { pin.offset(y: height * shownFill - 13) }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.55).delay(0.15 + Double(league.rawValue) * 0.14), value: drawn)
            }
            .padding(.vertical, 5)
        }
    }

    private var node: some View {
        LeagueMedal(league: league.rawValue, size: 42)
            .saturation(state == .ahead ? 0 : 1)
            .opacity(state == .ahead ? 0.5 : 1)
            .frame(width: 50, height: 50)
            .background {
                if state == .here {
                    Circle()
                        .fill(metal.base.opacity(0.25))
                        .overlay { Circle().strokeBorder(metal.light.opacity(0.7), lineWidth: 1.5) }
                        .frame(width: 60, height: 60)
                }
            }
    }
}

/// A prize on the road: the thing itself and one word under it. Tapped, it is worn or
/// put on the home screen, or refused while it is still ahead.
struct RoadPrize<Art: View>: View {
    let label: LocalizedStringKey
    let isEarned: Bool
    let isChosen: Bool
    let metal: LeagueMetal
    let action: () -> Void
    @ViewBuilder var art: Art

    @Environment(\.tableFelt) private var felt

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                art
                    .saturation(isEarned ? 1 : 0)
                    .opacity(isEarned ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) { if !isEarned { LockGlyph().offset(x: 4, y: 4) } }
                    .frame(height: 40)
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isChosen ? metal.light : Palette.onTableSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .frame(width: 80)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(felt.shade(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isChosen ? metal.light : Palette.onTableSoft.opacity(0.15),
                                          lineWidth: isChosen ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
