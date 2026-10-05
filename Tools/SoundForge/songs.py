"""The table songs the shop sells: six loops for the bed under a game, two of each of the
cheaper grades, one prezioso and one leggendario.

Every song keeps to the notes of A minor and C major, the house key, so a scopa, a
settebello or a win still fits over whichever one is playing. The dearer the song, the more
of the band plays it: the common ones are the house band with a new tune, the leggendario
is two sections, a verse and a refrain, with everyone in.

Tempos divide 2646000, so every loop is a whole number of samples.
"""

import numpy as np

import dsp
import instruments as inst
import music
from music import Bars

# Chords as a bass root and the pitch classes the guitar may use.
AM = (45, (9, 0, 4))
DM = (50, (2, 5, 9))
E7 = (40, (4, 8, 11, 2))
F = (41, (5, 9, 0))
C = (48, (0, 4, 7))
G = (43, (7, 11, 2))
G7 = (43, (7, 11, 2, 5))


def _hands(chords: list[tuple[int, tuple[int, ...]]], low: int = 55, high: int = 76) -> list[list[int]]:
    """The guitar's hand on each chord, each finger moving as little as it can."""
    out, hand = [], music.OPENING
    for _, pitches in chords:
        hand = music._voicing(pitches, hand, low, high)
        out.append(hand)
    return out


def _line(bars: Bars, notes: list[tuple], voice, extra: float = 0.0) -> np.ndarray:
    """A tune as (bar, beat, note, beats), each note rendered by `voice(note, seconds)`."""
    track = bars.canvas()
    for bar, beat, note, length in notes:
        dsp.place(track, voice(note, length * bars.beat + extra), bars.at(bar, beat))
    return track


def _mandolin_line(bars: Bars, notes: list[tuple], rng: np.random.Generator,
                   per_beat: int, level: float, held: float = 0.9) -> np.ndarray:
    """Short notes are picked once and anything `held` beats or longer is played tremolo."""
    rate = per_beat / bars.beat

    def voice(note: float, seconds: float) -> np.ndarray:
        if seconds < bars.beat * held:
            return inst.mandolin(note, seconds + 0.25, level=level, rng=rng)
        return inst.tremolo(note, seconds, rate, level=level, rng=rng)

    return _line(bars, notes, voice)


def _bass(bars: Bars, chords: list, rng: np.random.Generator, beats: tuple[float, ...],
          level: float = 0.58, hold: float = 1.4, step: float = 0.5) -> np.ndarray:
    """Root on the first beat, the fifth on the others, and a step into the next root."""
    track = bars.canvas()
    for bar, (root, _) in enumerate(chords):
        nxt = chords[(bar + 1) % len(chords)][0]
        for i, beat in enumerate(beats):
            note = root if i == 0 else root + 7
            dsp.place(track, inst.upright(note, hold * bars.beat, level=level * (1.0 if i == 0 else 0.72),
                                          rng=rng), bars.at(bar, beat))
        approach = nxt + (1 if nxt < root else -1)
        dsp.place(track, inst.upright(approach, step * bars.beat, level=level * 0.5, rng=rng),
                  bars.at(bar, bars.beats - step))
    return track


def _pads(bars: Bars, chords: list, hands: list[list[int]], level: float) -> np.ndarray:
    track = bars.canvas()
    for bar, hand in enumerate(hands):
        dsp.place(track, inst.pad([n - 12 for n in hand[:3]], bars.beat * (bars.beats + 0.6), level=level),
                  bars.at(bar, -0.1))
    return track


