"""Everything that happens once.

The rule the set is built on: a card is paper, a point is metal, the interface is
wood, and nothing beeps.

Loudness is set here rather than in the app, so the mix between two sounds is the
same on every device and the app has one volume to think about.
"""

import numpy as np

import dsp
import instruments as inst
from dsp import SR


def _finish(parts: list[tuple[float, np.ndarray]], duration: float, *, wet: float = 0.12,
            decay: float = 0.9, peak: float = 0.8, stereo: bool = False) -> np.ndarray:
    """Lay the parts out, put them in a small room, and set the peak. Even a card
    gets a little reverb: dry paper on a phone speaker sounds like a sample.
    """
    dry = dsp.silence(duration)
    for at, signal in parts:
        dsp.place(dry, signal, at)
    if wet > 0:
        space = dsp.room(dry * wet, decay=decay, damping=6000.0, predelay=0.008)
        out = np.stack([dry, dry]) + space if stereo else dry + space.mean(axis=0)
    else:
        out = np.stack([dry, dry]) if stereo else dry
    return dsp.trim(dsp.fade_out(dsp.saturate(out, 1.1), 0.03), peak)


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


# Sounds that fire on nearly every touch are rendered several times from different
# noise and the game picks between them, so a card never repeats itself exactly.
TAKES = 3


# MARK: Paper


def pick(seed: int = 0) -> np.ndarray:
    """A card lifted out of a hand. Barely there, since it fires on every tap."""
    rng = _rng(101 + seed)
    return _finish([(0.0, inst.flick(rng, level=0.5, decay=0.028, colour=4600.0))],
                   0.2, wet=0.06, peak=0.34)


def play(seed: int = 0) -> np.ndarray:
    """Your card going down on the cloth."""
    rng = _rng(202 + seed)
    return _finish([(0.0, inst.flick(rng, level=0.7, decay=0.05, colour=2800.0)),
                    (0.052, inst.land(rng, level=0.8))],
                   0.36, wet=0.1, peak=0.62)


def take(seed: int = 0) -> np.ndarray:
    """A capture: what you played and what it took, sliding in together."""
    rng = _rng(303 + seed)
    parts = [(0.0, inst.flick(rng, level=0.62, decay=0.05, colour=3000.0))]
    for i, at in enumerate((0.055, 0.108, 0.152)):
        parts.append((at, inst.flick(rng, level=0.52 - 0.08 * i, decay=0.045,
                                     colour=2600.0 + 400.0 * i)))
    parts.append((0.17, inst.land(rng, level=0.6, weight=0.8)))
    return _finish(parts, 0.55, wet=0.13, decay=1.0, peak=0.72)


def sweep() -> np.ndarray:
    """Three cards or more. The pile answers with a drum and a fifth rings over it."""
    rng = _rng(104)
    parts = [(0.0, inst.sweepnoise(rng, 0.26, 5200.0, 1400.0, level=0.34)),
             (0.05, inst.tom(52.0, 118.0, 0.5, level=0.4))]
    for i in range(5):
        parts.append((i * 0.048, inst.flick(rng, level=0.5 - 0.05 * i, decay=0.05,
                                            colour=3400.0 - 300.0 * i)))
    parts.append((0.22, inst.land(rng, level=0.7, weight=1.1)))
    parts.append((0.1, inst.vibes(69, 1.1, level=0.18)))
    parts.append((0.13, inst.vibes(76, 1.0, level=0.13)))
    return _finish(parts, 0.95, wet=0.2, decay=1.3, peak=0.86)


