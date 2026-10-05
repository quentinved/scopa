import SwiftUI

/// A question asked before something is done: drawn by the app rather than by iOS, so it is
/// the same card, in the middle of the screen, on every iPhone and iPad. The system's sheet
/// sits at the foot of a phone and floats beside the button on an iPad.
struct Confirmation: Identifiable {
    let id = UUID()
    var title: Text
    var message: Text?
    var actions: [Action]

    struct Action: Identifiable {
        enum Role {
            /// The thing the card is asking about, in gold.
            case primary
            /// Something that cannot be taken back, in terracotta.
            case destructive
            /// One of several choices, none of them the obvious one.
            case plain
            /// Leaves things as they were. Also what a tap beside the card does.
            case cancel
        }

        let id = UUID()
        let title: Text
        var role: Role = .primary
        var run: () -> Void = {}
    }

    init(_ title: Text, message: Text? = nil, actions: [Action]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

extension View {
    /// Shows the card while `isPresented` is true. `make` is read once, as it opens, so what
    /// it says holds still while it closes even if the thing it asked about has gone.
    func confirmation(isPresented: Binding<Bool>, _ make: @escaping () -> Confirmation?) -> some View {
        modifier(ConfirmationPresenter(isPresented: isPresented, make: make))
    }
}

/// Hangs the card on a full-screen cover with no background and no slide, so it lies over
/// navigation bars and sheets alike. The chosen action runs once the cover is gone, so one
/// that presents something of its own — a pack being opened — is not refused for it.
private struct ConfirmationPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let make: () -> Confirmation?

    @Environment(\.tableFelt) private var felt
    @State private var shown: Confirmation?
    @State private var chosen: Confirmation.Action?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented, initial: true) { _, now in now ? open() : shut() }
            .fullScreenCover(item: $shown, onDismiss: finish) { confirmation in
                ConfirmationCard(confirmation: confirmation) { action in
                    chosen = action
                    shut()
                }
                .environment(\.tableFelt, felt)
                .presentationBackground(.clear)
            }
    }

    private func open() {
        guard shown == nil else { return }
        guard let made = make() else { isPresented = false; return }
        withoutSlide { shown = made }
    }

    private func shut() {
        guard shown != nil else { return }
        withoutSlide { shown = nil }
    }

    private func finish() {
        let action = chosen
        chosen = nil
        isPresented = false
        action?.run()
    }

    private func withoutSlide(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

/// The card and the shade behind it. It brings itself in and takes itself out; the cover
/// underneath only appears and disappears.
private struct ConfirmationCard: View {
    let confirmation: Confirmation
    let close: (Confirmation.Action?) -> Void

    @Environment(\.tableFelt) private var felt
    @State private var isIn = false
    @State private var isLeaving = false

    private var cancel: Confirmation.Action? { confirmation.actions.first { $0.role == .cancel } }

    var body: some View {
        ZStack {
            Color.black.opacity(isIn ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { leave(with: cancel) }
                .accessibilityHidden(true)
            if isIn {
                card.transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.34, bounce: 0.22)) { isIn = true } }
        .sensoryFeedback(.impact(weight: .light), trigger: isIn) { _, now in now }
    }

    private var card: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                confirmation.title
                    .font(.display(26))
                    .foregroundStyle(Palette.onTable)
                confirmation.message?
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.onTableSoft)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(confirmation.actions) { action in button(action) }
            }
        }
        .padding(22)
        .frame(maxWidth: 360)
        // Darker than a panel on the table: whatever is under the shade must not read through.
        .glassPanel(tint: felt.shade(0.85))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { leave(with: cancel) }
    }

    @ViewBuilder
    private func button(_ action: Confirmation.Action) -> some View {
        let tap = { leave(with: action) }
        switch action.role {
        case .primary:
            Button(action: tap) { action.title }
                .buttonStyle(FilledButtonStyle(tint: Palette.gold, foreground: Palette.ink, minHeight: 50))
        case .destructive:
            Button(action: tap) { action.title }
                .buttonStyle(FilledButtonStyle(minHeight: 50))
        case .plain:
            Button(action: tap) { action.title }
                .buttonStyle(OutlineButtonStyle(minHeight: 50))
        case .cancel:
            Button(action: tap) { action.title }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
    }

    /// Takes the card out, then hands the choice back. A second tap while it goes is nothing.
    private func leave(with action: Confirmation.Action?) {
        guard !isLeaving else { return }
        isLeaving = true
        withAnimation(.easeOut(duration: 0.16)) {
            isIn = false
        } completion: {
            close(action)
        }
    }
}