def _arpeggio(bars: Bars, hands: list[list[int]], chords: list, pattern: list[int], step: float,
              level: float, rng: np.random.Generator) -> np.ndarray:
    """The guitar picked one string at a time. Index 0 is the bass string, the rest the hand."""
    track = bars.canvas()
    for bar, (hand, (root, _)) in enumerate(zip(hands, chords)):
        strings = [root + 12 if root + 12 < hand[0] else root] + hand
        for i, index in enumerate(pattern):
            note = strings[min(index, len(strings) - 1)]
            weight = 1.0 if i == 0 else 0.7
            dsp.place(track, inst.nylon(note, step * bars.beat * 3.0, level=level * weight, rng=rng),
                      bars.at(bar, i * step))
    return track


def _render(stems: dict[str, np.ndarray], places: dict, bars: Bars,
            decay: float = 2.0, damping: float = 4200.0) -> np.ndarray:
    """The house mix, with the very top rolled off: hiss nobody hears at a table is most of a file."""
    mixed = music._mix(stems, places, bars.length, decay=decay, damping=damping)
    return dsp.trim(np.stack([_roll_off(side) for side in mixed]), 0.88)


def _roll_off(loop: np.ndarray, lead: int = 4096) -> np.ndarray:
    """Filtered with the loop's own end in front of it, so the seam stays where it was."""
    return dsp.lowpass(np.concatenate([loop[-lead:], loop]), 9000.0)[lead:]


# MARK: Comune


POMERIGGIO_CHORDS = [AM, AM, DM, DM, G, G, C, E7, AM, AM, DM, DM, F, E7, AM, E7]

POMERIGGIO_TUNE = [
    (0, 0, 76, 2), (0, 2, 72, 1), (1, 0, 69, 3),
    (2, 0, 77, 2), (2, 2, 74, 1), (3, 0, 72, 1), (3, 1, 74, 2),
    (4, 0, 79, 2), (4, 2, 77, 1), (5, 0, 74, 3),
    (6, 0, 76, 1.5), (6, 1.5, 74, 0.5), (6, 2, 72, 1), (7, 0, 71, 2), (7, 2, 68, 1),
    (8, 0, 69, 1), (8, 1, 72, 1), (8, 2, 76, 1), (9, 0, 81, 3),
    (10, 0, 77, 2), (10, 2, 76, 1), (11, 0, 74, 3),
    (12, 0, 72, 1), (12, 1, 74, 1), (12, 2, 77, 1), (13, 0, 76, 2), (13, 2, 74, 1),
    (14, 0, 72, 1), (14, 1, 71, 1), (14, 2, 69, 1), (15, 0, 68, 2), (15, 2, 71, 1),
]


def pomeriggio() -> np.ndarray:
    """A slow waltz on the guitar, with the vibraphone humming the tune."""
    bars = Bars(bpm=112, bars=16, beats=3)
    rng = np.random.default_rng(31101)
    hands = _hands(POMERIGGIO_CHORDS)
    stems = {
        "guitar": _arpeggio(bars, hands, POMERIGGIO_CHORDS, [0, 2, 3, 4, 3, 2], 0.5, 0.26, rng),
        "bass": _bass(bars, POMERIGGIO_CHORDS, rng, (0.0,), level=0.5, hold=2.6),
        "keys": _pads(bars, POMERIGGIO_CHORDS, hands, 0.12),
        "vibes": _line(bars, POMERIGGIO_TUNE, lambda n, s: inst.vibes(n, s, level=0.34), extra=1.0),
    }
    places = {
        "guitar": (1.0, -0.22, 0.32),
        "bass": (0.9, 0.0, 0.05),
        "keys": (0.9, 0.12, 0.3),
        "vibes": (0.5, 0.28, 0.45),
    }
    return _render(stems, places, bars, decay=2.1, damping=4000.0)


