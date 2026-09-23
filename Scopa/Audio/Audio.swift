import AVFoundation
import Observation

/// The only thing in the app that makes a noise.
///
/// A small mixing desk: two decks for the music, so one loop can be faded into the
/// next, and a pool of voices for everything else. It is built at launch but not
/// started until the first sound, so a silent session never claims the hardware.
///
/// A singleton, because sounds are fired from views eight levels deep and the state
/// held here is two switches that belong to the phone rather than to a game.
///
/// The session is `.playback` with `.mixWithOthers`: the game is still heard with the
/// ring switch off, the way a music app is, and other apps' audio keeps playing under it.
/// `.ambient` would be the politer default, but a card game whose table has gone quiet
/// reads as broken rather than as considerate.
@MainActor
@Observable
final class Audio {
    static let shared = Audio()

    /// Whether music plays at all. One switch for the whole app.
    var isMusicOn: Bool {
        didSet {
            UserDefaults.standard.set(isMusicOn, forKey: Self.musicKey)
            if isMusicOn { resume(wanted) } else { silenceMusic() }
        }
    }

    /// Whether sound effects play: the cards, the coins and the interface.
    var areSoundsOn: Bool {
        didSet { UserDefaults.standard.set(areSoundsOn, forKey: Self.soundsKey) }
    }

    private static let musicKey = "musicOn"
    private static let soundsKey = "soundsOn"
    /// Enough voices that a deal, nine cards inside a second, never cuts itself off.
    private static let closeVoices = 10
    private static let wideVoices = 3

    @ObservationIgnored private let engine = AVAudioEngine()
    /// The music bus. Its level is what ducking moves.
    @ObservationIgnored private let band = AVAudioMixerNode()
    /// The bus for everything that is not music.
    @ObservationIgnored private let felt = AVAudioMixerNode()
    /// Two decks, so a loop can be faded out under the one replacing it.
    @ObservationIgnored private var decks: [AVAudioPlayerNode] = []
    @ObservationIgnored private var live = 0
    /// Mono and stereo voices are separate pools: a player node plays only the format
    /// it was connected with.
    @ObservationIgnored private var mono: [AVAudioPlayerNode] = []
    @ObservationIgnored private var wide: [AVAudioPlayerNode] = []
    @ObservationIgnored private var nextMono = 0
    @ObservationIgnored private var nextWide = 0

    @ObservationIgnored private var loaded: [String: AVAudioPCMBuffer] = [:]
    /// Names missing from the bundle, so an unrecorded sound is looked for once.
    @ObservationIgnored private var absent: Set<String> = []
    /// What should be playing. Differs from `sounding` when music is off, the app is
    /// backgrounded, or another app holds the audio.
    @ObservationIgnored private var wanted: Track?
    @ObservationIgnored private var sounding: Track?
    @ObservationIgnored private var running = false
    @ObservationIgnored private var away = false
    @ObservationIgnored private var fading: Task<Void, Never>?
    @ObservationIgnored private var ducking: Task<Void, Never>?
    /// When the turn last came round to this player, measured by `nudge()`.
    @ObservationIgnored private var lastTurn = ContinuousClock.now - .seconds(60)

    private init() {
        let defaults = UserDefaults.standard
        // Both default to on for a player who has never touched them.
        isMusicOn = defaults.object(forKey: Self.musicKey) as? Bool ?? true
        areSoundsOn = defaults.object(forKey: Self.soundsKey) as? Bool ?? true
        build()
        watchForInterruptions()
    }

    /// Reads both switches again, after `AccountSync` has merged them with the player's
    /// other device. Assigning is enough: `isMusicOn`'s own `didSet` starts or silences the
    /// loop, so the table goes quiet or comes back without anything else being told.
    func readStoredAgain() {
        let defaults = UserDefaults.standard
        isMusicOn = defaults.object(forKey: Self.musicKey) as? Bool ?? true
        areSoundsOn = defaults.object(forKey: Self.soundsKey) as? Bool ?? true
    }

    // MARK: The desk

    private func build() {
        guard let mono1 = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let stereo = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        else { return }
        for bus in [band, felt] {
            engine.attach(bus)
            engine.connect(bus, to: engine.mainMixerNode, format: stereo)
        }
        decks = (0..<2).map { _ in AVAudioPlayerNode() }
        for deck in decks {
            engine.attach(deck)
            engine.connect(deck, to: band, format: stereo)
            deck.volume = 0
        }
        mono = Self.pool(Self.closeVoices, into: felt, as: mono1, on: engine)
        wide = Self.pool(Self.wideVoices, into: felt, as: stereo, on: engine)
    }

