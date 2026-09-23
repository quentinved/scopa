"""The band, and the things on the table that are not instruments: a nylon guitar,
an upright bass, a vibraphone, a pad, an accordion, brushes and shakers, and the
cards, built from the same parts as the music so they sit in one world.

Every voice returns dry mono. Where it sits in the room is decided at the mix.
"""

import numpy as np

import dsp
from dsp import SR


# MARK: Strings


def _string(freq: float, n: int, damping: float, softness: int,
            rng: np.random.Generator) -> np.ndarray:
    """A plucked string: Karplus-Strong, noise trapped in a loop one period long.

    Written a block at a time: the loop reads itself a whole period back, so a
    period of output can be produced in one stroke.
    """
    period = max(int(round(SR / freq)), 3)
    excitation = rng.uniform(-1.0, 1.0, period)
    if softness > 1:
        excitation = np.convolve(excitation, np.ones(softness) / softness, mode="same")
    # One sample of headroom at the front stands in for "the sample before the start".
    y = np.zeros(n + 1)
    y[1:period + 1] = excitation
    block = max(period - 1, 1)
    i = period + 1
    while i <= n:
        end = min(i + block, n + 1)
        y[i:end] = damping * 0.5 * (y[i - period:end - period] + y[i - period - 1:end - period - 1])
        i = end
    return y[1:]


def nylon(note: float, duration: float, level: float = 1.0,
          rng: np.random.Generator | None = None) -> np.ndarray:
    """Gut strings on a small-bodied guitar. Warm, quick to soften, no fret buzz."""
    rng = rng or np.random.default_rng()
    n = dsp.seconds(duration)
    freq = dsp.midi_hz(note)
    tone = _string(freq, n, damping=0.9955, softness=5, rng=rng)
    tone *= dsp.pluck(n, attack=0.002, decay=duration * 0.85)
    body = dsp.peak(dsp.peak(tone, 210.0, 4.0, q=1.1), 430.0, 2.5, q=1.4)
    return level * dsp.lowpass(body, 4200.0)


def strum(notes: list[float], duration: float, level: float = 1.0, spread: float = 0.011,
          down: bool = True, rng: np.random.Generator | None = None) -> np.ndarray:
    """Strings one after the other across a few milliseconds. Upstrokes run the
    other way and come out a touch lighter.
    """
    rng = rng or np.random.default_rng()
    order = list(notes) if down else list(reversed(notes))
    out = dsp.silence(duration + 0.4)
    for i, note in enumerate(order):
        voice = nylon(note, duration + 0.3, rng=rng)
        weight = 1.0 - 0.12 * i if down else 0.82 - 0.1 * i
        dsp.place(out, voice * weight, i * spread)
    return level * out


def upright(note: float, duration: float, level: float = 1.0,
            rng: np.random.Generator | None = None) -> np.ndarray:
    """The bass. Additive rather than modelled: a string this long goes woolly, and
    the mix needs a clear root from it."""
    rng = rng or np.random.default_rng()
    n = dsp.seconds(duration + 0.25)
    t = np.arange(n) / SR
    freq = dsp.midi_hz(note)
    tone = np.sin(2.0 * np.pi * freq * t) * dsp.pluck(n, 0.006, duration * 0.9)
    tone += 0.34 * np.sin(2.0 * np.pi * freq * 2 * t) * dsp.pluck(n, 0.004, duration * 0.35)
    tone += 0.12 * np.sin(2.0 * np.pi * freq * 3 * t) * dsp.pluck(n, 0.003, duration * 0.2)
    # The finger leaving the string.
    tone += 0.16 * dsp.bandpass(rng.uniform(-1, 1, n), 1500.0, 0.9) * dsp.pluck(n, 0.001, 0.035)
    return level * dsp.lowpass(dsp.saturate(tone, 1.3), 2600.0)


# MARK: Struck metal