PIAZZA_TUNE = [
    (0, 0, 72, 1.5), (0, 1.5, 71, 0.5), (0, 2, 69, 2),
    (1, 0, 77, 1.5), (1, 1.5, 76, 0.5), (1, 2, 74, 2),
    (2, 0, 71, 1), (2, 1, 74, 1), (2, 2, 79, 2),
    (3, 0, 76, 2.5), (3, 3, 72, 1),
    (4, 0, 69, 1.5), (4, 1.5, 72, 0.5), (4, 2, 77, 2),
    (5, 0, 74, 1.5), (5, 1.5, 72, 0.5), (5, 2, 71, 2),
    (6, 0, 68, 1), (6, 1, 71, 1), (6, 2, 74, 1), (6, 3, 77, 1),
    (7, 0, 76, 1), (7, 1, 72, 1), (7, 2, 69, 2),
]


def piazza() -> np.ndarray:
    """The house band across the square, with an accordion singing over the changes."""
    bars = Bars(bpm=84, bars=8)
    rng = np.random.default_rng(31102)
    stems = music._rhythm_section(bars, rng, melody=False, comp_level=0.24, shaker_level=0.06)
    stems["reeds"] = _line(bars, PIAZZA_TUNE, lambda n, s: inst.squeeze([n], s * 0.95, level=0.05))
    places = {
        "guitar": (0.9, -0.3, 0.3),
        "bass": (0.95, 0.0, 0.05),
        "keys": (0.9, 0.1, 0.3),
        "ticks": (0.8, 0.42, 0.14),
        "skins": (0.9, -0.15, 0.36),
        "reeds": (0.62, 0.24, 0.4),
    }
    return _render(stems, places, bars, decay=2.0, damping=4200.0)


# MARK: Raro


BARCAROLA_CHORDS = [AM, AM, DM, AM, E7, AM, F, C, DM, AM, E7, E7]

# In eighths: six to the bar.
BARCAROLA_TUNE = [
    (0, 0, 76, 3), (0, 3, 77, 1), (0, 4, 76, 2), (1, 0, 72, 3), (1, 3, 69, 3),
    (2, 0, 74, 3), (2, 3, 77, 1), (2, 4, 74, 2), (3, 0, 72, 6),
    (4, 0, 71, 2), (4, 2, 68, 1), (4, 3, 71, 3), (5, 0, 69, 6),
    (6, 0, 72, 3), (6, 3, 77, 3), (7, 0, 76, 4), (7, 4, 79, 2),
    (8, 0, 77, 3), (8, 3, 76, 1), (8, 4, 74, 2), (9, 0, 76, 3), (9, 3, 72, 3),
    (10, 0, 71, 3), (10, 3, 74, 3), (11, 0, 71, 2), (11, 2, 68, 1), (11, 3, 71, 3),
]


def barcarola() -> np.ndarray:
    """A boat song in six-eight: the guitar rocking and a wooden flute over the water."""
    bars = Bars(bpm=189, bars=12, beats=6)
    rng = np.random.default_rng(31103)
    hands = _hands(BARCAROLA_CHORDS)
    stems = {
        "guitar": _arpeggio(bars, hands, BARCAROLA_CHORDS, [0, 2, 3, 4, 3, 2], 1.0, 0.27, rng),
        "bass": _bass(bars, BARCAROLA_CHORDS, rng, (0.0, 3.0), level=0.5, hold=2.8, step=1.0),
        "keys": _pads(bars, BARCAROLA_CHORDS, hands, 0.14),
        "flute": _line(bars, BARCAROLA_TUNE, lambda n, s: inst.flute(n, s, level=0.13, rng=rng)),
        "glints": _line(bars, [(b, 0, 81 if b % 4 == 0 else 76, 3) for b in range(0, 12, 2)],
                        lambda n, s: inst.vibes(n, s, level=0.12), extra=1.0),
    }
    places = {
        "guitar": (1.0, -0.25, 0.34),
        "bass": (0.9, 0.0, 0.05),
        "keys": (1.0, 0.1, 0.34),
        "flute": (0.6, 0.22, 0.42),
        "glints": (0.6, 0.45, 0.6),
    }
    return _render(stems, places, bars, decay=2.6, damping=3800.0)


SERENATA_CHORDS = [C, AM, DM, G7, C, E7, AM, G7]

