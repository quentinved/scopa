"""What the room is playing: two loops and three short pieces, all in A minor and
all from the same band, so a win can play over the table bed.

Tempos are chosen so a bar is a whole number of samples. A loop that ends on a
fraction of a sample drifts or clicks at the seam.
"""

import numpy as np

import dsp
import instruments as inst

# The turnaround the whole game sits on: a circle of fifths home to A minor.
PROGRESSION = [
    ("Am9", 45, (9, 0, 4, 7, 11)),
    ("Dm9", 50, (2, 5, 9, 0, 4)),
    ("G13", 43, (7, 11, 2, 5, 4)),
    ("Cmaj9", 48, (0, 4, 7, 11, 2)),
    ("Fmaj9", 41, (5, 9, 0, 4, 7)),
    ("Bm7b5", 47, (11, 2, 5, 9)),
    ("E7b9", 40, (4, 8, 11, 2, 5)),
    ("Am9", 45, (9, 0, 4, 7, 11)),
]

OPENING = [57, 64, 67, 71]  # A3 E4 G4 B4, where the guitar's hand starts.


def _voicing(pitches: tuple[int, ...], previous: list[int],
             low: int = 55, high: int = 76) -> list[int]:
    """Move each finger to the nearest note of the new chord, so the guitar never leaps."""
    available = [n for n in range(low, high + 1) if n % 12 in pitches]
    chosen: list[int] = []
    for note in previous:
        candidates = [n for n in available if n not in chosen]
        chosen.append(min(candidates, key=lambda n: (abs(n - note), n)))
    return sorted(chosen)


def _voicings() -> list[list[int]]:
    out, hand = [], OPENING
    for _, _, pitches in PROGRESSION:
        hand = _voicing(pitches, hand)
        out.append(hand)
    return out


class Bars:
    """Bar-and-beat into seconds, with the loop length that falls out of it."""

    def __init__(self, bpm: float, bars: int, beats: int = 4, tail: float = 5.0):
        self.beat = 60.0 / bpm
        self.bars, self.beats, self.tail = bars, beats, tail
        length = dsp.SR * self.beat * beats * bars
        assert abs(length - round(length)) < 1e-6, f"{bpm} bpm does not land on a sample"
        self.length = int(round(length))

    def at(self, bar: int, beat: float = 0.0) -> float:
        return (bar * self.beats + beat) * self.beat

    def canvas(self) -> np.ndarray:
        return np.zeros(self.length + dsp.seconds(self.tail))


# The comping figure: the bossa two-bar pattern, in eighths.
COMP = ((0.0, 1.5, 3.0), (1.0, 2.5, 3.5))

# Eight bars of vibraphone over the changes, kept sparse: a menu loop is heard
# dozens of times in a row.
MELODY = [
    (0, 2.0, 76, 1.0), (0, 3.0, 79, 1.0),
    (1, 0.0, 77, 1.5), (1, 2.0, 74, 1.2),
    (2, 0.0, 76, 1.0), (2, 1.5, 74, 0.6), (2, 2.5, 72, 1.4),
    (3, 1.0, 71, 2.2),
    (4, 0.0, 72, 1.0), (4, 2.0, 76, 1.6),
    (5, 0.5, 74, 1.0), (5, 2.5, 72, 1.2),
    (6, 0.0, 71, 1.0), (6, 2.0, 68, 1.6),
    (7, 0.0, 69, 3.0),
]


def _rhythm_section(bars: Bars, rng: np.random.Generator, *, melody: bool,
                    comp_level: float, shaker_level: float) -> dict[str, np.ndarray]:
    """Guitar, bass, pad and the quiet things, as separate stems to be placed."""
    voicings = _voicings()
    guitar, bass, keys, ticks, skins = (bars.canvas() for _ in range(5))

    for bar, (_, root, _) in enumerate(PROGRESSION):
        nxt = PROGRESSION[(bar + 1) % len(PROGRESSION)][1]
        _comp_bar(guitar, keys, bars, bar, voicings[bar], comp_level, rng)
        _bass_bar(bass, bars, bar, root, nxt, rng)
        _percussion_bar(ticks, skins, bars, bar, shaker_level, rng)

    stems = {"guitar": guitar, "bass": bass, "keys": keys, "ticks": ticks, "skins": skins}
    if melody:
        stems["vibes"] = _melody(bars)
    return stems