def vibes(note: float, duration: float, level: float = 1.0, tremolo: float = 0.22) -> np.ndarray:
    """A vibraphone bar with the motor running. Three partials, the upper two
    short, and the slow wobble that gives the instrument its name."""
    n = dsp.seconds(duration)
    t = np.arange(n) / SR
    freq = dsp.midi_hz(note)
    tone = np.sin(2.0 * np.pi * freq * t) * dsp.pluck(n, 0.003, duration * 0.85)
    tone += 0.30 * np.sin(2.0 * np.pi * freq * 3.98 * t) * dsp.pluck(n, 0.002, duration * 0.22)
    tone += 0.10 * np.sin(2.0 * np.pi * freq * 10.7 * t) * dsp.pluck(n, 0.001, duration * 0.09)
    tone *= 1.0 - tremolo * (0.5 - 0.5 * np.cos(2.0 * np.pi * 4.7 * t))
    return level * dsp.lowpass(tone, 9000.0)


def bell(freq: float, duration: float, level: float = 1.0, strike: float = 0.5) -> np.ndarray:
    """Inharmonic partials, a bright strike and a long tail. The seven of coins and
    the denari are both built on it.
    """
    n = dsp.seconds(duration)
    t = np.arange(n) / SR
    tone = np.zeros(n)
    for ratio, weight, decay in ((1.0, 1.0, 1.0), (2.76, 0.55, 0.62), (5.40, 0.30, 0.34),
                                 (8.93, 0.16, 0.2), (13.3, 0.07, 0.12)):
        if freq * ratio > SR * 0.45:
            continue
        tone += weight * np.sin(2.0 * np.pi * freq * ratio * t) * dsp.pluck(n, 0.001, duration * decay)
    tone += strike * 0.28 * dsp.highpass(np.random.default_rng(int(freq)).uniform(-1, 1, n), 5000.0) \
        * dsp.pluck(n, 0.0005, 0.012)
    return level * tone


# MARK: Air


def pad(notes: list[float], duration: float, level: float = 1.0, detune: float = 0.16) -> np.ndarray:
    """Three detuned voices per note, filtered well down, to hold the chord together."""
    n = dsp.seconds(duration)
    t = np.arange(n) / SR
    tone = np.zeros(n)
    for note in notes:
        for offset, weight in ((-detune, 0.5), (0.0, 0.6), (detune, 0.5)):
            freq = dsp.midi_hz(note + offset)
            for harmonic in range(1, 9):
                if freq * harmonic > SR * 0.45:
                    break
                phase = (note * 7 + harmonic * 3 + offset * 11) % (2.0 * np.pi)
                tone += (weight / harmonic ** 1.35) * np.sin(2.0 * np.pi * freq * harmonic * t + phase)
    tone /= max(len(notes), 1)
    return level * dsp.chorus(dsp.lowpass(tone, 1500.0, q=0.8), rate=0.24, depth=0.008, mix=0.3)


def accordion(notes: list[float], duration: float, level: float = 1.0) -> np.ndarray:
    """Reeds and bellows, used when a game is won. Odd harmonics, two ranks a beat
    apart in tuning, and a slow vibrato."""
    n = dsp.seconds(duration)
    t = np.arange(n) / SR
    vibrato = 1.0 + 0.004 * np.sin(2.0 * np.pi * 5.4 * t)
    tone = np.zeros(n)
    for note in notes:
        for offset in (-0.09, 0.09):
            freq = dsp.midi_hz(note + offset)
            for harmonic in range(1, 13):
                if freq * harmonic > SR * 0.45:
                    break
                weight = 1.0 / harmonic ** 1.1 * (1.0 if harmonic % 2 else 0.45)
                tone += weight * np.sin(2.0 * np.pi * freq * harmonic * np.cumsum(vibrato) / SR)
    tone /= max(len(notes), 1)
    voiced = dsp.peak(dsp.peak(tone, 720.0, 5.0, q=1.2), 1600.0, 3.0, q=1.5)
    return level * dsp.lowpass(voiced, 5200.0)


# MARK: Brushes and skins


def shaker(rng: np.random.Generator, level: float = 1.0, decay: float = 0.042) -> np.ndarray:
    n = dsp.seconds(0.16)
    grain = rng.uniform(-1, 1, n) * dsp.pluck(n, 0.0015, decay)
    return level * (dsp.highpass(grain, 4200.0) + 0.5 * dsp.bandpass(grain, 7600.0, 1.4))