SERENATA_TUNE = [
    (0, 0, 76, 1.5), (0, 1.5, 77, 0.5), (0, 2, 79, 2),
    (1, 0, 81, 1), (1, 1, 79, 1), (1, 2, 76, 2),
    (2, 0, 77, 1.5), (2, 1.5, 76, 0.5), (2, 2, 74, 2),
    (3, 0, 71, 1), (3, 1, 74, 1), (3, 2, 77, 1), (3, 3, 74, 1),
    (4, 0, 72, 1.5), (4, 1.5, 74, 0.5), (4, 2, 76, 2),
    (5, 0, 80, 1.5), (5, 1.5, 77, 0.5), (5, 2, 76, 2),
    (6, 0, 81, 1), (6, 1, 76, 1), (6, 2, 72, 1), (6, 3, 76, 1),
    (7, 0, 74, 3), (7, 3, 71, 1),
]


def serenata() -> np.ndarray:
    """A mandolin under a window, played tremolo over a picked guitar."""
    bars = Bars(bpm=72, bars=8)
    rng = np.random.default_rng(31104)
    hands = _hands(SERENATA_CHORDS)
    stems = {
        "guitar": _arpeggio(bars, hands, SERENATA_CHORDS, [0, 2, 3, 4, 1, 3, 2, 4], 0.5, 0.24, rng),
        "bass": _bass(bars, SERENATA_CHORDS, rng, (0.0, 2.0), level=0.52, hold=1.6),
        "keys": _pads(bars, SERENATA_CHORDS, hands, 0.13),
        "mandolin": _mandolin_line(bars, SERENATA_TUNE, rng, per_beat=6, level=1.2),
    }
    places = {
        "guitar": (1.0, -0.3, 0.3),
        "bass": (0.9, 0.0, 0.05),
        "keys": (0.9, 0.14, 0.32),
        "mandolin": (0.75, 0.2, 0.36),
    }
    return _render(stems, places, bars, decay=2.2, damping=4400.0)


# MARK: Prezioso


TARANTELLA_CHORDS = [AM, AM, E7, E7, E7, E7, AM, AM,
                     DM, DM, AM, AM, E7, E7, AM, AM]


def _eighths(bar: int, notes: list[float | tuple[float, int]]) -> list[tuple]:
    """A bar of the tarantella written as eighths: a bare note is one, a pair is (note, length)."""
    out, at = [], 0
    for entry in notes:
        note, length = entry if isinstance(entry, tuple) else (entry, 1)
        out.append((bar, at, note, length))
        at += length
    return out


TARANTELLA_A = [
    [76, 77, 76, 72, 71, 72], [69, 72, 76, (81, 3)],
    [80, 81, 80, 77, 76, 74], [71, 74, 77, (76, 3)],
    [74, 76, 74, 71, 68, 71], [64, 68, 71, (74, 3)],
    [72, 74, 72, 69, 68, 69],
]

TARANTELLA_B = [
    [(74, 2), 77, 77, 76, 74], [74, 72, 74, (77, 3)],
    [(76, 2), 72, 72, 71, 69], [72, 69, 72, (76, 3)],
    [71, 74, 77, 76, 74, 71], [68, 71, 74, (80, 3)],
    [81, 80, 81, 76, 72, 76], [(69, 3), 71, 72, 74],
]

def _tarantella_tune() -> list[tuple]:
    bars = TARANTELLA_A + [[(69, 3), 64, 68, 71]] + TARANTELLA_B
    return [note for bar, notes in enumerate(bars) for note in _eighths(bar, notes)]