def scopa() -> np.ndarray:
    """The table swept clean: the loudest moment in the game, and the happiest.

    It is the only sound the band plays. The nylon guitar carrying the table music
    picks up on G and lands on C — the major chord inside the key the music is already
    in, so it brightens the room without arguing with it — while the table claps on the
    chord and again after it, and three glockenspiel notes climb over the top.

    It used to be the same guitar on A minor over a floor tom, in a long room. Played
    on its own that read as an omen rather than a win, which is not what anybody who
    has just swept the table wants to hear. Nothing in it now is under 90 Hz, the room
    closes quickly, and every chord in it is major.

    It stays the warmest of the loud sounds rather than the brightest: the settebello
    owns brightest, and the glockenspiel here is kept under the guitar for that reason.
    """
    rng = _rng(924)
    parts = _cards_leaving(rng, count=6, stride=0.04, colour=3600.0)
    # The pickup: an upstroke on G, light, a beat before the chord.
    parts.append((0.06, inst.strum([55, 59, 62, 67], 0.3, level=0.24, spread=0.010,
                                   down=False, rng=rng), -0.15))
    # The chord: C major, open, down across all six strings.
    parts.append((0.20, inst.strum([48, 52, 55, 60, 64, 67], 1.05, level=0.5,
                                   spread=0.014, rng=rng), -0.12))
    parts.append((0.20, inst.tom(92.0, 170.0, 0.22, level=0.16), 0.0))
    parts.append((0.20, inst.palmas(rng, hands=4, level=0.44), 0.2))
    parts.append((0.47, inst.palmas(rng, hands=4, level=0.3), 0.25))
    for i, note in enumerate((79, 84, 88)):
        parts.append((0.27 + i * 0.055, inst.handbell(dsp.midi_hz(note), 1.0, level=0.15 - 0.02 * i),
                      0.3 + 0.1 * i))
    return _stage(parts, 1.55, wet=0.18, decay=1.3, peak=0.88)


# MARK: Cheers
#
# Four alternatives to `scopa`, bought in the shop and played in its place when you are
# the one who swept. Each keeps the sweep itself — the cards leaving the cloth — because
# that part is the move and not a decoration; what changes is what the room does about it.
#
# All four are parties. They were once a tolling bell, a minor chord, a thunderstorm and
# a purse falling on a drum, and a player who had paid for one of them heard it as
# something going wrong. Everything here is in C major and nothing booms.


def cheer_campana() -> np.ndarray:
    """The bells rung for a wedding: the village hears about it.

    Eight handbells down the scale, the way a tower rings rounds, and then the four of
    the chord struck together to finish. Short tails, so it peals rather than tolls.
    """
    rng = _rng(313)
    parts = _cards_leaving(rng, count=5, stride=0.042, colour=3400.0)
    for i, note in enumerate((84, 83, 81, 79, 77, 76, 74, 72)):
        parts.append((0.05 + i * 0.085, inst.handbell(dsp.midi_hz(note), 1.2, level=0.36 - 0.012 * i),
                      0.55 if i % 2 else -0.55))
    for i, note in enumerate((72, 76, 79, 84)):
        parts.append((0.78 + i * 0.012, inst.handbell(dsp.midi_hz(note), 1.5, level=0.3), -0.3 + 0.2 * i))
    parts.append((0.78, inst.shaker(rng, level=0.2, decay=0.12), 0.0))
    return _stage(parts, 2.3, wet=0.22, decay=1.6, peak=0.86)


def cheer_festa() -> np.ndarray:
    """The village band strikes up: an accordion, a bass, a tambourine and the table
    clapping along.

    A run up into the chord, the chord on the beat with the bass under it, an answer on
    the off-beat, and the chord again, held, with the tambourine rolling under it:
    ta-da-da-daa.
    """
    rng = _rng(479)
    parts = _cards_leaving(rng, count=5, stride=0.038, colour=3600.0)
    for i, note in enumerate((67, 69, 71)):
        parts.append((0.04 + i * 0.055, _reed([note], 0.07, level=0.3), 0.1))
    beats = ((0.22, [60, 64, 67, 72], 48, 0.2), (0.46, [64, 67, 72], 43, 0.16),
             (0.70, [64, 67, 72, 76], 48, 0.95))
    for at, chord, root, hold in beats:
        parts.append((at, _reed(chord, hold, level=0.4), 0.1))
        parts.append((at, inst.upright(root, max(hold, 0.3), level=0.34, rng=rng), 0.0))
        parts.append((at, inst.palmas(rng, hands=3, level=0.3), 0.3))
        parts.append((at, inst.shaker(rng, level=0.3, decay=0.06), -0.35))
    # The roll under the held chord.
    for i in range(10):
        parts.append((0.76 + i * 0.034, inst.shaker(rng, level=0.2 - 0.014 * i, decay=0.04), -0.35))
    parts.append((0.74, inst.handbell(dsp.midi_hz(88), 1.0, level=0.1), 0.4))
    # Peaked lower than the others: a held reed is loud for its peak, and at 0.88 it
    # came out several decibels over every other cheer.
    return _stage(parts, 1.9, wet=0.18, decay=1.4, peak=0.74)


