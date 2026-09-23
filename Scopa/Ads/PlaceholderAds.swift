import SwiftUI

/// Stands in for a real network so the pacing can be judged on a simulator with no account
/// and no connection. Launch with `-placeholderAds` to use it instead of AdMob.
@MainActor
@Observable
final class PlaceholderAds: AdsGateway {
    /// The full screen ad currently up, if any. Read by `overlayBody`.
    private(set) var showing: FullScreen?
    private(set) var isLoaded = false

    /// Resumes the caller once the player closes the ad.
    @ObservationIgnored private var dismissal: CheckedContinuation<Void, Never>?

    /// The two full screen ads, which say different things.
    enum FullScreen { case interstitial, rewarded }

    func begin() {}

    /// The height of the adaptive banner a phone gets from most networks.
    var bannerHeight: CGFloat { 50 }

    func bannerBody() -> AnyView {
        AnyView(PlaceholderBanner())
    }

    func overlayBody() -> AnyView {
        AnyView(
            Group {
                if let showing {
                    PlaceholderInterstitial(kind: showing) { [weak self] in self?.close() }
                        .transition(.opacity)
                }
            }
        )
    }

    func preloadInterstitial() {
        isLoaded = true
    }

    @discardableResult
    func showInterstitial() async -> Bool {
        guard isLoaded else { return false }
        isLoaded = false
        await present(.interstitial)
        return true
    }

    var isRewardedReady: Bool { true }
    func preloadRewarded() {}

    func showRewarded() async -> Bool {
        await present(.rewarded)
        return true
    }

    private func present(_ kind: FullScreen) async {
        await withCheckedContinuation { continuation in
            dismissal = continuation
            withAnimation(.easeOut(duration: 0.25)) { showing = kind }
        }
    }

    private func close() {
        guard showing != nil else { return }
        withAnimation(.easeIn(duration: 0.2)) { showing = nil }
        dismissal?.resume()
        dismissal = nil
    }
}

/// The stand-in banner strip.
private struct PlaceholderBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("AD")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.steel)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 3))
            Text("Banner slot")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.cream.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        // Runs to the bottom edge, so no band of table is left under it.
        .background(Palette.steel.ignoresSafeArea(edges: .bottom))
        .accessibilityHidden(true)
    }
}

/// A stand-in full screen ad, with the same few seconds before it can be closed.
private struct PlaceholderInterstitial: View {
    let kind: PlaceholderAds.FullScreen
    let close: () -> Void

    /// How long a network typically makes you wait before the cross appears.
    private static let hold = 5

    @State private var remaining = PlaceholderInterstitial.hold

    var body: some View {
        ZStack {
            Palette.steel.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Advertisement")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Palette.cream.opacity(0.5))
                Text(kind == .rewarded ? "Watched for denari" : "Full screen slot")
                    .font(.display(46))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.cream)
                Text(kind == .rewarded
                     ? "This one was asked for, so it pays.\nClose it and the denari are in the purse."
                     : "This is where the network's ad plays.\nSweep it away with a coup de balai.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.cream.opacity(0.6))
            }
            .padding(32)
        }
        .overlay(alignment: .topTrailing) { dismissControl }
        .task { await countDown() }
    }

    private func countDown() async {
        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            remaining -= 1
        }
    }

    @ViewBuilder private var dismissControl: some View {
        Group {
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.5))
            } else {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.cream)
                }
                .accessibilityLabel("Close the ad")
            }
        }
        .frame(width: 34, height: 34)
        .background(Palette.ink.opacity(0.5), in: Circle())
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}