def _comp_bar(guitar: np.ndarray, keys: np.ndarray, bars: Bars, bar: int, chord: list[int],
              comp_level: float, rng: np.random.Generator) -> None:
    """One bar of strummed chord, with the pad holding the same notes under it."""
    for i, beat in enumerate(COMP[bar % 2]):
        dsp.place(guitar,
                  inst.strum(chord, 1.4, level=comp_level * (1.0 if i == 0 else 0.82),
                             down=(i % 2 == 0), rng=rng),
                  bars.at(bar, beat))
    dsp.place(keys, inst.pad([n - 12 for n in chord[:3]] + [chord[-1]],
                             bars.beat * 4.6, level=0.16), bars.at(bar, -0.1))


def _bass_bar(bass: np.ndarray, bars: Bars, bar: int, root: int, nxt: int,
              rng: np.random.Generator) -> None:
    dsp.place(bass, inst.upright(root, 1.7 * bars.beat, level=0.62, rng=rng), bars.at(bar))
    dsp.place(bass, inst.upright(root + 7, 1.2 * bars.beat, level=0.44, rng=rng), bars.at(bar, 2.0))
    # A semitone into the next root, so eight bars read as one line.
    approach = nxt + (1 if nxt < root else -1)
    dsp.place(bass, inst.upright(approach, 0.5 * bars.beat, level=0.34, rng=rng), bars.at(bar, 3.5))


def _percussion_bar(ticks: np.ndarray, skins: np.ndarray, bars: Bars, bar: int,
                    shaker_level: float, rng: np.random.Generator) -> None:
    for eighth in range(8):
        accent = 0.9 if eighth % 2 else 0.5
        dsp.place(ticks, inst.shaker(rng, level=shaker_level * accent), bars.at(bar, eighth * 0.5))
    for beat in (1.0, 3.0):
        dsp.place(ticks, inst.rim(rng, level=0.1), bars.at(bar, beat))
    if bar % 4 == 0:
        dsp.place(skins, inst.brush(rng, duration=bars.beat * 2.2, level=0.11), bars.at(bar, -0.15))


def _melody(bars: Bars) -> np.ndarray:
    tune = bars.canvas()
    for bar, beat, note, length in MELODY:
        dsp.place(tune, inst.vibes(note, length * bars.beat + 1.2, level=0.5), bars.at(bar, beat))
    return tune


def _mix(stems: dict[str, np.ndarray], places: dict[str, tuple[float, float, float]],
         length: int, *, decay: float, damping: float) -> np.ndarray:
    """Place each stem, send part of it to one shared plate, and fold the loop."""
    dry = np.zeros((2, len(next(iter(stems.values())))))
    send = np.zeros(dry.shape[1])
    for name, stem in stems.items():
        level, position, wet = places[name]
        dry += dsp.pan(stem * level, position)
        send += stem * level * wet
    wet = dsp.room(send, decay=decay, damping=damping)
    mixed = dsp.wrap(dry + 0.9 * wet, length)
    return dsp.trim(dsp.saturate(dsp.compress(mixed, threshold=-15.0, ratio=2.4), 1.15), 0.88)


def lungomare() -> np.ndarray:
    """The lobby loop: guitar, bass, brushes and a vibraphone melody over them."""
    bars = Bars(bpm=90, bars=8)
    rng = np.random.default_rng(20260908)
    stems = _rhythm_section(bars, rng, melody=True, comp_level=0.30, shaker_level=0.085)
    places = {
        "guitar": (1.0, -0.28, 0.30),
        "bass": (1.0, 0.0, 0.05),
        "keys": (0.85, 0.10, 0.28),
        "ticks": (1.0, 0.42, 0.14),
        "skins": (1.0, -0.15, 0.35),
        "vibes": (0.52, 0.30, 0.45),
    }
    return _mix(stems, places, bars.length, decay=1.9, damping=4600.0)


