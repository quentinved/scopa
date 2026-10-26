import SwiftUI

/// One prize: the thing itself, its name, where it shows, and the button that puts it there.
struct PrizeTile<Art: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let metal: LeagueMetal
    /// The button's word. Nil hides it.
    let action: LocalizedStringKey?
    /// Said in place of the button once it is done.
    let done: LocalizedStringKey?
    let perform: () -> Void
    @ViewBuilder var art: Art

    @Environment(\.tableFelt) private var felt

    var body: some View {
        VStack(spacing: 8) {
            art.frame(height: 66)
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.onTable)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.onTableSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(felt.shade(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(metal.base.opacity(0.5), lineWidth: 1)
                }
        }
    }

    @ViewBuilder private var footer: some View {
        if let action {
            Button(action: perform) {
                Text(action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(Palette.terracotta) }
            }
            .buttonStyle(.plain)
        } else if let done {
            Label { Text(done) } icon: { Image(systemName: "checkmark") }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(metal.light)
                .padding(.vertical, 7)
        }
    }
}

/// The padlock on a prize not won yet.
struct LockGlyph: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Palette.cream)
            .padding(5)
            .background(Palette.ink.opacity(0.75), in: Circle())
    }
}

/// Wedges of light radiating from the centre.
struct LightRays: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.16
        let outer = min(rect.width, rect.height) * 0.5
        let half = .pi / Double(count) * 0.36
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            path.move(to: CGPoint(x: centre.x + cos(angle - half) * inner, y: centre.y + sin(angle - half) * inner))
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
            path.addLine(to: CGPoint(x: centre.x + cos(angle + half) * inner, y: centre.y + sin(angle + half) * inner))
            path.closeSubpath()
        }
        return path
    }
}
