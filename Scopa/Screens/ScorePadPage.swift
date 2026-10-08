import SwiftUI
import ScopaCore

/// The score of a game played with a real deck, for a table with no paper on it. The pad is
/// kept on the phone, so a game left for dinner is still there after.
struct ScorePadPage: View {
    let you: String
    @State private var pad: ScorePad? = DebugLaunch.scorePadSample ?? ScorePad.saved()

    var body: some View {
        Group {
            if let board = Binding($pad) {
                ScorePadBoard(pad: board) { pad = nil }
            } else {
                ScorePadSetup(you: you) { pad = $0 }
            }
        }
        .background(TableGround())
        .navigationTitle("Score pad")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pad) { _, pad in ScorePad.keep(pad) }
    }
}

extension ScorePad {
    private static let key = "scorePad"

    static func saved() -> ScorePad? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ScorePad.self, from: data)
    }

    /// Writes the pad down, or throws it away when there is none.
    static func keep(_ pad: ScorePad?) {
        guard let pad, let data = try? JSONEncoder().encode(pad) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Who is playing and to how many, before the first hand.
private struct ScorePadSetup: View {
    let you: String
    var start: (ScorePad) -> Void

    @State private var names: [String] = []
    @State private var target = 11

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sides
                HStack {
                    Caption(text: "Play to")
                    Spacer()
                    ScoreStepper(value: target) { target = $0 }
                }
            }
            .padding(20)
        }
        .softScrollEdge(.top)
        .safeAreaInset(edge: .bottom) {
            Button("Start counting") { start(ScorePad(sides: trimmed, target: target)) }
                .buttonStyle(FilledButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .onAppear { if names.isEmpty { names = [you, ""] } }
    }

    /// Each name as typed, or "Player 2" where nobody typed one.
    private var trimmed: [String] {
        names.enumerated().map { seat, name in
            let name = name.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? String(localized: "Player \(seat + 1)") : name
        }
    }

    private var sides: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Who is playing")
            ForEach(names.indices, id: \.self) { seat in
                HStack(spacing: 12) {
                    SeatBadge(name: trimmed[seat], tint: Palette.seat(seat), size: 34)
                    TextField("", text: $names[seat],
                              prompt: Text("Player \(seat + 1)").foregroundStyle(Palette.onTableSoft))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.onTable)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassPanel(radius: GlassRadius.control)
            }
            addAndRemove
            SheetNote("Playing in teams? Put both names on one line.", size: 13)
        }
    }

    private var addAndRemove: some View {
        HStack(spacing: 10) {
            Button { names.append("") } label: { Label("Add a seat", systemImage: "plus") }
                .disabled(names.count >= ScorePad.sideRange.upperBound)
            Button { names.removeLast() } label: { Label("Remove", systemImage: "minus") }
                .disabled(names.count <= ScorePad.sideRange.lowerBound)
            Spacer(minLength: 0)
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Palette.terracotta)
        .padding(.top, 2)
    }
}
