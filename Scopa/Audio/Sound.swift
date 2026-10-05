import Foundation

/// What the game says out loud at each moment, and how loudly. One vocabulary of
/// moments, like `Haptic`, so a capture sounds the same whichever screen fired it.
///
/// The whole set follows one rule: a card is paper, a point is metal, the interface
/// is wood. Nothing beeps.
enum Sound: String, CaseIterable {
    /// A card picked up out of the hand.
    case pick
    /// Your own card landing on the cloth.
    case play
    /// Your capture, sliding in.
    case take
    /// A big capture: three cards or more, with a drum under it.
    case sweep
    /// Somebody else's cards moving, heard from across the table.
    case theirs
    /// Three more each, off the top of the deck.
    case deal
    /// The seven of coins changing hands, yours or theirs.
    case settebello
    /// A sweep of the table.
    case scopa
    // The bought cheers, played in place of `scopa` for your own sweeps. See `Cheer`.
    case cheerCampana
    case cheerFesta
    case cheerFuochi
    case cheerOro
    /// Your turn.
    case turn
    /// The turn clock in its last seconds.
    case clock
    /// A move the rules will not take.
    case refused
    /// Something to read has appeared.
    case notice
    /// Anything touched.
    case tap
    /// Anything switched from one state to another.
    case toggle
    /// The hand is over and the counting is about to start.
    case roundOver
    /// One line of the summary landing.
    case step
    /// The name at the end of it.
    case reveal
    /// A denaro into the purse.
    case denaro
    /// The shop till.
    case purchase
    /// The game won.
    case victory
    /// The game lost.
    case defeat

    /// The recordings this moment can use, without extension. More than one means the
    /// game picks at random, so the sounds fired on every touch have three takes each.
    var takes: [String] {
        switch self {
        case .pick, .play, .take, .theirs: (1...3).map { "sfx_\(rawValue)_\($0)" }
        case .roundOver: ["sfx_roundover"]
        // `cheerCampana` is `sfx_cheer_campana`: one underscore rather than a camel hump,
        // because the forge names its files the way Python names its functions.
        case .cheerCampana: ["sfx_cheer_campana"]
        case .cheerFesta: ["sfx_cheer_festa"]
        case .cheerFuochi: ["sfx_cheer_fuochi"]
        case .cheerOro: ["sfx_cheer_oro"]
        default: ["sfx_\(rawValue)"]
        }
    }

    /// What stands in when nothing in `takes` is in the bundle.
    ///
    /// The scopa falls back to the sweep, which is a safety net rather than a real case:
    /// `sfx_scopa.caf` does ship. A bought cheer falls back to the scopa, which is not —
    /// a build that drops one of those recordings still announces the sweep.
    var standIn: Sound? {
        switch self {
        case .scopa: .sweep
        case .cheerCampana, .cheerFesta, .cheerFuochi, .cheerOro: .scopa
        default: nil
        }
    }

    /// Trim, for balancing two sounds without re-rendering either. The absolute level is
    /// set when the sound is synthesised.
    var level: Float {
        switch self {
        case .pick: 0.7
        case .theirs, .clock, .tap: 0.8
        case .settebello, .victory: 1.0
        default: 0.9
        }
    }

    /// How far the music dips for this sound, and how long it stays down. Only the few
    /// moments worth interrupting a track for: ducking every card would pump the music.
    var duck: Duck? {
        switch self {
        case .settebello: Duck(depth: 0.34, hold: 1.4)
        // Each hold is that recording's own length, since the hold is counted from when
        // the sound starts: a cheer whose last coin lands under a track already on its
        // way back up is a cheer that was cut off. Re-check them when a sound changes length.
        case .scopa: Duck(depth: 0.28, hold: 1.6)
        case .cheerCampana: Duck(depth: 0.24, hold: 2.3)
        case .cheerFuochi: Duck(depth: 0.2, hold: 2.3)
        case .cheerOro: Duck(depth: 0.16, hold: 3.2)
        case .cheerFesta: Duck(depth: 0.26, hold: 1.9)
        case .victory, .defeat: Duck(depth: 0.16, hold: 3.0)
        case .roundOver, .reveal: Duck(depth: 0.42, hold: 1.4)
        case .purchase: Duck(depth: 0.5, hold: 1.0)
        case .sweep: Duck(depth: 0.6, hold: 0.7)
        default: nil
        }
    }

    struct Duck {
        /// What fraction of its volume the music keeps.
        let depth: Float
        /// Seconds held down before it climbs back.
        let hold: Double
    }
}

/// The loops, all in A minor or its relative major so anything the game plays over them fits.
enum Track: String, CaseIterable {
    /// The lobby: a full band, with a tune.
    case lungomare = "music_lungomare"
    /// The table: no melody and a slower count, so it stays behind the thinking.
    case tavolo = "music_tavolo"
    // The songs the shop sells for the table. See `Song`.
    case pomeriggio = "music_pomeriggio"
    case piazza = "music_piazza"
    case barcarola = "music_barcarola"
    case serenata = "music_serenata"
    case tarantella = "music_tarantella"
    case mergellina = "music_mergellina"

    /// Set against the table bed's loudness, so changing song does not change the room.
    var level: Float {
        switch self {
        case .lungomare: 0.5
        case .tavolo: 0.3
        case .pomeriggio, .serenata, .mergellina: 0.29
        case .piazza, .barcarola: 0.27
        case .tarantella: 0.34
        }
    }
}
