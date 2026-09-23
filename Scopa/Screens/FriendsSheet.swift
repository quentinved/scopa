import SwiftUI
import ScopaCore
import ScopaRelay

/// Every way to play a friend, near or far: a table opened under a code, an invitation by
/// name through Game Center, a table found nearby, or one phone passed round. The online
/// door is for strangers and has no codes on it.
struct FriendsSheet: View {
    let store: TableStore
    @Binding var path: [Page]

    @Environment(\.dismiss) private var dismiss
    @State private var detent = PresentationDetent.medium

    enum Page: Hashable {
        case thisPhone
        case joinByCode
    }

    /// The cloth in play, so the colour goes with the table.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        NavigationStack(path: $path) {
            // The root wears the play sheets' own headline; the pages pushed from it keep a
            // navigation bar, which is where their back button lives.
            SheetScaffold(title: "With friends", subtitle: "A code, a name, or one phone passed round.",
                          close: { dismiss() }) {
                VStack(alignment: .leading, spacing: 12) {
                    anywhereSection
                    sameRoomSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .animation(.spring(duration: 0.35, bounce: 0.15), value: store.isBrowsing)
                .animation(.easeInOut(duration: 0.2), value: store.nearby)
                .animation(.easeInOut(duration: 0.2), value: store.onlineStatus)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self, destination: destination)
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .onAppear { if !path.isEmpty { detent = .large } }
        .onChange(of: path) { _, path in if !path.isEmpty { detent = .large } }
    }

    @ViewBuilder private func destination(_ page: Page) -> some View {
        switch page {
        case .thisPhone:
            OnThisPhonePage(you: store.playerName, knowsTieRules: store.knowsTieRules) { table in
                store.playOnThisDevice(seats: table.seats, teams: table.teams, turnClock: table.clock,
                                       targetScore: table.target, primiera: table.primiera, ties: table.ties)
            }
        case .joinByCode:
            JoinTablePage(store: store)
        }
    }

    @ViewBuilder private var anywhereSection: some View {
        Caption(text: "Anywhere in the world")
        SheetChoice(symbol: "paperplane.fill", tint: Palette.terracotta,
                    title: "Open a table", detail: "Get a code and a link to send a friend") {
            store.openRoom()
        }
        NavigationLink(value: Page.joinByCode) {
            SheetChoiceLabel(symbol: "character.cursor.ibeam", tint: Palette.gold,
                             title: "Join with a code", detail: "Four letters, or the link they sent")
        }
        .buttonStyle(.plain)
        // Game Center's own sheet: no code to agree on, but both phones need Game Center.
        SheetChoice(symbol: "person.2.fill", tint: felt.accent,
                    title: "Invite Game Center friends", detail: "Ask them by name; no code to send") {
            store.inviteFriends(players: GameConfiguration.playerRange.upperBound)
        }
        if let status = store.onlineStatus {
            OnlineProgressLine(store: store, status: status, waiting: "Waiting for your friend")
                .transition(.opacity)
        }
        SheetNote("Opening a table gives you four letters and a link. Send it however you like — the table waits until they arrive, however long that takes, and nobody has to sign in to anything. Inviting by name instead needs Game Center on both phones.")
    }

    @ViewBuilder private var sameRoomSection: some View {
        Caption(text: "In the same room")
            .padding(.top, 10)
        SheetChoice(symbol: "antenna.radiowaves.left.and.right", tint: Palette.steel,
                    title: "Host a table", detail: "Open one here; friends nearby join it") {
            store.host()
        }
        SheetChoice(symbol: "magnifyingglass", tint: Palette.gold,
                    title: "Join a table", detail: "Find one a friend has opened nearby",
                    isSelected: store.isBrowsing) {
            if store.isBrowsing { store.stopBrowsing() } else { store.browse(); detent = .large }
        }
        if store.isBrowsing {
            nearby
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        NavigationLink(value: Page.thisPhone) {
            SheetChoiceLabel(symbol: "iphone.gen3", tint: felt.accent,
                             title: "Pass the phone", detail: "Friends and bots take turns on this one")
        }
        .buttonStyle(.plain)
        SheetNote("Nearby tables need both phones on the same Wi-Fi, or Bluetooth on.")
            .padding(.top, 4)
    }

    private var nearby: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.nearby.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.onTableSoft)
                    Text("Looking for tables nearby…")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.onTableSoft)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(store.nearby) { table in
                    Button { store.join(table) } label: {
                        NearbyRow(table: table, isJoining: store.joining?.id == table.id)
                    }
                    .buttonStyle(.plain)
                    // One invitation at a time.
                    .disabled(store.joining != nil)
                }
                .animation(.easeInOut(duration: 0.2), value: store.joining)
            }
        }
    }
}

/// The other end of an invitation: four letters typed in, or the link pasted whole.
///
/// The code is checked with the relay before matchmaking starts, so a misheard letter is
/// answered straight away rather than by a spinner that never stops.
private struct JoinTablePage: View {
    let store: TableStore

    @State private var typed = ""
    @FocusState private var isTyping: Bool

    private var isBusy: Bool { store.onlineStatus != nil }
    /// What was typed, read as a code: the four letters out of a link, or out of a code
    /// written down with a space in the middle.
    private var code: String {
        if let url = URL(string: typed.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil, let inside = TableStore.code(inside: url) {
            return inside
        }
        return Relay.tidy(typed)
    }

    private var isReady: Bool { Relay.isCode(code) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Caption(text: "The code")
                    codeField
                    SheetNote("Your friend gets these when they open a table. Pasting the whole link works too.", size: 13)
                }
                if let status = store.onlineStatus {
                    OnlineProgressLine(store: store, status: status, waiting: "Sitting down at \(code)")
                        .transition(.opacity)
                }
            }
            .padding(20)
        }
        .softScrollEdge(.top)
        .safeAreaInset(edge: .bottom) { sitDownButton }
        .background(TableGround())
        .navigationTitle("Join a table")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: store.onlineStatus)
        .onAppear { isTyping = true }
    }

    /// Big and spaced out, so a code held up across the room can be checked letter by letter.
    private var codeField: some View {
        TextField("ABCD", text: $typed)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
            .submitLabel(.go)
            .focused($isTyping)
            .onSubmit { sitDown() }
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .kerning(8)
            .foregroundStyle(isReady ? Palette.goldLight : Palette.onTable)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 18)
            .glassPanel(radius: GlassRadius.control)
            .disabled(isBusy)
            .animation(.easeInOut(duration: 0.2), value: isReady)
    }

    /// The filled style does not dim on its own.
    private var sitDownButton: some View {
        Button(isBusy ? "Sitting down…" : "Sit down") { sitDown() }
            .buttonStyle(FilledButtonStyle())
            .disabled(isBusy || !isReady)
            .opacity(isReady ? 1 : 0.5)
            .animation(.easeInOut(duration: 0.15), value: isReady)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    private func sitDown() {
        guard !isBusy, isReady else { return }
        store.joinRoom(code: code)
    }
}

private struct NearbyRow: View {
    let table: NearbyTable
    var isJoining = false

    /// The cloth in play, so the colour goes with the table.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        HStack(spacing: 12) {
            SeatBadge(name: table.hostName, tint: felt.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(table.hostName)'s table")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text(isJoining ? "Asking for a seat…" : "\(table.seated) of \(table.capacity) seated")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
            }
            Spacer()
            if isJoining {
                ProgressView().tint(Palette.onTableSoft)
            } else {
                Image(systemName: "chevron.right").foregroundStyle(Palette.onTableSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(radius: GlassRadius.control, interactive: true)
    }
}
