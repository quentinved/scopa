import SwiftUI
import ScopaCore

/// The coach, at the table: one strip under the hand that says what the card you are
/// holding would do, and one badge on the cards themselves.
///
/// It only appears at the coached level, where a first game lands after the walkthrough.
/// Every word comes out of `Coach`, which weighs moves with the same bot the review uses,
/// so the strip and the reading afterwards cannot contradict each other.

// MARK: - What there is to say

/// The one thing worth saying at this moment, picked by the table screen.
enum CoachSay: Equatable {
    /// A card is in the air: what it would do, and why.
    case counsel(Coach.Counsel)
    /// Your move, nothing picked yet. It says what is in the hand without saying which
    /// card it is in.
    case lookFor(Chance)
    /// The move that has just been made against you, while the cards it took are still
    /// being shown on the cloth.
    case theirMove(Coach.Reading, name: String)
    /// Somebody else is on the move.
    case waiting(String)
    /// Between rounds, or a table with nothing to say.
    case quiet

    /// What the hand holds, said without naming the card.
    enum Chance: Equatable { case sweep, take, nothing }
}

extension CoachSay {
    /// What the coach makes of a hand nobody has picked from yet.
    static func lookingAt(_ counsels: [Coach.Counsel]) -> CoachSay {
        if counsels.contains(where: \.sweeps) { return .lookFor(.sweep) }
        if counsels.contains(where: \.takes) { return .lookFor(.take) }
        return .lookFor(.nothing)
    }
}

// MARK: - The strip

/// Two lines under the hand: what the move is, and why. Its height is fixed at two lines
/// so that picking a card up and putting it down again never shifts the cards underneath.
struct CoachStrip: View {
    let say: CoachSay
    let stage: Stage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: stage.pick(tall: 56, wide: 52), alignment: .top)
        .glassPanel(radius: GlassRadius.control)
        .animation(.easeInOut(duration: 0.2), value: say)
    }

    private var counsel: Coach.Counsel? {
        if case .counsel(let counsel) = say { return counsel }
        return nil
    }

    private var tint: Color {
        if case .theirMove(let reading, _) = say { return reading.sweeps ? Palette.terracotta : Palette.onTable }
        return counsel?.standing.tint ?? Palette.onTable
    }

    private var headline: LocalizedStringKey {
        switch say {
        case .counsel(let counsel): counsel.action
        case .theirMove(let reading, let name): reading.headline(by: name)
        case .lookFor(.sweep): "There is a sweep in this hand"
        case .lookFor(.take): "Something here takes"
        case .lookFor(.nothing): "Nothing here takes"
        case .waiting(let name): "\(name) is thinking"
        case .quiet: " "
        }
    }

    /// Why a move is worth making, or what it costs. One line: nobody reads a second one
    /// mid-game.
    private var detail: LocalizedStringKey {
        switch say {
        case .counsel(let counsel):
            let notes = counsel.standing == .costly
                ? counsel.warnings + counsel.reasons
                : counsel.reasons + counsel.warnings
            return notes.first?.advice ?? "Play it when you are ready."
        case .theirMove(let reading, let name):
            return reading.line(by: name) ?? "Your move."
        case .lookFor(.sweep): return "Find the card that clears the table and the point is yours."
        case .lookFor(.take): return "Tap a card and I will tell you what it would do."
        case .lookFor(.nothing): return "One of them has to go down. The question is which you can spare."
        case .waiting: return "Watch what the card does when it lands."
        case .quiet: return " "
        }
    }
}

// MARK: - The badge on a card

/// What the coach thinks of one card in hand, drawn on its corner: gold for the move to
/// make, terracotta for the one that costs. A sound move is left unmarked.
struct CoachMark: View {
    let standing: Coach.Standing

    /// The cloth under it, so what it drops is the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        if standing != .sound {
            Image(systemName: standing == .best ? "star.fill" : "exclamationmark")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Palette.cream)
                .frame(width: 20, height: 20)
                .background(Circle().fill(standing.tint))
                .overlay(Circle().strokeBorder(Palette.cream.opacity(0.7), lineWidth: 1))
                .shadow(color: felt.shade(0.4), radius: 3, y: 1)
                .accessibilityLabel(standing.label)
        }
    }
}

// MARK: - Words for a counsel

extension Coach.Counsel {
    /// What playing this card does, in one phrase.
    var action: LocalizedStringKey {
        guard takes else { return "Lays the \(card.rank.label) down" }
        return sweeps ? "Takes \(captures.rankList) and sweeps" : "Takes \(captures.rankList)"
    }
}

extension Coach.Reading {
    /// What they did, in the same shape the callout on the cloth says it, so the two read
    /// as one sentence.
    func headline(by name: String) -> LocalizedStringKey {
        if sweeps { return "\(name) swept the table" }
        if takes { return "\(name) took \(captures.rankList)" }
        return "\(name) laid the \(card.rank.label) down"
    }

    /// The line under it: what the move did to you, or what it left lying there.
    func line(by name: String) -> LocalizedStringKey? {
        notes.compactMap { $0.telling(name) }.first
    }
}

#Preview {
    VStack(spacing: 12) {
        CoachStrip(say: .lookFor(.sweep), stage: .tall)
        CoachStrip(say: .waiting("Hugo"), stage: .tall)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { TableGround() }
}
