import SwiftUI

/// A player off the campaign's board, struck as the seat badge they wear at a table.
struct CampaignFaceBadge: View {
    let look: any CampaignLook
    var size: CGFloat = 20
    /// Off on the map, where a bought ring would crowd the tables.
    var wearsCornice = true

    var body: some View {
        let mark = look.mark.flatMap(SeatMark.init(rawValue:)) ?? .initial
        let cornice = wearsCornice ? look.cornice.flatMap(Cornice.init(rawValue:)) ?? .none : .none
        SeatBadge(name: look.name, tint: Self.tint(look.id),
                  size: SeatBadge.fitted(size, mark: mark, cornice: cornice), mark: mark, cornice: cornice,
                  livery: look.livery.flatMap(SeatLivery.init(rawValue:)) ?? .tavolo)
            .frame(width: size, height: size)
    }

    /// A chair's colour picked from the id, the same on every phone and every launch.
    static func tint(_ id: String) -> Color {
        Palette.seat(id.unicodeScalars.reduce(0) { $0 + Int($1.value) })
    }
}

/// The players sitting at one table of the map: a few faces overlapping, the first on top,
/// and a count of the rest.
struct StageCrowd: View {
    let table: Ladder.CampaignTable
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(table.faces.enumerated()), id: \.element.id) { index, face in
                CampaignFaceBadge(look: face, size: size, wearsCornice: false)
                    .background { Circle().fill(Palette.ink.opacity(0.4)).padding(-1.5) }
                    .zIndex(Double(table.faces.count - index))
            }
            if table.more > 0 { more }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("^[\(table.count) player](inflect: true) at this table"))
    }

    private var more: some View {
        Text(verbatim: "+\(table.more)")
            .font(.system(size: size * 0.5, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Palette.onTable)
            .padding(.horizontal, 5)
            .frame(height: size * 0.8)
            .background(Palette.ink.opacity(0.45), in: .capsule)
            .padding(.leading, size * 0.3 + 3)
    }
}
