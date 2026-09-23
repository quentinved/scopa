import SwiftUI
import ScopaCore
import ScopaGameCenter
import ScopaRewards

/// Everything the player can set: who they are, how the table treats them, what it sounds
/// like, and a door to the shop for what it looks like.
struct SettingsSheet: View {
    @Bindable var store: TableStore
    let ads: AdsStore
    let purse: PurseStore
    let reminders: Reminders
    let account: AccountSync

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var draft = ""
    /// Read when the page is built rather than watched: nothing can finish a game while
    /// the settings are open.
    private let record = Achievements.record
    private let level = Experience.level
    @State private var showsRules = false
    @State private var showsPostbox = false
    /// Opened by the row, and by `-album` on the way in.
    @State private var showsAlbum = DebugLaunch.showsAlbum
    @FocusState private var isTypingName: Bool
    @Environment(FriendsOnline.self) private var friendsOnline: FriendsOnline?

    /// The cloth under it, so the glass is tinted with the table's own shadow.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profile
                    albumGroup
                    markGroup
                    reminderGroup
                    if Ladder.isOn, let friendsOnline { friendsGroup(friendsOnline) }
                    tableGroup
                    soundGroup
                    lookGroup
                    gameCenterGroup
                    helpGroup
                    CoupDeBalai(ads: ads, store: store)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .softScrollEdge(.top)
            .scrollDismissesKeyboard(.interactively)
            .background(TableGround())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showsAlbum) {
                AlbumView(store: store, purse: purse)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitName()
                        dismiss()
                    }
                    .tint(Palette.goldLight)
                }
            }
        }
        .onAppear { draft = store.playerName }
        // Committed on focus loss too, so leaving by a swipe keeps the name.
        .onChange(of: isTypingName) { _, typing in if !typing { commitName() } }
        .sheet(isPresented: $showsRules) { RulesView() }
        .confirmationDialog("What would you like to tell us?", isPresented: $showsPostbox,
                            titleVisibility: .visible) {
            Button("Something is wrong") { write(.problem) }
            Button("I have an idea") { write(.idea) }
        }
    }

    // MARK: Groups

    /// The way into the album. A row rather than a door on the lobby: the lobby is four
    /// doors and nothing else on purpose, and this is a thing to look at between games
    /// rather than a way into one.
    private var albumGroup: some View {
        SettingsGroup(caption: "Your album") {
            SettingsRow(symbol: "square.grid.3x3.fill", tint: Palette.gold, title: "The album",
                        detail: albumDetail) { showsAlbum = true }
        }
    }

    private var waiting: Int { store.albumBook.waiting }

    /// What the row says it holds: what is waiting to be opened if anything is, and how
    /// far along the album is when nothing is.
    private var albumDetail: LocalizedStringKey {
        waiting > 0
            ? "^[\(waiting) pack](inflect: true) waiting to be opened"
            : "\(store.albumBook.album.found) of \(Album.size) cards found"
    }

    private var markGroup: some View {
        SettingsGroup(caption: "Your mark", footnote: "On your seat, and seen by everyone at the table. The rest are won at it.") {
            MarkPicker(name: store.playerName, mark: $store.seatMark,
                       progress: Achievements.markProgress(streak: store.dailyStreak,
                                                           suits: store.albumBook.album.completedSuits,
                                                           deck: store.albumBook.album.isComplete),
                       owned: Set(SeatMark.forSale.filter(purse.owns)), livery: store.livery)
        }
    }

    private var reminderGroup: some View {
        SettingsGroup(caption: "Today's deal",
                      footnote: reminders.isBlocked
                          ? "Notifications are off for Scopa in the iPhone's Settings."
                          : "A nudge at the hour you usually play and a last call in the evening, on the days you have not played yet.") {
            ReminderRow(reminders: reminders, book: store.dailyBook)
        }
    }

    private func friendsGroup(_ friends: FriendsOnline) -> some View {
        SettingsGroup(caption: "Friends", footnote: friendsFootnote(friends)) {
            FriendsOnlineRow(friends: friends, isSignedIn: store.isSignedIn)
        }
    }

    /// What the switch does, or why it cannot: it is only as good as Game Center lets it be.
    private func friendsFootnote(_ friends: FriendsOnline) -> LocalizedStringKey {
        if !store.isSignedIn { return "Needs Game Center, which is signed in to from the iPhone's Settings." }
        switch friends.access {
        case .denied: return "Scopa is not allowed to see your friends. Turn it on in the iPhone's Settings, under Game Center."
        case .restricted: return "Friend lists are turned off on this iPhone."
        case .granted, .notAsked:
            return "Your Game Center friends who play Scopa see when you are playing, and you see when they are. Turn it off and nobody sees you — and you see nobody."
        }
    }

    private var tableGroup: some View {
        SettingsGroup(caption: "At the table",
                      footnote: "Today's deal and the tables with denari on them are always played against the hard bot: everybody there faces the same one.") {
            AssistPicker(assist: $store.assist)
            Rule()
            BotPicker(level: $store.botLevel)
            Rule()
            LanguagePicker(language: $store.language)
        }
    }

    private var soundGroup: some View {
        SettingsGroup(caption: "Sound", footnote: "The ring switch silences the game whatever these say, and nothing here interrupts what the phone is already playing.") {
            AudioRows(audio: Audio.shared)
        }
    }

    private var lookGroup: some View {
        SettingsGroup(caption: "The look") {
            NavigationLink {
                ShopContent(store: store, purse: purse, ads: ads)
            } label: {
                LookRow(theme: store.cardTheme, felt: store.tableFelt)
            }
            .buttonStyle(.plain)
        }
    }

    private var gameCenterGroup: some View {
        SettingsGroup(caption: "Game Center",
                      footnote: "A ranked duo is played with a friend who also has Scopa.") {
            AccountRow(account: account)
            Rule()
            SettingsRow(symbol: "person.2.fill", tint: Palette.seat(2), title: "Your friends",
                        detail: "Add someone, or see who already plays") {
                store.showGameCenterFriends()
            }
        }
    }

    private var helpGroup: some View {
        SettingsGroup(caption: "Help") {
            SettingsRow(symbol: "book.pages", tint: Palette.gold, title: "How to play",
                        detail: "The deck, the takes, the scopa and the points") { showsRules = true }
            Rule()
            SettingsRow(symbol: "envelope.fill", tint: Palette.terracotta, title: "Write to us",
                        detail: "A problem, or an idea for the game") {
                showsPostbox = true
            }
            if ads.consent.offersPrivacyChoices {
                Rule()
                SettingsRow(symbol: "hand.raised.fill", tint: Palette.steel, title: "Your privacy choices",
                            detail: "What the ads on this device may use") {
                    Task { await ads.consent.presentPrivacyChoices() }
                }
            }
        }
    }

    /// Opens a mail draft with the subject and build filled in. A phone with no mail
    /// account gets the support page instead, which prints the same address.
    private func write(_ errand: Postbox.Errand) {
        guard let letter = Postbox.letter(about: errand, in: locale) else {
            openURL(Postbox.supportPage)
            return
        }
        openURL(letter) { opened in
            if !opened { openURL(Postbox.supportPage) }
        }
    }

    // MARK: Profile

    private var profile: some View {
        VStack(alignment: .leading, spacing: 14) {
            name
            Rectangle()
                .fill(Palette.onTableSoft.opacity(0.2))
                .frame(height: 1)
            levelRow
        }
        .padding(16)
        .glassPanel(radius: GlassRadius.panel)
    }

    private var name: some View {
        HStack(spacing: 14) {
            SeatBadge(name: draft.isEmpty ? store.playerName : draft, tint: Palette.seat(0), size: 58,
                      mark: store.seatMark, cornice: store.cornice, livery: store.livery)
                .animation(.snappy, value: draft)
            VStack(alignment: .leading, spacing: 2) {
                TextField("", text: $draft,
                          prompt: Text("Name").foregroundStyle(Palette.onTableSoft))
                    .textFieldStyle(.plain)
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                    .submitLabel(.done)
                    .focused($isTypingName)
                    .onSubmit(commitName)
                // What they have to show for it, once there is anything to show. Before
                // the first game the line says what the field is for instead: "0 won ·
                // 0 lost" is a worse welcome than no line at all, and the pencil beside
                // it is what says the name can be tapped.
                if record.hasPlayed {
                    Text("\(record.wins) won · \(record.losses) lost")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.onTableSoft)
                } else {
                    Text("Your name at the table")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
        .contentShape(.rect)
        .onTapGesture { isTypingName = true }
    }

    /// The slow number: how much has been played, ever.
    ///
    /// It sits under the name rather than out on the lobby on purpose. A league is worth
    /// announcing — it is this month, and it can go down. A level only ever goes up, which
    /// makes it something to look up rather than something to be told, and the lobby is
    /// already carrying a rosette, a head count, a streak and a week.
    private var levelRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Level \(level.number)")
                    .textCase(.uppercase)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
                // The bar says how far along; this says how far is left, which is the part
                // somebody deciding whether to play one more game actually wants.
                Text("\(level.toGo) XP to level \(level.number + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onTableSoft)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(felt.shade(0.5))
                    Capsule()
                        .fill(Palette.goldSheen)
                        .frame(width: max(geometry.size.width * level.fraction, level.progress > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Level \(level.number)"))
        .accessibilityValue(Text("\(level.toGo) XP to level \(level.number + 1)"))
    }

    private func commitName() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != store.playerName { store.playerName = trimmed }
    }
}

// MARK: - The furniture

/// A captioned glass panel holding a few rows, with an optional footnote.
struct SettingsGroup<Content: View>: View {
    let caption: LocalizedStringKey
    var footnote: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.onTableSoft)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .glassPanel(radius: GlassRadius.control)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A row that goes somewhere: a symbol, a title, a detail line and a chevron.
struct SettingsRow: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SymbolCoin(symbol: symbol, tint: tint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.onTableSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// What the account is doing, told as what it has done: who this device plays as, and when
/// it last met the player's other ones.
///
/// Neither a switch nor a door — there is nothing here to set. It is a row at all because a
/// player with a phone and an iPad otherwise has no way to tell whether the two are yet the
/// same player, and "your progress syncs" printed under a heading is a claim rather than an
/// answer. A name and a time are the answer.
private struct AccountRow: View {
    let account: AccountSync

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            SymbolCoin(symbol: "arrow.triangle.2.circlepath", tint: Palette.steel, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your account")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if account.isSyncing {
                ProgressView()
                    .controlSize(.small)
                    .tint(Palette.onTableSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// The most useful true thing, in order: what went wrong, that nobody is signed in, or
    /// who this is and when they were last met.
    private var detail: LocalizedStringKey {
        if let problem = account.problem { return problem }
        guard let name = GameCenter.localName else {
            return "Sign in to Game Center to play on all your devices"
        }
        guard let syncedAt = account.syncedAt else { return "\(name) · not synced yet" }
        // The game's own language rather than the phone's: this sheet may be being read in
        // Italian on a French phone, and "il y a 2 minutes" in the middle of it would jar.
        return "\(name) · synced \(syncedAt.formatted(.relative(presentation: .named).locale(locale)))"
    }
}

/// Music and sound effects, each with its own switch.
private struct AudioRows: View {
    @Bindable var audio: Audio

    /// The cloth in play, so the colour goes with the table.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 0) {
            toggle("Music", symbol: "music.note", isOn: $audio.isMusicOn)
            Rule()
            toggle("Cards and coins", symbol: "speaker.wave.2.fill", isOn: $audio.areSoundsOn)
        }
        .tint(Palette.terracotta)
        .sensoryFeedback(.selection, trigger: audio.isMusicOn)
        .sensoryFeedback(.selection, trigger: audio.areSoundsOn)
        .sound(.toggle, trigger: audio.areSoundsOn)
    }

    private func toggle(_ title: LocalizedStringKey, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                SymbolCoin(symbol: symbol, tint: felt.accent, size: 32)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// The switch for the daily reminder. Turning it on asks iOS for permission.
private struct ReminderRow: View {
    let reminders: Reminders
    let book: DailyDealBook

    var body: some View {
        Toggle(isOn: Binding(
            get: { reminders.isOn },
            set: { on in Task { if on { await reminders.turnOn(book) } else { reminders.turnOff() } } }
        )) {
            HStack(spacing: 12) {
                SymbolCoin(symbol: "bell.badge.fill", tint: Palette.gold, size: 32)
                Text("Remind me")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
            }
        }
        .tint(Palette.terracotta)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sensoryFeedback(.selection, trigger: reminders.isOn)
    }
}

/// The switch for friends online. Turning it on asks Game Center for the friend list, which
/// is the one place Scopa brings that prompt up for this.
private struct FriendsOnlineRow: View {
    let friends: FriendsOnline
    let isSignedIn: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        Toggle(isOn: Binding(
            get: { friends.isOn },
            set: { on in Task { if on { await friends.turnOn() } else { await friends.turnOff() } } }
        )) {
            HStack(spacing: 12) {
                SymbolCoin(symbol: "person.2.fill", tint: Palette.live, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Say when friends are playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    if friends.isOn && !friends.online.isEmpty {
                        Text(verbatim: friends.online.map(\.name).formatted(.list(type: .and).locale(locale)))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.onTableSoft)
                            .lineLimit(1)
                    }
                }
            }
        }
        .tint(Palette.terracotta)
        .disabled(!isSignedIn || friends.access == .denied || friends.access == .restricted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sensoryFeedback(.selection, trigger: friends.isOn)
    }
}

/// The deck and felt in use, small, and the way to the shop.
private struct LookRow: View {
    let theme: CardTheme
    let felt: TableFelt

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [felt.light, felt.base, felt.deep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 44)
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.gold.opacity(0.35)) }
                HStack(spacing: -10) {
                    CardView(card: Card(.knight, of: .coins), width: 22)
                    CardBack(width: 22).rotationEffect(.degrees(8))
                }
                .environment(\.cardTheme, theme)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Deck and table")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Text(verbatim: "\(theme.style.title) · \(theme.skin.title) · \(felt.title)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onTableSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Coup de balai

/// A passphrase that removes the ads for good. A soft gate for friends and family,
/// folded away until asked for.
private struct CoupDeBalai: View {
    let ads: AdsStore
    /// The same phrase also enables the house tie rule on tables this phone sets up.
    let store: TableStore

    @State private var isOpen = false
    @State private var phrase = ""
    @State private var refused = false
    @FocusState private var isTyping: Bool

    /// The cloth in play, so the colour goes with the table.
    @Environment(\.tableFelt) private var felt

    var body: some View {
        Group {
            if ads.adsAreOn { invitation } else { swept }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: ads.adsAreOn)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isOpen)
        .sensoryFeedback(.success, trigger: ads.adsAreOn)
        .sound(.purchase, trigger: ads.adsAreOn)
    }

    private var invitation: some View {
        VStack(spacing: 0) {
            Button {
                isOpen.toggle()
                if isOpen { isTyping = true }
            } label: {
                HStack(spacing: 12) {
                    BroomMark(size: 22, tint: Palette.goldLight)
                        .frame(width: 32, height: 32)
                    Text("Coup de balai")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.onTableSoft)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                form
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassPanel(radius: GlassRadius.control)
        .clipShape(.rect(cornerRadius: GlassRadius.control))
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rule()
            Text("Know the words? Say them and the ads are swept off the table for good.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                TextField("", text: $phrase,
                          prompt: Text("Passphrase").foregroundStyle(Palette.onTableSoft))
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.onTable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($isTyping)
                    .onSubmit(sweep)
                    .onChange(of: phrase) { _, _ in refused = false }
                Button("Balayer", action: sweep)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(phrase.isEmpty ? Palette.onTableSoft : Palette.terracotta)
                    .disabled(phrase.isEmpty)
            }
            if refused {
                Text("Ça ne balaie pas.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.terracotta)
                    .transition(.opacity)
            }
        }
    }

    private var swept: some View {
        HStack(spacing: 12) {
            BroomMark(size: 22, tint: Palette.cream)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tutto pulito!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                Text(store.knowsTieRules
                     ? "The table is swept. No more ads on this device — and the tables you set can share what you end level on."
                     : "The table is swept. No more ads on this device.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control, tint: felt.light.opacity(0.6))
    }

    private func sweep() {
        // Both are told even when the table is already swept, so the rule can still be taught.
        let swept = ads.coupDeBalai(phrase)
        let taught = store.hearTieRules(phrase)
        guard swept || taught else {
            withAnimation(.snappy(duration: 0.2)) { refused = true }
            return
        }
        isTyping = false
        phrase = ""
        refused = false
    }
}

#Preview {
    SettingsSheet(store: TableStore(), ads: AdsStore(), purse: PurseStore(), reminders: Reminders(),
                  account: AccountSync())
}
