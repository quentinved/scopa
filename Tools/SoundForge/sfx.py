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
    """The table swept clean: the loudest moment in the game.

    The difficulty is that the set already has a brightest sound, and it belongs
    to the settebello. Going brighter still would only blur the two, so this one
    is the biggest and the warmest instead — lower, wider, and with the room held
    open longer behind it.

    It is also the only sound the band plays: the same nylon guitar that is
    carrying the table music answers with an A minor chord, in the key the music
    is already in, so a scopa lands as the room reacting rather than as a prize
    being awarded. The cards leave first, the drum answers underneath, and the
    chord arrives a beat later, which is the order it happens in.
    """
    # Off the house numbering on purpose: this is the seed of the take that was
    # chosen out of several, and the grain of the noise is part of what was picked.
    rng = _rng(921)
    parts = [(0.0, inst.sweepnoise(rng, 0.30, 5200.0, 1300.0, level=0.34))]
    # More cards than a sweep, and faster: this is the whole table going.
    for i in range(6):
        parts.append((i * 0.042, inst.flick(rng, level=0.44 - 0.045 * i, decay=0.05,
                                            colour=3600.0 - 260.0 * i)))
    parts.append((0.05, inst.tom(46.0, 128.0, 0.58, level=0.46)))
    parts.append((0.26, inst.land(rng, level=0.6, weight=1.1)))
    parts.append((0.10, inst.strum([57, 64, 69, 72, 76], 0.95, level=0.46,
                                   spread=0.020, rng=rng)))
    parts.append((0.16, inst.coin(rng, level=0.16, freq=2400.0)))
    parts.append((0.30, inst.vibes(81, 1.2, level=0.16)))
    return _finish(parts, 1.75, wet=0.26, decay=1.9, peak=0.88, stereo=True)


# MARK: Cheers
#
# Four alternatives to `scopa`, bought in the shop and played in its place when you are
# the one who swept. Each keeps the sweep itself — the cards leaving the cloth — because
# that part is the move and not a decoration; what changes is what the room does about it.


def cheer_campana() -> np.ndarray:
    """A church bell over the sweep: the village hears about it.

    Two bells a fifth apart struck together and a third one late, so it tolls rather
    than chimes. The bells run long past the cards, which is the whole effect: the
    table has moved on and the sound is still going.
    """
    rng = _rng(311)
    parts = [(0.0, inst.sweepnoise(rng, 0.28, 5000.0, 1250.0, level=0.30))]
    for i in range(5):
        parts.append((i * 0.042, inst.flick(rng, level=0.40 - 0.05 * i, decay=0.05,
                                            colour=3400.0 - 250.0 * i)))
    parts.append((0.04, inst.bell(523.25, 2.6, level=0.52, strike=0.62)))
    parts.append((0.07, inst.bell(349.23, 2.9, level=0.34, strike=0.5)))
    parts.append((0.52, inst.bell(659.25, 2.0, level=0.22, strike=0.44)))
    parts.append((0.24, inst.land(rng, level=0.5, weight=1.0)))
    return _finish(parts, 2.6, wet=0.32, decay=2.6, peak=0.88, stereo=True)


def cheer_festa() -> np.ndarray:
    """The village band: an accordion chord and a tambourine.

    The one cheer that is unambiguously other people. A minor chord, like everything
    else in the set, but voiced high and wide so it lands as a party rather than as
    a warning.
    """
    rng = _rng(477)
    parts = [(0.0, inst.sweepnoise(rng, 0.26, 5400.0, 1400.0, level=0.32))]
    for i in range(5):
        parts.append((i * 0.038, inst.flick(rng, level=0.40 - 0.05 * i, decay=0.05,
                                            colour=3600.0 - 260.0 * i)))
    parts.append((0.06, inst.accordion([69, 76, 81, 84], 1.1, level=0.44)))
    parts.append((0.05, inst.tom(52.0, 132.0, 0.5, level=0.38)))
    # The tambourine: four shakes on the beat, thinning out.
    for i in range(4):
        parts.append((0.06 + i * 0.115, inst.shaker(rng, level=0.34 - 0.06 * i, decay=0.06)))
    parts.append((0.20, inst.rim(rng, level=0.3)))
    parts.append((0.30, inst.vibes(88, 1.0, level=0.14)))
    return _finish(parts, 1.8, wet=0.24, decay=1.7, peak=0.88, stereo=True)


