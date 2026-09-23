import SwiftUI
import ScopaCore

/// A bounded pulse: on, off, a few times over, then done.
///
/// Never `repeatForever`: an endless animation keeps the whole screen compositing for the
/// length of somebody else's turn, under a dozen layers of glass.
private enum Pulse {
    @MainActor
    static func beat(times: Int, every half: TimeInterval, _ set: (Bool) -> Void) async {
        for _ in 0..<times {
            withAnimation(.easeInOut(duration: half)) { set(true) }
            try? await Task.sleep(for: .seconds(half))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: half)) { set(false) }
            try? await Task.sleep(for: .seconds(half))
            guard !Task.isCancelled else { return }
        }
    }
}

/// A ring around whoever the table is waiting on. Three breaths on arrival, then still.
struct TurnRing: View {
    var padding: CGFloat
    @State private var swollen = false

    var body: some View {
        Circle()
            .strokeBorder(Palette.goldLight, lineWidth: 2)
            .padding(-padding)
            .scaleEffect(swollen ? 1.12 : 1)
            .opacity(swollen ? 0.45 : 1)
            .task { await Pulse.beat(times: 3, every: 0.9) { swollen = $0 } }
    }
}

/// Whose move it is. Yours is terracotta, anyone else's takes their seat colour with a
/// dot that keeps time while they think.
struct TurnPill: View {
    let view: PlayerView
    let name: String
    @State private var beat = false

    /// The old label fades out before the new one fades in. A plain cross-fade drew both
    /// labels over each other at half strength.
    private static let swap = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.14).delay(0.14)),
        removal: .opacity.animation(.easeOut(duration: 0.14))
    )

    var body: some View {
        ZStack {
            if view.isMyTurn {
                yourTurn
            } else if let seat = view.turnSeat {
                theirTurn(seat: seat)
            } else {
                Text("Round over")
                    .foregroundStyle(Palette.onTable)
                    .transition(Self.swap)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
        // A long name in a narrow column gives ground by shrinking a little before it gives
        // up a word: "Bartolomeo is thinking" set slightly small still reads, "Bartolomeo is
        // thi…" does not.
        .minimumScaleFactor(0.85)
        // Free to give ground sideways so the pill never pushes the pile count off the row.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCapsule(tint: tint)
        .shadow(color: Palette.ink.opacity(0.28), radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.18), value: view.isMyTurn)
    }

    private var yourTurn: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.cream).frame(width: 8, height: 8)
            Text("Your turn")
        }
        .foregroundStyle(Palette.cream)
        .transition(Self.swap)
    }

    private func theirTurn(seat: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.cream)
                .frame(width: 8, height: 8)
                .scaleEffect(beat ? 1.35 : 1)
                // Keyed on the seat so each new player's turn gets its own beats.
                .task(id: seat) { await Pulse.beat(times: 3, every: 0.7) { beat = $0 } }
            Text("\(name) is thinking")
        }
        .foregroundStyle(Palette.cream)
        .transition(Self.swap)
    }

    private var tint: Color? {
        if view.isMyTurn { return Palette.terracotta }
        if let seat = view.turnSeat {
            return Palette.seat(seat, teams: view.configuration.teams).opacity(0.85)
        }
        return nil
    }
}

/// The edge of the screen lit in terracotta while it is your move. A couple of breaths
/// on arrival, then it holds.
struct TurnEdge: View {
    let isOn: Bool
    @State private var breathing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 56, style: .continuous)
            .strokeBorder(Palette.terracotta, lineWidth: breathing ? 34 : 24)
            .blur(radius: breathing ? 22 : 16)
            .padding(-6)
            .opacity(isOn ? (breathing ? 0.95 : 0.85) : 0)
            .overlay {
                RoundedRectangle(cornerRadius: 52, style: .continuous)
                    .strokeBorder(Palette.terracotta.opacity(breathing ? 0.9 : 0.65), lineWidth: 4)
                    .padding(2)
                    .opacity(isOn ? 1 : 0)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.35), value: isOn)
            .task(id: isOn) {
                guard isOn else { breathing = false; return }
                await Pulse.beat(times: 2, every: 0.6) { breathing = $0 }
            }
    }
}