def cheer_fuochi() -> np.ndarray:
    """Fireworks over the square: three rockets up, and the sky full of glitter.

    Each rocket whistles up, opens with a pop, and hangs glitter across the stereo field
    as it comes down; a glockenspiel chord lights up with the first, which is what turns
    three bangs into a celebration. The pops are kept small — a shell's boom is the one
    part of a firework that frightens anybody, and on a phone speaker it would be the
    only part left.

    This used to be thunder, and was sold as the room going dark. It is still the same
    shelf and price, stored under its old name.
    """
    rng = _rng(827)
    parts = _cards_leaving(rng, count=5, stride=0.04, colour=3400.0)
    rockets = ((0.04, 0.42, 650.0, 1900.0, -0.45, 0.9), (0.30, 0.38, 720.0, 2250.0, 0.5, 0.9),
               (0.58, 0.36, 820.0, 2500.0, 0.0, 1.3))
    for at, rise, start, end, position, glitter in rockets:
        parts.append((at, inst.whistle(rng, rise, start, end, level=0.16), position))
        burst = at + rise
        parts.append((burst, inst.pop(rng, level=0.34), position))
        parts.append((burst + 0.02, inst.crackle(rng, glitter, sparks=90, level=0.26), 0.0))
    for i, note in enumerate((84, 88, 91)):
        parts.append((0.47 + i * 0.03, inst.handbell(dsp.midi_hz(note), 1.4, level=0.12), -0.3 + 0.3 * i))
    return _stage(parts, 2.3, wet=0.2, decay=1.8, peak=0.86)


def cheer_oro() -> np.ndarray:
    """The jackpot: a purse emptied across the table, and the room lit up by it.

    It opens on a till's ka-ching, a coin and two bells, and a glockenspiel runs up the
    chord while twenty coins pour out on a closing stride, each struck a little lower
    than the last so the pile goes away from you. A second, thinner spill follows for
    the ones that carried on across the cloth, and the whole chord rings out at the end
    with the last three coins still spinning down into it — everybody else has stopped
    clapping and there is still gold moving, which is what makes it the dear one.

    It used to open on a drum and a low bell and end on one bell alone; the drum and the
    lonely bell are gone.
    """
    rng = _rng(1051)
    parts = _cards_leaving(rng, count=5, stride=0.036, colour=4000.0)
    parts.append((0.02, inst.coin(rng, level=0.34, freq=3100.0), 0.0))
    parts.append((0.02, inst.handbell(dsp.midi_hz(88), 1.2, level=0.26), 0.1))
    parts.append((0.09, inst.handbell(dsp.midi_hz(96), 1.4, level=0.22), -0.1))

    at = 0.05
    for i in range(20):
        parts.append((at, inst.coin(rng, level=0.36 - 0.012 * i, freq=2900.0 - 70.0 * i),
                      float(np.sin(i * 1.7)) * 0.6))
        at += 0.062 * (0.94 ** i)
    for i, note in enumerate((72, 76, 79, 84, 88)):
        parts.append((0.14 + i * 0.075, inst.handbell(dsp.midi_hz(note), 1.3, level=0.2), -0.4 + 0.2 * i))
    parts.append((0.52, inst.land(rng, level=0.34, weight=0.6), 0.0))

    at = 0.86
    for i in range(9):
        parts.append((at, inst.coin(rng, level=0.22 - 0.016 * i, freq=2300.0 - 80.0 * i),
                      float(np.cos(i * 2.3)) * 0.7))
        at += 0.085 * (0.92 ** i)

    for i, note in enumerate((72, 76, 79, 84)):
        parts.append((1.3 + i * 0.02, inst.handbell(dsp.midi_hz(note), 1.9, level=0.16), -0.3 + 0.2 * i))
    parts.append((1.3, inst.vibes(84, 1.8, level=0.14), 0.0))
    for at, freq, level, position in ((1.52, 2600.0, 0.18, -0.4), (1.9, 2200.0, 0.14, 0.45),
                                      (2.26, 1900.0, 0.1, 0.0)):
        parts.append((at, inst.coin(rng, level=level, freq=freq), position))
    return _stage(parts, 3.2, wet=0.24, decay=2.0, peak=0.9)


