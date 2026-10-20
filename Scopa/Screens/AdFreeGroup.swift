import SwiftUI

/// The no-ads purchase in the settings: a row that opens its sheet, and the restore line
/// the App Store asks every non-consumable to offer.
struct AdFreeGroup: View {
    let pass: AdFreePass

    @State private var showsSheet = false
    @State private var showsPatron = false

    var body: some View {
        SettingsGroup(caption: "Ads", footnote: Self.footnote(for: pass.state)) {
            if pass.isOwned {
                owned
            } else {
                offer
                Rule()
                SettingsRow(symbol: "arrow.clockwise", tint: Palette.steel, title: "Restore purchases",
                            detail: "Bought it on another device? Bring it here") {
                    Task { await pass.restore() }
                }
                .disabled(pass.state == .restoring)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: pass.isOwned)
        .sheet(isPresented: $showsSheet) { AdFreeSheet(pass: pass).coversBanner(carries: false) }
        .fullScreenCover(isPresented: $showsPatron) { PatronSheet() }
    }

    private var offer: some View {
        Button { showsSheet = true } label: {
            HStack(spacing: 12) {
                SymbolCoin(symbol: "rectangle.slash.fill", tint: Palette.terracotta, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scopa without ads")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    Text("No banner and no ad between games. The videos that pay denari stay, for when you want them.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                AdFreePriceTag(pass: pass)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The patron's crest where the price would be, and the gold page behind a tap.
    private var owned: some View {
        Button { showsPatron = true } label: {
            HStack(spacing: 12) {
                PatronCrest(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scopa without ads")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                    Text("Yours, and thank you. No banner, no ad between games.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.onTableSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// What the last attempt came to, when it is worth a line. Shared with the sheet.
    static func footnote(for state: AdFreePass.State) -> LocalizedStringKey? {
        switch state {
        case .pending: "Waiting for approval. The ads go as soon as it comes."
        case .failed: "The App Store could not finish that. Try again in a moment."
        case .nothingToRestore: "There is nothing to restore on this Apple account."
        case .idle, .buying, .restoring: nil
        }
    }
}
