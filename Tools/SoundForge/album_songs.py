"""The songs an album hands over rather than the shop: one per volume that pays in music.

Faenza is the Maiolica volume's. The town gave faience its name and Romagna gave the dance
halls the mazurka, so it is one: three-four with the lift on the second beat, the bass on
one and the guitar on the two after it. Like every song it keeps to A minor and C major,
and like the leggendario it is, it has two halves and the whole band. The first half is
the mandolin's in C, the second the bells and the accordion's in F with a flute under.

Tempos divide 2646000, so every loop is a whole number of samples.
"""

import numpy as np

import dsp
import instruments as inst
from music import Bars
from songs import AM, C, DM, F, G7, _hands, _line, _mandolin_line, _pads, _render

FAENZA_CHORDS = [C, C, G7, G7, G7, G7, C, C, C, C, F, F, C, G7, C, C,
                 F, F, C, C, G7, G7, C, C, F, F, C, AM, DM, G7, C, G7]

# The mandolin's half: a dotted lift into every bar, as a mazurka steps.
FAENZA_A = [
    (0, 0, 76, 0.75), (0, 0.75, 77, 0.25), (0, 1, 79, 1), (0, 2, 84, 1),
    (1, 0, 79, 1.5), (1, 1.5, 76, 0.5), (1, 2, 72, 1),
    (2, 0, 74, 0.75), (2, 0.75, 76, 0.25), (2, 1, 77, 1), (2, 2, 83, 1),
    (3, 0, 79, 2), (3, 2, 77, 1),
    (4, 0, 74, 0.75), (4, 0.75, 76, 0.25), (4, 1, 77, 1), (4, 2, 79, 1),
    (5, 0, 81, 1), (5, 1, 79, 1), (5, 2, 77, 1),
    (6, 0, 76, 1), (6, 1, 79, 1), (6, 2, 72, 1),
    (7, 0, 76, 2), (7, 2, 79, 1),
    (8, 0, 76, 0.75), (8, 0.75, 77, 0.25), (8, 1, 79, 1), (8, 2, 84, 1),
    (9, 0, 84, 1), (9, 1, 83, 0.5), (9, 1.5, 81, 0.5), (9, 2, 79, 1),
    (10, 0, 77, 0.75), (10, 0.75, 79, 0.25), (10, 1, 81, 1), (10, 2, 84, 1),
    (11, 0, 81, 2), (11, 2, 77, 1),
    (12, 0, 79, 1), (12, 1, 76, 1), (12, 2, 72, 1),
    (13, 0, 74, 1), (13, 1, 77, 1), (13, 2, 71, 1),
    (14, 0, 72, 2), (14, 2, 67, 1),
    (15, 0, 72, 2), (15, 2, 76, 1),
]

# The second half sings: longer notes, held tremolo, climbing to the top of the tune.
FAENZA_B = [
    (16, 0, 81, 2), (16, 2, 77, 1),
    (17, 0, 84, 2), (17, 2, 81, 1),
    (18, 0, 79, 1.5), (18, 1.5, 81, 0.5), (18, 2, 79, 1),
    (19, 0, 76, 3),
    (20, 0, 77, 2), (20, 2, 74, 1),
    (21, 0, 83, 2), (21, 2, 79, 1),
    (22, 0, 84, 1.5), (22, 1.5, 83, 0.5), (22, 2, 84, 1),
    (23, 0, 79, 3),
    (24, 0, 81, 2), (24, 2, 77, 1),
    (25, 0, 84, 2), (25, 2, 86, 1),
    (26, 0, 88, 1.5), (26, 1.5, 86, 0.5), (26, 2, 84, 1),
    (27, 0, 81, 2), (27, 2, 76, 1),
    (28, 0, 77, 1), (28, 1, 81, 1), (28, 2, 86, 1),
    (29, 0, 83, 1.5), (29, 1.5, 81, 0.5), (29, 2, 79, 1),
    (30, 0, 84, 3),
    (31, 0, 79, 1), (31, 1, 77, 1), (31, 2, 74, 1),
]