def _cards_leaving(rng: np.random.Generator, count: int, stride: float,
                   colour: float) -> list[tuple[float, np.ndarray, float]]:
    """The sweep itself, which every scopa sound opens on: a hand across the felt and
    the cards going with it. Kept above 1800 Hz so it rustles rather than rumbles.
    """
    parts = [(0.0, inst.sweepnoise(rng, 0.26, 5200.0, 1800.0, level=0.3), 0.0)]
    for i in range(count):
        parts.append((i * stride, inst.flick(rng, level=0.42 - 0.045 * i, decay=0.05,
                                             colour=colour - 260.0 * i), -0.2 + 0.08 * i))
    parts.append((count * stride + 0.02, inst.land(rng, level=0.4, weight=0.7), 0.0))
    return parts


def _reed(notes: list[float], duration: float, level: float) -> np.ndarray:
    """An accordion chord with its bellows opened and closed, rather than switched."""
    tone = inst.accordion(notes, duration + 0.06, level=level)
    return tone * dsp.swell(len(tone), 0.012, duration * 0.6, duration * 0.4 + 0.06)


def _stage(parts: list[tuple[float, np.ndarray, float]], duration: float, *,
           wet: float = 0.18, decay: float = 1.4, peak: float = 0.88) -> np.ndarray:
    """`_finish` for the celebrations, where each part has its own place across the
    room, −1 left to +1 right. A stereo part keeps the image it came with.

    People clapping and fireworks are all over the place, and a party made of one voice
    copied into both ears sounds like a sample of one.
    """
    dry = np.zeros((2, dsp.seconds(duration)))
    send = dsp.silence(duration)
    for at, signal, position in parts:
        stereo = signal if signal.ndim > 1 else dsp.pan(signal, position) * np.sqrt(2.0)
        for channel in range(2):
            dsp.place(dry[channel], stereo[channel], at)
        dsp.place(send, stereo.mean(axis=0), at)
    space = dsp.room(send * wet, decay=decay, damping=6500.0, predelay=0.01)
    return dsp.trim(dsp.fade_out(dsp.saturate(dry + space, 1.1), 0.06), peak)


def theirs(seed: int = 0) -> np.ndarray:
    """Somebody else's cards, from across the table: darker and quieter than yours."""
    rng = _rng(505 + seed)
    parts = [(0.0, inst.flick(rng, level=0.4, decay=0.05, colour=2200.0)),
             (0.06, inst.flick(rng, level=0.3, decay=0.04, colour=2000.0)),
             (0.115, inst.land(rng, level=0.42, weight=0.7))]
    dry = _finish(parts, 0.42, wet=0.12, decay=1.0, peak=0.44)
    return dsp.lowpass(dry, 3200.0)


def deal() -> np.ndarray:
    """Three cards each, off the top of the deck, ending on the pack settling."""
    rng = _rng(106)
    parts = []
    at = 0.0
    for i in range(9):
        parts.append((at, inst.flick(rng, level=0.42 + 0.02 * i, decay=0.042,
                                     colour=3000.0 + rng.uniform(-500, 700))))
        at += 0.062 - 0.003 * i + rng.uniform(-0.006, 0.006)
    parts.append((at + 0.02, inst.land(rng, level=0.6, weight=0.9)))
    parts.append((0.0, inst.brush(rng, 0.55, level=0.1)))
    return _finish(parts, 0.95, wet=0.14, decay=1.1, peak=0.7)


def settebello() -> np.ndarray:
    """The seven of coins changing hands: the brightest sound in the set, three
    bells up an A major triad with a coin under them.
    """
    rng = _rng(107)
    parts = [(0.0, inst.coin(rng, level=0.35, freq=2600.0)),
             (0.0, inst.sweepnoise(rng, 0.5, 3000.0, 9000.0, level=0.12))]
    for i, freq in enumerate((880.0, 1108.7, 1318.5)):
        parts.append((i * 0.072, inst.bell(freq, 2.1 - 0.2 * i, level=0.5 - 0.09 * i)))
    parts.append((0.22, inst.vibes(88, 1.6, level=0.14)))
    return _finish(parts, 2.3, wet=0.34, decay=2.4, peak=0.9, stereo=True)