def tavolo() -> np.ndarray:
    """The table loop: the same band with no melody, a slower count and a darker room."""
    bars = Bars(bpm=80, bars=8)
    rng = np.random.default_rng(70707)
    stems = _rhythm_section(bars, rng, melody=False, comp_level=0.20, shaker_level=0.05)
    places = {
        "guitar": (0.85, -0.32, 0.34),
        "bass": (0.9, 0.0, 0.06),
        "keys": (1.15, 0.12, 0.34),
        "ticks": (0.7, 0.45, 0.16),
        "skins": (0.9, -0.18, 0.4),
    }
    return _mix(stems, places, bars.length, decay=2.4, damping=3200.0)


# MARK: The short pieces
#
# Played once each, over whatever loop is already running.


def _piece(duration: float, parts: list[tuple[float, np.ndarray, float, float]],
           decay: float = 2.2) -> np.ndarray:
    dry = np.zeros((2, dsp.seconds(duration)))
    send = np.zeros(dry.shape[1])
    for at, signal, position, wet in parts:
        stereo = dsp.pan(signal, position)
        for channel in range(2):
            dsp.place(dry[channel], stereo[channel], at)
        dsp.place(send, signal * wet, at)
    mixed = dry + 0.85 * dsp.room(send, decay=decay, damping=5200.0)
    return dsp.trim(dsp.fade_out(dsp.saturate(mixed, 1.1), 0.35), 0.9)


def victory() -> np.ndarray:
    """A game won: E7 leaning on A major, so the minor turns major at the end."""
    rng = np.random.default_rng(11)
    parts = [
        (0.0, inst.tom(58.0, 130.0, 0.5, level=0.5), 0.0, 0.1),
        (0.0, inst.brush(rng, 0.6, level=0.28), 0.0, 0.4),
        (0.0, inst.strum([52, 56, 59, 62], 1.0, level=0.42, rng=rng), -0.25, 0.3),
        (0.0, inst.upright(40, 0.6, level=0.55, rng=rng), 0.0, 0.05),
        (0.46, inst.strum([57, 61, 64, 69], 2.4, level=0.52, rng=rng), -0.2, 0.35),
        (0.46, inst.upright(45, 1.6, level=0.6, rng=rng), 0.0, 0.05),
        (0.46, inst.accordion([57, 61, 64, 69], 2.3, level=0.1), 0.15, 0.3),
    ]
    for i, note in enumerate((69, 73, 76, 81)):
        parts.append((0.5 + i * 0.085, inst.vibes(note, 2.2, level=0.32), 0.25, 0.5))
    parts.append((0.92, inst.bell(dsp.midi_hz(81), 2.6, level=0.2), 0.1, 0.6))
    return _piece(3.4, parts, decay=2.6)


def defeat() -> np.ndarray:
    """A game lost. Warm rather than sour."""
    rng = np.random.default_rng(12)
    parts = [
        (0.0, inst.strum([57, 60, 64, 69], 1.6, level=0.34, rng=rng), -0.22, 0.32),
        (0.0, inst.upright(45, 1.0, level=0.5, rng=rng), 0.0, 0.05),
        (0.0, inst.brush(rng, 0.7, level=0.2), 0.0, 0.4),
        (0.62, inst.strum([57, 62, 65, 69], 2.0, level=0.3, rng=rng), -0.18, 0.34),
        (0.62, inst.upright(38, 1.4, level=0.46, rng=rng), 0.0, 0.05),
        (0.62, inst.accordion([57, 62, 65], 1.9, level=0.07), 0.12, 0.3),
    ]
    for i, note in enumerate((76, 74, 72, 69)):
        parts.append((0.1 + i * 0.16, inst.vibes(note, 1.6, level=0.2), 0.28, 0.5))
    return _piece(2.8, parts, decay=2.2)


def roundover() -> np.ndarray:
    """A hand finished, with the points about to be counted."""
    rng = np.random.default_rng(13)
    parts = [
        (0.0, inst.brush(rng, 0.5, level=0.22), 0.0, 0.4),
        (0.02, inst.vibes(69, 1.6, level=0.26), -0.2, 0.5),
        (0.02, inst.vibes(76, 1.6, level=0.2), 0.2, 0.5),
        (0.0, inst.upright(45, 0.8, level=0.34, rng=rng), 0.0, 0.05),
    ]
    return _piece(1.9, parts, decay=1.8)