def _tarantella_band(bars: Bars, hands: list[list[int]], rng: np.random.Generator) -> dict[str, np.ndarray]:
    """Bass on one and four, the guitar and the accordion on the beats between."""
    guitar, reeds, jingles = bars.canvas(), bars.canvas(), bars.canvas()
    for bar, hand in enumerate(hands):
        for eighth in (1, 2, 4, 5):
            light = 0.8 if eighth in (2, 5) else 1.0
            dsp.place(guitar, inst.strum(hand, 0.3, level=0.2 * light, spread=0.006,
                                         down=eighth in (1, 4), rng=rng), bars.at(bar, eighth))
            dsp.place(reeds, inst.squeeze(hand[1:], bars.beat * 0.8, level=0.07 * light), bars.at(bar, eighth))
        for eighth in range(6):
            accent = 1.0 if eighth in (0, 3) else 0.55
            dsp.place(jingles, inst.tambourine(rng, level=0.5 * accent, shake=eighth not in (0, 3)),
                      bars.at(bar, eighth))
    return {"guitar": guitar, "reeds": reeds, "jingles": jingles}


def tarantella() -> np.ndarray:
    """The dance from the south, unhurried: tambourine, accordion and a running mandolin."""
    bars = Bars(bpm=288, bars=16, beats=6)
    rng = np.random.default_rng(31105)
    hands = _hands(TARANTELLA_CHORDS)
    stems = _tarantella_band(bars, hands, rng)
    stems["bass"] = _bass(bars, TARANTELLA_CHORDS, rng, (0.0, 3.0), level=0.55, hold=2.0, step=1.0)
    stems["mandolin"] = _mandolin_line(bars, _tarantella_tune(), rng, per_beat=2, level=0.8, held=2.5)
    places = {
        "guitar": (1.0, -0.3, 0.26),
        "reeds": (1.0, 0.28, 0.3),
        "jingles": (0.8, 0.45, 0.18),
        "bass": (0.95, 0.0, 0.05),
        "mandolin": (0.75, 0.12, 0.3),
    }
    return _render(stems, places, bars, decay=1.8, damping=4800.0)


# MARK: Leggendario


MERGELLINA_CHORDS = [AM, AM, DM, AM, E7, E7, AM, E7,
                     C, C, G7, G7, F, C, DM, E7]

MERGELLINA_VERSE = [
    (0, 0, 69, 1), (0, 1, 72, 1), (0, 2, 76, 1.5), (0, 3.5, 74, 0.5),
    (1, 0, 72, 2), (1, 2, 71, 1), (1, 3, 72, 1),
    (2, 0, 74, 1), (2, 1, 77, 1), (2, 2, 81, 1.5), (2, 3.5, 79, 0.5),
    (3, 0, 76, 3), (3, 3, 72, 1),
    (4, 0, 71, 1), (4, 1, 74, 1), (4, 2, 77, 1.5), (4, 3.5, 76, 0.5),
    (5, 0, 74, 2), (5, 2, 71, 1), (5, 3, 68, 1),
    (6, 0, 69, 1.5), (6, 1.5, 71, 0.5), (6, 2, 72, 1), (6, 3, 76, 1),
    (7, 0, 74, 2), (7, 2, 71, 1), (7, 3, 74, 1),
]

MERGELLINA_REFRAIN = [
    (8, 0, 79, 2), (8, 2, 76, 1), (8, 3, 79, 1),
    (9, 0, 84, 3), (9, 3, 83, 0.5), (9, 3.5, 81, 0.5),
    (10, 0, 79, 2), (10, 2, 77, 1), (10, 3, 74, 1),
    (11, 0, 77, 3), (11, 3, 74, 1),
    (12, 0, 77, 1.5), (12, 1.5, 76, 0.5), (12, 2, 77, 1), (12, 3, 81, 1),
    (13, 0, 79, 2), (13, 2, 76, 1), (13, 3, 72, 1),
    (14, 0, 74, 1), (14, 1, 77, 1), (14, 2, 76, 1), (14, 3, 74, 1),
    (15, 0, 71, 2), (15, 2, 68, 1), (15, 3, 71, 1),
]