def brush(rng: np.random.Generator, duration: float = 0.34, level: float = 1.0) -> np.ndarray:
    n = dsp.seconds(duration)
    grain = rng.uniform(-1, 1, n) * dsp.swell(n, duration * 0.35, duration * 0.1, duration * 0.5)
    return level * dsp.bandpass(grain, 2600.0, 0.55)


def rim(rng: np.random.Generator, level: float = 1.0) -> np.ndarray:
    n = dsp.seconds(0.12)
    t = np.arange(n) / SR
    click = dsp.bandpass(rng.uniform(-1, 1, n), 1900.0, 2.6) * dsp.pluck(n, 0.0004, 0.02)
    wood = 0.5 * np.sin(2.0 * np.pi * 330.0 * t) * dsp.pluck(n, 0.0006, 0.035)
    return level * (click + wood)


def tom(low: float, high: float, duration: float = 0.4, level: float = 1.0) -> np.ndarray:
    """A drum falling in pitch as it decays."""
    n = dsp.seconds(duration)
    t = np.arange(n) / SR
    sweep = high * (low / high) ** np.clip(t / (duration * 0.45), 0.0, 1.0)
    tone = np.sin(2.0 * np.pi * np.cumsum(sweep) / SR) * dsp.pluck(n, 0.001, duration * 0.55)
    skin = 0.2 * dsp.lowpass(np.random.default_rng(7).uniform(-1, 1, n), 900.0) * dsp.pluck(n, 0.001, 0.05)
    return level * dsp.saturate(tone + skin, 1.4)


# MARK: Paper
#
# A card is a short band of noise with a body under it, not a click. Dealing,
# playing and sweeping differ only in how many there are and how fast they follow.


def flick(rng: np.random.Generator, level: float = 1.0, decay: float = 0.055,
          colour: float = 3200.0) -> np.ndarray:
    """One card leaving a hand or sliding across another."""
    n = dsp.seconds(0.22)
    grain = rng.uniform(-1, 1, n) * dsp.pluck(n, 0.0012, decay, shape=0.7)
    return level * (dsp.bandpass(grain, colour, 0.75) + 0.35 * dsp.highpass(grain, 6000.0))


def land(rng: np.random.Generator, level: float = 1.0, weight: float = 1.0) -> np.ndarray:
    """A card coming to rest on cloth: a slap with almost no ring under it."""
    n = dsp.seconds(0.3)
    t = np.arange(n) / SR
    slap = dsp.bandpass(rng.uniform(-1, 1, n), 1400.0, 0.6) * dsp.pluck(n, 0.0008, 0.03)
    felt = weight * 0.5 * np.sin(2.0 * np.pi * 132.0 * t) * dsp.pluck(n, 0.001, 0.045)
    return level * dsp.lowpass(slap + felt, 7000.0)


def coin(rng: np.random.Generator, level: float = 1.0, freq: float = 2150.0) -> np.ndarray:
    """A denaro. Struck partials that do not agree, which is what makes it metal."""
    n = dsp.seconds(0.5)
    t = np.arange(n) / SR
    tone = np.sin(2.0 * np.pi * freq * t) * dsp.pluck(n, 0.0004, 0.28)
    tone += 0.6 * np.sin(2.0 * np.pi * freq * 1.51 * t) * dsp.pluck(n, 0.0004, 0.19)
    tone += 0.3 * np.sin(2.0 * np.pi * freq * 2.33 * t) * dsp.pluck(n, 0.0004, 0.1)
    tick = 0.4 * dsp.highpass(rng.uniform(-1, 1, n), 4000.0) * dsp.pluck(n, 0.0003, 0.006)
    return level * (tone + tick)


def sweepnoise(rng: np.random.Generator, duration: float, start: float, end: float,
               level: float = 1.0) -> np.ndarray:
    """Noise whose colour travels: a hand through air, or across felt. Two fixed
    bands crossfaded, since a filter that really moves costs a per-sample loop.
    """
    n = dsp.seconds(duration)
    grain = rng.uniform(-1, 1, n) * dsp.swell(n, duration * 0.3, duration * 0.15, duration * 0.55)
    blend = np.linspace(0.0, 1.0, n) ** 1.4
    return level * ((1.0 - blend) * dsp.bandpass(grain, start, 0.7) + blend * dsp.bandpass(grain, end, 0.7))