def rise() -> np.ndarray:
    """A good card about to turn over out of a pack: bells climbing the A major chord,
    closer and closer together, over a shimmer that brightens as they go. It stops on
    the top note, with nothing resolved, because the card turning over is the answer.
    """
    rng = _rng(131)
    parts = [(0.0, inst.sweepnoise(rng, 1.15, 1800.0, 8500.0, level=0.1), 0.0)]
    at, gap = 0.0, 0.2
    for i, note in enumerate((69, 73, 76, 81, 85, 88, 93, 97)):
        parts.append((at, inst.handbell(dsp.midi_hz(note), 0.7, level=0.08 + 0.016 * i),
                      -0.5 + 0.14 * i))
        at += gap
        gap *= 0.78
    parts.append((0.55, inst.crackle(rng, 0.6, sparks=26, level=0.1), 0.0))
    return _stage(parts, 1.5, wet=0.22, decay=1.4, peak=0.62)


def shine() -> np.ndarray:
    """A good card turned over: glitter thrown off it and the chord it climbed to, rung
    together. Bright and short, so the settebello's own bells can sit on top of it.
    """
    rng = _rng(137)
    parts = [(0.0, inst.crackle(rng, 1.0, sparks=60, level=0.2), 0.0),
             (0.0, inst.coin(rng, level=0.22, freq=3200.0), 0.0)]
    for i, note in enumerate((81, 85, 88, 93)):
        parts.append((i * 0.018, inst.handbell(dsp.midi_hz(note), 1.3, level=0.16), -0.3 + 0.2 * i))
    parts.append((0.02, inst.vibes(93, 1.2, level=0.1), 0.0))
    return _stage(parts, 1.5, wet=0.24, decay=1.6, peak=0.74)


# MARK: Metal


def denaro() -> np.ndarray:
    """One coin into the purse."""
    return _finish([(0.0, inst.coin(_rng(108), level=0.62))], 0.55, wet=0.18, decay=1.2, peak=0.6)


def purchase() -> np.ndarray:
    """The shop till: coins into the drawer, the bell on the till, and a chord up."""
    rng = _rng(109)
    parts = [(i * 0.07, inst.coin(rng, level=0.46 - 0.07 * i, freq=2000.0 + 330.0 * i),
              -0.3 + 0.3 * i) for i in range(3)]
    parts.append((0.16, inst.handbell(dsp.midi_hz(91), 0.9, level=0.2), 0.2))
    parts.append((0.22, inst.handbell(dsp.midi_hz(96), 1.1, level=0.18), -0.1))
    for i, note in enumerate((72, 76, 79, 84)):
        parts.append((0.12 + i * 0.045, inst.vibes(note, 1.3, level=0.22 - 0.025 * i), -0.2 + 0.15 * i))
    return _stage(parts, 1.4, wet=0.22, decay=1.5, peak=0.8)


# MARK: Wood
#
# The interface. All of these have to survive being heard a thousand times, so
# they are short, dry and well under the cards.


def tap() -> np.ndarray:
    rng = _rng(110)
    n = dsp.seconds(0.12)
    t = np.arange(n) / SR
    click = dsp.bandpass(rng.uniform(-1, 1, n), 1250.0, 2.2) * dsp.pluck(n, 0.0004, 0.012)
    body = 0.4 * np.sin(2.0 * np.pi * 240.0 * t) * dsp.pluck(n, 0.0006, 0.022)
    return _finish([(0.0, click + body)], 0.13, wet=0.05, peak=0.3)