    private static func pool(_ count: Int, into bus: AVAudioMixerNode, as format: AVAudioFormat,
                             on engine: AVAudioEngine) -> [AVAudioPlayerNode] {
        (0..<count).map { _ in
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: bus, format: format)
            return node
        }
    }

    /// Starts the engine at the first sound, off the main thread.
    ///
    /// Claiming the session takes a hundred milliseconds or more. On the main actor that
    /// was a visible hitch as the lobby came up, so callers await this instead and the
    /// first sound lands a beat late.
    private func wake() async {
        guard !running, !away else { return }
        if waking == nil {
            let desk = Desk(engine: engine)
            waking = Task { [weak self] in
                let started = await Task.detached(priority: .userInitiated) { desk.start() }.value
                guard let self else { return }
                // Backgrounded while the hardware was coming up: leave it asleep.
                running = started && !away
                if running == false, started { desk.engine.pause() }
                waking = nil
            }
        }
        await waking?.value
    }

    @ObservationIgnored private var waking: Task<Void, Never>?

    /// The engine handed to a background thread for the one slow call. Nothing else touches
    /// it until `start()` returns.
    ///
    /// `nonisolated` so `start()` runs off the main actor. Without it the struct inherits
    /// this class's isolation and the detached task becomes a cross-actor hop.
    nonisolated private struct Desk: @unchecked Sendable {
        let engine: AVAudioEngine

        func start() -> Bool {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            engine.prepare()
            return (try? engine.start()) != nil
        }
    }

    // MARK: Sounds

    /// Plays one sound. Does nothing if sounds are off or the file is not in the bundle.
    func play(_ sound: Sound, gain: Float = 1) {
        guard areSoundsOn else { return }
        guard let buffer = pick(sound) else {
            if let understudy = sound.standIn { play(understudy, gain: gain) }
            return
        }
        guard running else {
            // The engine is still coming up, so the sound waits rather than the caller.
            Task { [weak self] in
                await self?.wake()
                self?.schedule(buffer, as: sound, gain: gain)
            }
            return
        }
        schedule(buffer, as: sound, gain: gain)
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, as sound: Sound, gain: Float) {
        guard running, let voice = voice(channels: buffer.format.channelCount) else { return }
        voice.volume = sound.level * gain
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { voice.play() }
        if let duck = sound.duck { step(back: duck) }
    }

    /// Chimes for the player's turn, but only after a six second wait, so a fast
    /// two-handed game does not chime every few seconds.
    func nudge() {
        let now = ContinuousClock.now
        defer { lastTurn = now }
        guard now - lastTurn > .seconds(6) else { return }
        play(.turn)
    }

    /// Plays a sound after a delay, so a consequence is heard behind its cause rather
    /// than on top of it.
    func play(_ sound: Sound, gain: Float = 1, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.play(sound, gain: gain)
        }
    }

    private func pick(_ sound: Sound) -> AVAudioPCMBuffer? {
        let takes = sound.takes.compactMap(buffer(named:))
        return takes.randomElement()
    }

    /// Round robin over the pool. When every voice is busy the oldest is interrupted.
    private func voice(channels: AVAudioChannelCount) -> AVAudioPlayerNode? {
        if channels == 1 {
            guard !mono.isEmpty else { return nil }
            defer { nextMono = (nextMono + 1) % mono.count }
            return mono[nextMono]
        }
        guard !wide.isEmpty else { return nil }
        defer { nextWide = (nextWide + 1) % wide.count }
        return wide[nextWide]
    }

    // MARK: Music

    /// Sets the loop that should be playing, or `nil` for silence. Asking for the track
    /// already on is free, so screens can call this on every appearance.
    func music(_ track: Track?) {
        guard wanted != track else { return }
        wanted = track
        resume(track)
    }

    private func resume(_ track: Track?) {
        guard let track, isMusicOn, !away else { return silenceMusic() }
        guard sounding != track else { return }
        // Another app is already playing, so only the sound effects go over it.
        guard !AVAudioSession.sharedInstance().isOtherAudioPlaying else { return }
        // Claimed here rather than in `begin`, which first awaits a twenty-second file.
        // Two screens asking inside that wait would otherwise start the loop twice.
        sounding = track
        Task { await begin(track) }
    }

    private func begin(_ track: Track) async {
        guard let buffer = await load(track.rawValue), wanted == track else {
            return giveUp(on: track)
        }
        await wake()
        guard running, wanted == track, decks.count == 2 else { return giveUp(on: track) }
        let leaving = decks[live]
        live = (live + 1) % decks.count
        let arriving = decks[live]
        arriving.stop()
        arriving.volume = 0
        loop(buffer, on: arriving)
        arriving.play()
        fading?.cancel()
        fading = Task {
            async let up: Void = ramp(arriving, to: track.level, over: 1.4)
            async let down: Void = ramp(leaving, to: 0, over: 1.4)
            _ = await (up, down)
            guard !Task.isCancelled else { return }
            leaving.stop()
        }
    }

    /// `.loops` on a buffer is AVFoundation's only gapless loop, which is why tracks ship
    /// as whole decoded buffers.
    ///
    /// Kept synchronous and out of `begin`: inside an `async` function the compiler picks
    /// `scheduleBuffer`'s async overload, which resumes when the buffer ends, and a looping
    /// buffer never ends.
    private func loop(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    /// Releases the claim `resume` made on a loop that never started, so asking again
    /// is not mistaken for asking for what is already playing.
    private func giveUp(on track: Track) {
        if sounding == track { sounding = nil }
    }

    private func silenceMusic() {
        fading?.cancel()
        sounding = nil
        let decks = self.decks
        fading = Task {
            await withTaskGroup { group in
                for deck in decks where deck.isPlaying {
                    group.addTask { await self.ramp(deck, to: 0, over: 0.6) }
                }
            }
            guard !Task.isCancelled else { return }
            for deck in decks { deck.stop() }
        }
    }

    /// Dips the music for a moment so a sound can land on top of it.
    private func step(back duck: Sound.Duck) {
        ducking?.cancel()
        ducking = Task {
            await ramp(band, to: duck.depth, over: 0.14)
            try? await Task.sleep(for: .seconds(duck.hold))
            guard !Task.isCancelled else { return }
            await ramp(band, to: 1, over: 1.1)
        }
    }

    /// Fades a volume by hand, since AVFoundation has no ramp. Fifty steps a second is
    /// smooth enough to have no stairs in it.
    private func ramp(_ node: some AVAudioMixing, to target: Float, over duration: Double) async {
        let steps = max(Int(duration / 0.02), 1)
        let from = node.volume
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            node.volume = from + (target - from) * Float(step) / Float(steps)
            try? await Task.sleep(for: .seconds(0.02))
        }
        node.volume = target
    }

    // MARK: Coming and going

    /// The app was backgrounded. Everything stops and the session is released so other
    /// audio can resume.
    func pause() {
        away = true
        fading?.cancel()
        ducking?.cancel()
        band.volume = 1
        for deck in decks { deck.stop(); deck.volume = 0 }
        sounding = nil
        if running { engine.pause() }
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The app came back to the foreground.
    func resume() {
        away = false
        resume(wanted)
    }

    private func watchForInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                // A phone call takes the session and hands it back. Without the second
                // half the music never returns.
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    Audio.shared.pause()
                } else {
                    Audio.shared.resume()
                }
            }
        }
    }

    // MARK: Files

    /// Reads every sound into memory off the main thread, one after another.
    ///
    /// Loading on first use puts the read in the same frame as the card that asked for
    /// it, and loading on the main actor stalls the lobby coming up.
    func warmUp() {
        Task { [weak self] in
            for sound in Sound.allCases {
                for name in sound.takes {
                    guard let self else { return }
                    _ = await load(name)
                }
            }
        }
    }

    private func buffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = loaded[name] { return cached }
        guard !absent.contains(name) else { return nil }
        guard let delivered = Self.read(name) else {
            absent.insert(name)
            return nil
        }
        loaded[name] = delivered.buffer
        return delivered.buffer
    }

    private func load(_ name: String) async -> AVAudioPCMBuffer? {
        if let cached = loaded[name] { return cached }
        guard !absent.contains(name) else { return nil }
        let delivered = await Task.detached(priority: .userInitiated) { Audio.read(name) }.value
        guard let delivered else {
            absent.insert(name)
            return nil
        }
        loaded[name] = delivered.buffer
        return delivered.buffer
    }

    /// A buffer built on one thread and handed over once, never written afterwards.
    private struct Delivery: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
    }

    /// Decodes off the main actor. A twenty-second loop decoded there shows as a stutter
    /// on the way to the table.
    private nonisolated static func read(_ name: String) -> Delivery? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
              let file = try? AVAudioFile(forReading: url),
              file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil
        else { return nil }
        return Delivery(buffer: buffer)
    }
}
