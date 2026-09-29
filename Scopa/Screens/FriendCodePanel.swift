import SwiftUI
import ScopaRewards

/// Where a new player types the code the friend who brought them handed out. One code per
/// player, paid once: a pack left waiting in the album, denari, or both.
struct FriendCodePanel: View {
    let book: AlbumBook
    let purse: PurseStore

    @State private var isOpen = false
    @State private var code = ""
    @State private var isSending = false
    @State private var refusal: LocalizedStringKey?
    /// Whose code this device used, read once and then kept in step with the answer.
    @State private var owner = FriendCode.usedOwner
    /// What was just paid, for the thank-you line. Nil on a later visit, or when nothing was owed.
    @State private var paid: FriendCode.Gift?
    @FocusState private var isTyping: Bool

    @Environment(\.tableFelt) private var felt

    var body: some View {
        Group {
            if let owner { thanks(owner) } else { invitation }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: owner)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isOpen)
        .sensoryFeedback(.success, trigger: paid)
        .sound(.purchase, trigger: paid)
    }

    private var invitation: some View {
        VStack(spacing: 0) {
            Button {
                isOpen.toggle()
                if isOpen { isTyping = true }
            } label: {
                HStack(spacing: 12) {
                    SymbolCoin(symbol: "gift.fill", tint: Palette.terracotta, size: 32)
                    Text("A friend's code")
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
            Text("Did a friend bring you to the table? Enter their code and the house sends you a gift. One code per player.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                field
                if isSending {
                    ProgressView().controlSize(.small).tint(Palette.onTableSoft)
                } else {
                    Button("Use", action: redeem)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isBlank ? Palette.onTableSoft : Palette.terracotta)
                        .disabled(isBlank)
                }
            }
            if let refusal {
                Text(refusal)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }

    private var field: some View {
        TextField("", text: $code, prompt: Text("Code").foregroundStyle(Palette.onTableSoft))
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Palette.onTable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isTyping)
            .onSubmit(redeem)
            .onChange(of: code) { _, _ in refusal = nil }
    }

    private func thanks(_ owner: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.cream)
            VStack(alignment: .leading, spacing: 3) {
                Text(owner.isEmpty ? "Grazie!" : "Grazie, \(owner)!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                Text(thanksDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassPanel(radius: GlassRadius.control, tint: felt.light.opacity(0.6))
    }

    /// What was just handed over, or, on any later visit, that the one code is spent.
    private var thanksDetail: LocalizedStringKey {
        guard let paid else { return "Your friend's code is used. There is one per player." }
        switch (paid.tier, paid.denari.isCredit) {
        case (let tier?, true): return "A \(tier.title) pack is waiting in the album, and \(paid.denari.coins) denari are in your purse."
        case (let tier?, false): return "A \(tier.title) pack is waiting in the album"
        default: return "\(paid.denari.coins) denari are in your purse."
        }
    }

    private var isBlank: Bool { code.trimmingCharacters(in: .whitespaces).isEmpty }

    private func redeem() {
        guard !isBlank, !isSending else { return }
        isSending = true
        Task {
            let outcome = await FriendCode.redeem(code)
            isSending = false
            await settle(outcome)
        }
    }

    private func settle(_ outcome: FriendCode.Outcome) async {
        switch outcome {
        case .gift(let gift):
            if gift.fresh {
                await pay(gift)
                paid = gift
            }
            remember(gift.owner)
        case .usedAnother(let owner): remember(owner)
        case .unknown: refuse("No code by that name.")
        case .notSignedIn: refuse("Sign in to Game Center first, so your code counts once.")
        case .unreachable: refuse("The code could not be checked. Try again in a moment.")
        }
    }

    private func pay(_ gift: FriendCode.Gift) async {
        if let tier = gift.tier { book.give(tier) }
        await purse.awardFriendCode(gift.denari)
    }

    private func remember(_ owner: String) {
        FriendCode.usedOwner = owner
        isTyping = false
        self.owner = owner
    }

    private func refuse(_ reason: LocalizedStringKey) {
        withAnimation(.snappy(duration: 0.2)) { refusal = reason }
    }
}
