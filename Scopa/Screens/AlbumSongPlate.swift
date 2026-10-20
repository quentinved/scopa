import SwiftUI

/// An album's song shown as the thing itself: a Vietri plate, tin white with a cobalt rim,
/// that plays the song at a tap and stops at the next. A prize nobody can buy can at least
/// be heard, long before it is won.
struct SongPlate: View {
    let song: Song
    var size: CGFloat = 92

    private let audio = Audio.shared
    private var playing: Bool { audio.auditioning == song.track }

    var body: some View {
        Button { audio.audition(playing ? nil : song.track) } label: { plate }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? Text("Stop") : Text("Listen"))
            .sensoryFeedback(.selection, trigger: playing)
            // Leaving the page puts the room's own music back.
            .onDisappear { if playing { audio.audition(nil) } }
    }

    private var plate: some View {
        ZStack {
            Circle().fill(MaiolicaPaint.tin)
            MaiolicaCrackle(cell: size * 0.12, seed: 7)
                .stroke(MaiolicaPaint.manganese.opacity(0.1), lineWidth: 0.4)
                .clipShape(Circle())
            Circle().strokeBorder(MaiolicaPaint.cobalt, lineWidth: size * 0.075)
            MaiolicaRingDots(count: 16, radius: 0.36, dot: 0.04)
                .fill(MaiolicaPaint.saffron)
            // The grooves, so the plate reads as something that plays.
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(MaiolicaPaint.cobaltWash.opacity(0.55), lineWidth: 0.8)
                    .padding(size * (0.2 + 0.055 * CGFloat(ring)))
            }
            Circle()
                .fill(playing ? MaiolicaPaint.cobalt : MaiolicaPaint.saffron)
                .frame(width: size * 0.34, height: size * 0.34)
            Image(systemName: playing ? "stop.fill" : "play.fill")
                .font(.system(size: size * 0.13, weight: .heavy))
                .foregroundStyle(playing ? MaiolicaPaint.saffron : MaiolicaPaint.cobaltDeep)
                .offset(x: playing ? 0 : size * 0.012)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        .animation(.easeOut(duration: 0.2), value: playing)
    }
}