def toggle() -> np.ndarray:
    """Two taps, the second a fifth up: a thing moving from one state to another."""
    rng = _rng(111)
    parts = []
    for i, freq in enumerate((330.0, 494.0)):
        n = dsp.seconds(0.1)
        t = np.arange(n) / SR
        click = dsp.bandpass(rng.uniform(-1, 1, n), 1600.0, 2.4) * dsp.pluck(n, 0.0004, 0.01)
        parts.append((i * 0.048, click + 0.45 * np.sin(2.0 * np.pi * freq * t) * dsp.pluck(n, 0.0006, 0.02)))
    return _finish(parts, 0.2, wet=0.06, peak=0.36)


def turn() -> np.ndarray:
    """Your turn. Two notes from the chord the music is already playing."""
    return _finish([(0.0, inst.vibes(76, 1.1, level=0.4)),
                    (0.1, inst.vibes(81, 1.2, level=0.3))],
                   0.9, wet=0.3, decay=1.6, peak=0.42)


def step() -> np.ndarray:
    """One line of the round summary landing."""
    return _finish([(0.0, inst.vibes(72, 0.45, level=0.35, tremolo=0.0))],
                   0.3, wet=0.14, decay=0.9, peak=0.36)


def reveal() -> np.ndarray:
    """The name at the end of the summary."""
    rng = _rng(112)
    parts = [(0.0, inst.brush(rng, 0.45, level=0.14))]
    for i, note in enumerate((69, 76, 81)):
        parts.append((i * 0.04, inst.vibes(note, 1.7, level=0.32 - 0.05 * i)))
    parts.append((0.06, inst.bell(dsp.midi_hz(88), 1.5, level=0.1)))
    return _finish(parts, 1.5, wet=0.3, decay=1.9, peak=0.66, stereo=True)


def notice() -> np.ndarray:
    """Something to read has appeared. Deliberately unremarkable."""
    return _finish([(0.0, inst.vibes(74, 0.5, level=0.24, tremolo=0.0)),
                    (0.085, inst.vibes(74, 0.5, level=0.16, tremolo=0.0))],
                   0.5, wet=0.16, decay=1.0, peak=0.34)


def refused() -> np.ndarray:
    """A move that will not go: a dull thud rather than a buzzer."""
    rng = _rng(113)
    n = dsp.seconds(0.3)
    t = np.arange(n) / SR
    thud = np.sin(2.0 * np.pi * 116.0 * t) * dsp.pluck(n, 0.002, 0.09)
    thud += 0.5 * np.sin(2.0 * np.pi * 109.0 * t) * dsp.pluck(n, 0.002, 0.07)
    thud += 0.35 * dsp.lowpass(rng.uniform(-1, 1, n), 700.0) * dsp.pluck(n, 0.001, 0.04)
    return _finish([(0.0, dsp.lowpass(thud, 1400.0))], 0.34, wet=0.08, peak=0.48)


def clock() -> np.ndarray:
    """The turn clock in its last seconds. One dry tick, as quiet as it can be."""
    rng = _rng(114)
    n = dsp.seconds(0.08)
    tick = dsp.bandpass(rng.uniform(-1, 1, n), 3100.0, 3.0) * dsp.pluck(n, 0.0003, 0.007)
    return _finish([(0.0, tick)], 0.09, wet=0.0, peak=0.26)


# What gets several takes. A card is heard hundreds of times a game, a settebello twice.
VARIED = {"sfx_pick": pick, "sfx_play": play, "sfx_take": take, "sfx_theirs": theirs}

CATALOGUE = {
    **{f"{name}_{i + 1}": (lambda make=make, i=i: make(i))
       for name, make in VARIED.items() for i in range(TAKES)},
    "sfx_sweep": sweep,
    "sfx_scopa": scopa,
    "sfx_cheer_campana": cheer_campana,
    "sfx_cheer_festa": cheer_festa,
    "sfx_cheer_fuochi": cheer_fuochi,
    "sfx_cheer_oro": cheer_oro,
    "sfx_deal": deal,
    "sfx_settebello": settebello,
    "sfx_rise": rise,
    "sfx_shine": shine,
    "sfx_denaro": denaro,
    "sfx_purchase": purchase,
    "sfx_tap": tap,
    "sfx_toggle": toggle,
    "sfx_turn": turn,
    "sfx_step": step,
    "sfx_reveal": reveal,
    "sfx_notice": notice,
    "sfx_refused": refused,
    "sfx_clock": clock,
}