# A handbell at the top of each phrase of the second half: the glaze catching the light.
FAENZA_BELLS = [(16, 0, 84, 3), (20, 0, 83, 3), (24, 0, 84, 3), (28, 0, 86, 3)]


def _faenza_comp(bars: Bars, hands: list[list[int]], rng: np.random.Generator) -> dict[str, np.ndarray]:
    """The guitar on two and three, the accordion joining it for the second half."""
    guitar, reeds = bars.canvas(), bars.canvas()
    for bar, hand in enumerate(hands):
        for beat, weight in ((1.0, 1.0), (2.0, 0.75)):
            dsp.place(guitar, inst.strum(hand, 0.5, level=0.2 * weight, spread=0.007,
                                         down=beat == 1.0, rng=rng), bars.at(bar, beat))
            if bar >= 16:
                dsp.place(reeds, inst.squeeze(hand[1:], bars.beat * 0.7, level=0.06 * weight),
                          bars.at(bar, beat))
    return {"guitar": guitar, "reeds": reeds}


def _faenza_bass(bars: Bars, rng: np.random.Generator) -> np.ndarray:
    """Root on one, the fifth on the next bar's one when the chord holds."""
    track = bars.canvas()
    for bar, (root, _) in enumerate(FAENZA_CHORDS):
        held = bar > 0 and FAENZA_CHORDS[bar - 1][0] == root
        note = root + 7 if held else root
        dsp.place(track, inst.upright(note if note < 52 else note - 12, bars.beat * 1.6, level=0.55, rng=rng),
                  bars.at(bar))
    return track


def _faenza_rhythm(bars: Bars, rng: np.random.Generator) -> np.ndarray:
    """A shaker through the first half; the tambourine on one and a shake on two for the second."""
    track = bars.canvas()
    for bar in range(len(FAENZA_CHORDS)):
        if bar < 16:
            for half in range(6):
                dsp.place(track, inst.shaker(rng, level=0.055 if half % 2 else 0.035), bars.at(bar, half * 0.5))
        else:
            dsp.place(track, inst.tambourine(rng, level=0.4), bars.at(bar))
            dsp.place(track, inst.tambourine(rng, level=0.24, shake=True), bars.at(bar, 1.0))
    return track


def faenza() -> np.ndarray:
    """A mazurka from Romagna, the whole band: mandolin, then bells and accordion, a flute under."""
    bars = Bars(bpm=144, bars=len(FAENZA_CHORDS), beats=3)
    rng = np.random.default_rng(31201)
    hands = _hands(FAENZA_CHORDS)
    under = [(bar, beat, note - 12, length) for bar, beat, note, length in FAENZA_B]
    stems = {
        **_faenza_comp(bars, hands, rng),
        "bass": _faenza_bass(bars, rng),
        "keys": _pads(bars, FAENZA_CHORDS, hands, 0.11),
        "rhythm": _faenza_rhythm(bars, rng),
        "mandolin": _mandolin_line(bars, FAENZA_A + FAENZA_B, rng, per_beat=4, level=1.0, held=1.5),
        "flute": _line(bars, under, lambda n, s: inst.flute(n, s, level=0.1, rng=rng)),
        "bells": _line(bars, FAENZA_BELLS, lambda n, s: inst.handbell(dsp.midi_hz(n), s, level=0.14), extra=1.5),
    }
    places = {
        "guitar": (1.0, -0.3, 0.28),
        "reeds": (0.9, 0.3, 0.32),
        "bass": (0.95, 0.0, 0.05),
        "keys": (0.9, 0.12, 0.3),
        "rhythm": (0.8, 0.42, 0.16),
        "mandolin": (0.78, 0.14, 0.34),
        "flute": (0.6, -0.18, 0.42),
        "bells": (0.7, 0.36, 0.55),
    }
    return _render(stems, places, bars, decay=2.1, damping=4500.0)


LOOPS = {
    "music_faenza": faenza,
}
