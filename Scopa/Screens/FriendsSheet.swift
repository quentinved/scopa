import SwiftUI
import ScopaCore
import ScopaRelay

/// Every way to play a friend, near or far, laid out by who does what: one of you opens a
/// table, the others join it, by code from anywhere or over the same Wi-Fi. Or one phone
/// passed round. The online door is for strangers and has no codes on it.
///
/// It used to be split by distance — anywhere, then the same room — which put "open" and
/// "host" side by side (both "Ouvrir une table" in French) and left whoever hosted nearby
/// waiting for an invitation that never comes: the host does not invite, the others join.
struct FriendsSheet: View {
    let store: TableStore
    @Binding var path: [Page]

    @Environment(\.dismiss) private var dismiss
    @State private var detent = PresentationDetent.large

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
            SheetScaffold(title: "With friends", subtitle: "One of you opens a table, the others join it.",
                          close: { dismiss() }) {
                VStack(alignment: .leading, spacing: 12) {
                    openSection
                    joinSection
                    phoneSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .animation(.spring(duration: 0.35, bounce: 0.15), value: store.isBrowsing)
                .animation(.easeInOut(duration: 0.2), value: store.nearby)
                .animation(.easeInOut(duration: 0.2), value: store.unreachedTable)
                .animation(.easeInOut(duration: 0.2), value: store.onlineStatus)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self, destination: destination)
        }
        .presentationDetents([.medium, .large], selection: $detent)
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

    /// The two ways to be the one others join: a code that reaches anywhere, or a table put
    /// up over the Wi-Fi in the room. Game Center by name is the third, kept quiet.
    @ViewBuilder private var openSection: some View {
        Caption(text: "Open a table")
        TilePair {
            Button { store.openRoom() } label: {
                FriendsTile(symbol: "paperplane.fill", tint: Palette.terracotta,
                            title: "With a code", detail: "Friends join from anywhere")
            }
        } trailing: {
            Button { store.host() } label: {
                FriendsTile(symbol: "antenna.radiowaves.left.and.right", tint: Palette.steel,
                            title: "Nearby", detail: "Same Wi-Fi, no code to send")
            }
        }
        if let status = store.onlineStatus {
            OnlineProgressLine(store: store, status: status, waiting: "Waiting for your friend")
                .transition(.opacity)
        }
        // Game Center's own sheet: no code to agree on, but both phones need Game Center.
        Button {
            store.inviteFriends(players: GameConfiguration.playerRange.upperBound)
        } label: {
            Label("Or invite Game Center friends by name", systemImage: "person.2.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.onTableSoft)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The same two ways, from the other side: the code they were sent, or the table they
    /// put up nearby.
    @ViewBuilder private var joinSection: some View {
        Caption(text: "Join a friend's table")
            .padding(.top, 10)
        TilePair {
            NavigationLink(value: Page.joinByCode) {
                FriendsTile(symbol: "character.cursor.ibeam", tint: Palette.gold,
                            title: "With a code", detail: "The four letters they got")
            }
        } trailing: {
            Button {
                if store.isBrowsing { store.stopBrowsing() } else { store.browse() }
            } label: {
                FriendsTile(symbol: "magnifyingglass", tint: Palette.steel,
                            title: "Nearby", detail: store.isBrowsing ? "Looking. Tap to stop" : "When they chose Nearby",
                            isSelected: store.isBrowsing)
            }
        }
        if store.isBrowsing {
            nearby
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder private var phoneSection: some View {
        Caption(text: "On this phone")
            .padding(.top, 10)
        NavigationLink(value: Page.thisPhone) {
            SheetChoiceLabel(symbol: "iphone.gen3", tint: felt.accent,
                             title: "Pass the phone", detail: "Friends and bots take turns on this one")
        }
        .buttonStyle(.plain)
    }

    private var nearby: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let table = store.unreachedTable {
                UnreachedTableNote(table: table)
                    .transition(.opacity)
            }
            if store.nearby.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.onTableSoft)
                    Text("Looking for tables nearby…")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.onTableSoft)
                }
                .padding(.vertical, 4)
                SheetNote("Your friend opens a table with Nearby first. Both phones need to be on the same Wi-Fi.")
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
        .padding(.leading, 4)
    }
}

/// Two tiles side by side at the height of the taller one, so a pair whose lines wrap
/// differently still reads as a pair.
private struct TilePair<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading
            trailing
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Half a row: one way in, a symbol over its name and what it means.
private struct FriendsTile: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SymbolCoin(symbol: symbol, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.cream : Palette.onTable)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Palette.cream.opacity(0.85) : Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .glassPanel(radius: GlassRadius.control,
                    tint: isSelected ? Palette.terracotta.opacity(0.75) : nil, interactive: true)
        .contentShape(.rect(cornerRadius: GlassRadius.control))
    }
}

/// Said where the tap was, after a nearby table failed to answer. The usual cause is the
/// two phones on different networks, which a code gets round.
private struct UnreachedTableNote: View {
    let table: NearbyTable

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.goldLight)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(table.hostName)'s table did not answer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text("Nearby tables need both phones on the same Wi-Fi. On another network or on mobile data, ask \(table.hostName) to open a table with a code instead.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control, tint: Palette.terracotta.opacity(0.25))
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
