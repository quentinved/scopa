import SwiftUI

/// News that arrives while the player is looking at something else: a pack earned, a level
/// reached. Told once, at the top of whatever screen is up, and gone on its own.
///
/// Unlike `NoticeBar`, which says what the table just did, a toast says what the player
/// *got*, so it carries a picture and outlives the screen it was posted from — a pack earned
/// on the last summary is still being announced as the lobby slides in.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let tint: Color
    /// Already in the interface's language: the poster knows the locale, the toaster does not.
    let title: String
    var detail: String? = nil
}

/// The queue of toasts. One is shown at a time, so two pieces of news that land together
/// are read one after the other rather than stacked into a list nobody reads.
@MainActor @Observable
final class Toaster {
    private(set) var current: Toast?
    private var queue: [Toast] = []

    func post(_ toast: Toast) {
        if current == nil { current = toast } else { queue.append(toast) }
    }

    /// The toast on screen has had its time, or was tapped away.
    func dismiss(_ toast: Toast) {
        guard current == toast else { return }
        current = queue.isEmpty ? nil : queue.removeFirst()
    }
}

/// The toast on screen, dropped in from the top.
struct ToastBar: View {
    let toaster: Toaster

    var body: some View {
        Group {
            if let toast = toaster.current { card(toast) }
        }
        .animation(.spring(duration: 0.4, bounce: 0.25), value: toaster.current)
        .sensoryFeedback(trigger: toaster.current) { _, new in new == nil ? nil : .success }
        .sound(trigger: toaster.current) { _, new in new == nil ? nil : .notice }
    }

    private func card(_ toast: Toast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .frame(width: 34, height: 34)
                .background(toast.tint, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: toast.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                if let detail = toast.detail {
                    Text(verbatim: detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.cream.opacity(0.75))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 9)
        .glassCapsule(tint: Palette.ink.opacity(0.85))
        .padding(.horizontal, 16)
        // Hard under the status bar rather than dropped as far as the notices: news lands
        // on the last summary, and any lower it sits on the headline saying who won.
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .id(toast.id)
        .onTapGesture { toaster.dismiss(toast) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .task(id: toast.id) {
            AccessibilityNotification.Announcement(
                [toast.title, toast.detail].compactMap { $0 }.joined(separator: ". ")
            ).post()
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            toaster.dismiss(toast)
        }
    }
}