def cheer_tuono() -> np.ndarray:
    """Thunder: the lowest and darkest thing the game can say.

    No metal in it at all, which makes it the only sound in the set that is purely
    weather. The cards are nearly buried in it on purpose.

    It is a roll rather than a crack. A crack on its own was what this used to be, and
    it left the dearest cheer but one emptier after half a second than the cheapest one
    is after a full one: a strike, and then a room with nothing in it. Thunder is the
    part after the strike. So the first sweep is answered by three more, each lower and
    quieter and further away, and the last of them is still going when the banner
    leaves — which is the only thing distance ever sounds like.
    """
    rng = _rng(823)
    parts = [(0.0, inst.sweepnoise(rng, 0.9, 900.0, 90.0, level=0.46))]
    for i in range(4):
        parts.append((i * 0.045, inst.flick(rng, level=0.30 - 0.05 * i, decay=0.055,
                                            colour=2400.0 - 200.0 * i)))
    parts.append((0.02, inst.tom(64.0, 150.0, 0.7, level=0.52)))
    parts.append((0.30, inst.tom(38.0, 92.0, 1.1, level=0.46)))
    parts.append((0.36, inst.land(rng, level=0.5, weight=1.4)))
    # The roll: the same sweep three more times, each further off. They overlap on
    # purpose. A sweep swells over the first third of its span, so laid end to end they
    # would leave a hole between every pair and read as three thunders rather than one
    # going away; each starts while the one before it is still at its loudest.
    #
    # None of them runs as low as it could, either. The rumble that reads as enormous on
    # a desk is under the range a phone speaker reproduces at all, and a roll nobody can
    # hear is a gap with a number on it.
    for at, span, start, end, level in ((0.50, 0.95, 720.0, 120.0, 0.46),
                                        (1.00, 1.05, 540.0, 100.0, 0.36),
                                        (1.55, 1.20, 400.0, 86.0, 0.25)):
        parts.append((at, inst.sweepnoise(rng, span, start, end, level=level)))
    # A shoulder under the roll, kept below it. A drum louder than the weather it is
    # holding up is a second bang, and the roll then reads as two thunders again.
    parts.append((0.88, inst.tom(46.0, 98.0, 1.3, level=0.13)))
    return _finish(parts, 3.1, wet=0.36, decay=3.0, peak=0.86, stereo=True)


def cheer_oro() -> np.ndarray:
    """A purse emptied across the table, and the table not the same afterwards.

    This is the top of the shelf and it used to be the shortest thing on it: eleven
    coins over two seconds, which is a handful of change and not a fortune. It is the
    longest sound the game makes now, and the only cheer with a struck bell under it.

    Four things rather than one. The purse goes over — a thud and a bell, struck
    together, which is the gold arriving as one object before it becomes coins. Then
    the cascade, twenty coins on a closing stride so the fall tips rather than ticks.
    Then the spill: a second, lower fall for the ones that carried on across the cloth.
    Then three stragglers, spinning down one at a time into a bell still ringing, which
    is the part that makes it expensive — everybody else has stopped clapping and
    there is still gold moving.
    """
    rng = _rng(1049)
    parts = [(0.0, inst.sweepnoise(rng, 0.26, 6500.0, 1500.0, level=0.30))]
    # The sweep itself, at the front of every cheer.
    for i in range(5):
        parts.append((i * 0.036, inst.flick(rng, level=0.38 - 0.05 * i, decay=0.05,
                                            colour=4000.0 - 280.0 * i)))
    # The purse going over.
    parts.append((0.02, inst.tom(58.0, 152.0, 0.5, level=0.40)))
    parts.append((0.03, inst.bell(1046.50, 3.1, level=0.30, strike=0.7)))
    parts.append((0.06, inst.bell(698.46, 3.5, level=0.22, strike=0.42)))

    # The cascade. The stride closes, so the fall tips over rather than keeping time,
    # and each coin is struck a little lower than the last: the pile goes away from you.
    at = 0.05
    for i in range(20):
        parts.append((at, inst.coin(rng, level=0.40 - 0.013 * i, freq=2900.0 - 82.0 * i)))
        at += 0.062 * (0.94 ** i)
    parts.append((0.52, inst.land(rng, level=0.46, weight=1.1)))

    # The spill: what went on across the cloth after the purse was empty, lower and
    # thinner, and far enough behind the cascade to read as a consequence of it.
    at = 0.86
    for i in range(9):
        parts.append((at, inst.coin(rng, level=0.24 - 0.018 * i, freq=2050.0 - 95.0 * i)))
        at += 0.085 * (0.92 ** i)
    parts.append((0.94, inst.tom(44.0, 104.0, 0.7, level=0.22)))

    # The stragglers, one at a time, into the tail of the bell.
    for at, freq, level in ((1.52, 2400.0, 0.20), (1.94, 1800.0, 0.15), (2.38, 1450.0, 0.11)):
        parts.append((at, inst.coin(rng, level=level, freq=freq)))
    parts.append((1.40, inst.bell(523.25, 2.2, level=0.14, strike=0.3)))
    parts.append((0.22, inst.vibes(84, 1.6, level=0.17)))
    parts.append((1.10, inst.vibes(91, 1.8, level=0.10)))

    out = _finish(parts, 3.3, wet=0.32, decay=2.7, peak=0.92, stereo=True)
    # Opened out at the end rather than panned coin by coin: the cascade is one thing
    # happening across the table, not twenty things each in its own place.
    return dsp.trim(dsp.widen(out, delay=0.009, level=0.32), 0.92)


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


# MARK: Metal


def denaro() -> np.ndarray:
    """One coin into the purse."""
    return _finish([(0.0, inst.coin(_rng(108), level=0.62))], 0.55, wet=0.18, decay=1.2, peak=0.6)


def purchase() -> np.ndarray:
    """The shop till: a handful of coins and a chord."""
    rng = _rng(109)
    parts = [(i * 0.075, inst.coin(rng, level=0.5 - 0.08 * i, freq=1900.0 + 320.0 * i))
             for i in range(3)]
    for i, note in enumerate((72, 76, 79, 84)):
        parts.append((0.1 + i * 0.045, inst.vibes(note, 1.5, level=0.24 - 0.03 * i)))
    return _finish(parts, 1.5, wet=0.28, decay=1.8, peak=0.82, stereo=True)


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
    "sfx_cheer_tuono": cheer_tuono,
    "sfx_cheer_oro": cheer_oro,
    "sfx_deal": deal,
    "sfx_settebello": settebello,
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
