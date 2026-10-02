import SwiftUI
import ScopaRewards

/// The shop's last row, where a coupon from the house or a friend's code is typed.
///
/// Modest on purpose, at the foot of the shelves after how denari are earned: a code is a
/// present somebody was handed, not something the shop is selling.
struct PromoCodeRow: View {
    let purse: PurseStore
    let book: AlbumBook

    @State private var isOpen = false

    var body: some View {
        Button { isOpen = true } label: {
            HStack(spacing: 12) {
                SymbolCoin(symbol: "ticket.fill", tint: Palette.terracotta, size: 32)
                Text("Have a code?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.onTable)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassPanel(radius: GlassRadius.control, interactive: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isOpen) { PromoCodePanel(purse: purse, book: book) }
        .task { await openForScreenshot() }
    }

    /// `-promoCode`: a beat after the shop has finished sliding in, or the sheet is refused.
    private func openForScreenshot() async {
        #if DEBUG
        guard let shown = DebugLaunch.promoCode, shown != "row" else { return }
        try? await Task.sleep(for: .seconds(1))
        isOpen = true
        #endif
    }
}

/// One field and one button. Answers in place: what arrived, gilded, or one line on why
/// nothing did.
struct PromoCodePanel: View {
    let purse: PurseStore
    let book: AlbumBook

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isSending = false
    @State private var refusal: LocalizedStringKey?
    @State private var receipt: PromoCode.Receipt?
    @FocusState private var isTyping: Bool

    var body: some View {
        Group {
            if let receipt { thanks(receipt) } else { asking }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { TableGround() }
        .presentationDetents(receipt == nil ? [.height(360)] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: receipt)
        .sensoryFeedback(.success, trigger: receipt)
        .sound(.purchase, trigger: receipt)
        .onAppear(perform: pretendForScreenshot)
    }

    private var asking: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Have a code?")
                    .font(.display(30))
                    .foregroundStyle(Palette.onTable)
                Text("From the house, or from the friend who brought you. Each code counts once per player.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            field
            Button("Use", action: redeem)
                .buttonStyle(FilledButtonStyle())
                .disabled(isBlank || isSending)
                .opacity(isBlank ? 0.5 : 1)
            if let refusal {
                Text(refusal)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .onAppear { isTyping = true }
    }

    private var field: some View {
        HStack(spacing: 12) {
            SymbolCoin(symbol: "ticket.fill", tint: Palette.terracotta, size: 32)
            TextField("", text: $code, prompt: Text("Code").foregroundStyle(Palette.onTableSoft))
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.onTable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isTyping)
                .onSubmit(redeem)
                .onChange(of: code) { _, _ in refusal = nil }
            if isSending {
                ProgressView().controlSize(.small).tint(Palette.onTableSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(radius: GlassRadius.control)
    }

    private func thanks(_ receipt: PromoCode.Receipt) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                if let friend = receipt.friend { Text("Grazie, \(friend)!") } else { Text("Grazie!") }
            }
            .font(.display(30))
            .foregroundStyle(Palette.onTable)
            ScrollView {
                PromoReceipt(receipt: receipt)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Done") { dismiss() }
                .buttonStyle(FilledButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var isBlank: Bool { code.trimmingCharacters(in: .whitespaces).isEmpty }

    private func redeem() {
        guard !isBlank, !isSending else { return }
        isSending = true
        Task {
            let answer = await PromoCode.use(code, purse: purse, book: book)
            isSending = false
            switch answer {
            case .received(let received):
                isTyping = false
                receipt = received
            case .refused(let reason):
                Audio.shared.play(.refused)
                withAnimation(.snappy(duration: 0.2)) { refusal = reason }
            }
        }
    }

    /// `-promoCode paid` shows what a generous coupon looks like, without paying it.
    private func pretendForScreenshot() {
        #if DEBUG
        guard DebugLaunch.promoCode == "paid" else { return }
        let felt = Cosmetics.item(for: TableFelt.notte).map { [$0] } ?? []
        receipt = PromoCode.Receipt(denari: 500, tiers: [.velluto, .reliquia], items: felt)
        #endif
    }
}

/// Everything a code handed over, one line each, gilded once as it arrives.
private struct PromoReceipt: View {
    let receipt: PromoCode.Receipt

    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if receipt.denari.isCredit {
                line { DenariMark(size: 28) } label: { Text("\(receipt.denari.coins) denari are in your purse.") }
            }
            ForEach(Array(receipt.tiers.enumerated()), id: \.offset) { _, tier in
                line { PackArt(tier: tier, width: 22) } label: {
                    Text(tier.shelf == .shop ? "A \(tier.title) pack is waiting in the shop"
                                             : "A \(tier.title) pack is waiting in the album")
                }
            }
            ForEach(receipt.items) { item in
                line { SymbolCoin(symbol: "sparkles", tint: Rarities.tint(item.grade), size: 28) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.title)
                        Text(Cosmetics.title(of: item.kind))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.cream.opacity(0.75))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: GlassRadius.control, tint: felt.light.opacity(0.6))
        .overlay { Gilding() }
    }

    private func line(@ViewBuilder _ mark: () -> some View, @ViewBuilder label: () -> some View) -> some View {
        HStack(spacing: 12) {
            mark().frame(width: 32)
            label()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
