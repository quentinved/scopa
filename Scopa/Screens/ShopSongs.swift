import ScopaRewards
import SwiftUI

/// The songs for the table: each with its grade, a button to hear it first, and the usual
/// tap to buy or to switch to it.
struct ShopSongs: View {
    let purse: PurseStore
    let counter: ShopCounter
    private let audio = Audio.shared

    var body: some View {
        ShopSection(title: "Songs", subtitle: "Music for your games. The menus keep their own tune.",
                    anchor: "songs") {
            VStack(alignment: .leading, spacing: 10) {
                ShelfHeading(.song)
                ForEach(Song.allCases) { song in
                    SongRow(song: song, item: Cosmetics.item(for: song),
                            owned: purse.owns(song),
                            equipped: audio.tableSong == song,
                            playing: audio.auditioning == song.track,
                            affordable: counter.affordable(Cosmetics.item(for: song)),
                            justBought: counter.justBought(Cosmetics.item(for: song)),
                            pick: { pick(song) }, listen: { listen(to: song) })
                }
                if !audio.isMusicOn { musicIsOff }
            }
            .reactsToPick(audio.tableSong)
        }
        .onDisappear { audio.audition(nil) }
    }

    /// Said where it matters: a song bought with the music off would never be heard.
    private var musicIsOff: some View {
        HStack(spacing: 10) {
            Text("Music is switched off, so games are quiet. Previews still play.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.onTableSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Turn on") { audio.isMusicOn = true }
                .font(.system(size: 12, weight: .semibold))
                .tint(Palette.goldLight)
        }
    }

    private func listen(to song: Song) {
        audio.audition(audio.auditioning == song.track ? nil : song.track)
    }

    private func pick(_ song: Song) {
        counter.buyIfNeeded(Cosmetics.item(for: song)) { audio.tableSong = song }
    }
}

/// One song: a play button, its name and grade, what it sounds like, and where it stands.
private struct SongRow: View {
    let song: Song
    let item: ShopItem?
    let owned: Bool
    let equipped: Bool
    let playing: Bool
    let affordable: Bool
    let justBought: Bool
    let pick: () -> Void
    let listen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: listen) { playButton }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? Text("Stop") : Text("Listen"))
            Button(action: pick) { details }
                .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .glass(equipped ? .riviera(tint: Palette.terracotta.opacity(0.75), interactive: true) : .identity,
               in: .rect(cornerRadius: GlassRadius.control))
        .overlay { border }
        .overlay { if song.grade == .leggendario { legendaryLight } }
        .overlay { if justBought { Gilding().id(justBought) } }
    }

    private var playButton: some View {
        Image(systemName: playing ? "stop.fill" : "play.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(playing ? Palette.ink : Palette.goldLight)
            .frame(width: 44, height: 44)
            .background(Circle().fill(playing ? AnyShapeStyle(Palette.goldLight) : AnyShapeStyle(.black.opacity(0.25))))
            .overlay { Circle().strokeBorder(Palette.gold.opacity(0.5)) }
            .contentShape(Circle())
    }

    private var details: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(verbatim: song.title)
                        .font(.display(19))
                        .foregroundStyle(equipped ? Palette.cream : Palette.onTable)
                    RarityTag(song.grade, size: 8.5)
                }
                Text(song.explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(equipped ? Palette.cream.opacity(0.85) : Palette.onTableSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            state
        }
        .contentShape(.rect)
    }

    @ViewBuilder private var state: some View {
        if equipped {
            Label("In use", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.cream)
        } else if owned {
            Label("Owned", systemImage: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.onTableSoft)
        } else if let item {
            DenariLabel(amount: item.price, size: 14,
                        tint: affordable ? Palette.goldLight : Palette.onTableSoft)
                .opacity(affordable ? 1 : 0.7)
        }
    }

    @ViewBuilder private var border: some View {
        if !equipped {
            RoundedRectangle(cornerRadius: GlassRadius.control)
                .strokeBorder(song.grade > .comune ? Rarities.sheen(song.grade)
                                                   : AnyShapeStyle(Palette.onTableSoft.opacity(0.28)),
                              lineWidth: song.grade > .comune ? 1.5 : 1)
        }
    }

    /// The same corner of light a leggendario tile wears elsewhere in the shop.
    private var legendaryLight: some View {
        RoundedRectangle(cornerRadius: GlassRadius.control)
            .fill(RadialGradient(colors: [Palette.goldLight.opacity(0.22), .clear],
                                 center: .topTrailing, startRadius: 0, endRadius: 140))
            .allowsHitTesting(false)
    }
}