# The accordion holding a third under the refrain.
MERGELLINA_COUNTER = [(8, 0, 64, 4), (9, 0, 67, 4), (10, 0, 65, 4), (11, 0, 62, 4),
                      (12, 0, 69, 4), (13, 0, 67, 4), (14, 0, 65, 4), (15, 0, 68, 4)]


def _mergellina_guitar(bars: Bars, hands: list[list[int]], rng: np.random.Generator) -> np.ndarray:
    """Picked through the verse, strummed on two and four through the refrain."""
    verse = _arpeggio(bars, hands[:8], MERGELLINA_CHORDS[:8], [0, 2, 3, 4, 1, 3, 2, 4], 0.5, 0.22, rng)
    refrain = bars.canvas()
    for bar in range(8, 16):
        for beat, down in ((1.0, True), (2.5, False), (3.0, True)):
            dsp.place(refrain, inst.strum(hands[bar], 0.9, level=0.26 if down else 0.18, down=down, rng=rng),
                      bars.at(bar, beat))
        dsp.place(refrain, inst.nylon(MERGELLINA_CHORDS[bar][0] + 12, bars.beat * 2, level=0.28, rng=rng),
                  bars.at(bar))
    return verse + refrain


def _mergellina_rhythm(bars: Bars, rng: np.random.Generator) -> np.ndarray:
    """Shaker and rim under the verse; the tambourine comes in for the refrain."""
    track = bars.canvas()
    for bar in range(16):
        refrain = bar >= 8
        for eighth in range(8):
            if refrain:
                hit = inst.tambourine(rng, level=0.42 if eighth in (2, 6) else 0.22, shake=eighth not in (2, 6))
            else:
                hit = inst.shaker(rng, level=0.06 if eighth % 2 else 0.035)
            dsp.place(track, hit, bars.at(bar, eighth * 0.5))
        if not refrain:
            for beat in (1.0, 3.0):
                dsp.place(track, inst.rim(rng, level=0.08), bars.at(bar, beat))
    return track


def mergellina() -> np.ndarray:
    """A Neapolitan song with the whole band: a minor verse, a major refrain, bells at the top."""
    bars = Bars(bpm=112, bars=16)
    rng = np.random.default_rng(31106)
    hands = _hands(MERGELLINA_CHORDS)
    bells = [(8, 0, 84, 3), (12, 0, 81, 3)]
    stems = {
        "guitar": _mergellina_guitar(bars, hands, rng),
        "bass": _bass(bars, MERGELLINA_CHORDS, rng, (0.0, 2.0), level=0.56, hold=1.6),
        "keys": _pads(bars, MERGELLINA_CHORDS, hands, 0.15),
        "rhythm": _mergellina_rhythm(bars, rng),
        "mandolin": _mandolin_line(bars, MERGELLINA_VERSE + MERGELLINA_REFRAIN, rng, per_beat=6, level=1.0),
        "reeds": _line(bars, MERGELLINA_COUNTER, lambda n, s: inst.squeeze([n], s * 0.96, level=0.045)),
        "bells": _line(bars, bells, lambda n, s: inst.handbell(dsp.midi_hz(n), s, level=0.16), extra=1.5),
    }
    places = {
        "guitar": (1.0, -0.3, 0.3),
        "bass": (0.95, 0.0, 0.05),
        "keys": (1.0, 0.12, 0.32),
        "rhythm": (0.8, 0.44, 0.16),
        "mandolin": (0.78, 0.16, 0.34),
        "reeds": (0.8, -0.1, 0.36),
        "bells": (0.7, 0.36, 0.55),
    }
    return _render(stems, places, bars, decay=2.2, damping=4600.0)


LOOPS = {
    "music_pomeriggio": pomeriggio,
    "music_piazza": piazza,
    "music_barcarola": barcarola,
    "music_serenata": serenata,
    "music_tarantella": tarantella,
    "music_mergellina": mergellina,
}
