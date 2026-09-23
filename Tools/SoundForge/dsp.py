"""Oscillators, envelopes, filters and a room to put them in: everything the
instruments next door are built from. Nothing here knows about Scopa.

Everything is float64 mono at `SR` unless it says otherwise, and nothing is
normalised on the way through. Levels are set once, where the parts are mixed.
"""

import numpy as np

SR = 44100


# MARK: Time


def seconds(duration: float) -> int:
    """Samples in a span."""
    return int(round(duration * SR))


def silence(duration: float) -> np.ndarray:
    return np.zeros(seconds(duration))


def place(track: np.ndarray, signal: np.ndarray, at: float) -> None:
    """Mix a sound into a track at a moment, clipping whatever hangs off the end.

    It clips rather than grows because `wrap` folds a loop back onto itself and
    needs the overhang left where it is.
    """
    start = seconds(at)
    if start >= len(track) or start + len(signal) <= 0:
        return
    head = max(0, -start)
    start = max(0, start)
    end = min(start + len(signal) - head, len(track))
    track[start:end] += signal[head:head + (end - start)]


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


# MARK: Envelopes


def pluck(n: int, attack: float = 0.004, decay: float = 0.6, shape: float = 1.0) -> np.ndarray:
    """Struck and left to ring. `decay` is the time to −60 dB."""
    t = np.arange(n) / SR
    rise = np.clip(t / max(attack, 1e-6), 0.0, 1.0) ** shape
    return rise * np.exp(-t * (6.908 / max(decay, 1e-6)))


def swell(n: int, attack: float, hold: float, release: float) -> np.ndarray:
    """Blown rather than struck: in, held, out. Cosine edges, so no click."""
    t = np.arange(n) / SR
    env = np.ones(n)
    a = max(seconds(attack), 1)
    env[:a] = 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    r = max(seconds(release), 1)
    tail = min(r, n)
    env[n - tail:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(tail) / r)
    body = seconds(attack + hold)
    if body < n:
        env[body:] *= np.exp(-(t[body:] - t[body]) * 1.5)
    return env


def fade_in(x: np.ndarray, duration: float) -> np.ndarray:
    """Mono or stereo: the fade always runs along time, the last axis."""
    n = min(seconds(duration), x.shape[-1])
    if n > 1:
        x[..., :n] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)
    return x


def fade_out(x: np.ndarray, duration: float) -> np.ndarray:
    n = min(seconds(duration), x.shape[-1])
    if n > 1:
        x[..., x.shape[-1] - n:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(n) / n)
    return x


# MARK: Filters
#
# Filters are applied by convolving with their impulse response rather than by
# running the difference equation, which in Python is a million-step loop per track.


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    size = 1 << max(1, (len(x) + len(ir) - 2)).bit_length()
    spectrum = np.fft.rfft(x, size) * np.fft.rfft(ir, size)
    return np.fft.irfft(spectrum, size)[:len(x)]


def _biquad_ir(b0: float, b1: float, b2: float, a0: float, a1: float, a2: float,
               length: int = 4096) -> np.ndarray:
    """The filter's response to a single click, which is all convolution needs."""
    ir = np.zeros(length)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(length):
        x0 = 1.0 if i == 0 else 0.0
        y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x0
        y2, y1 = y1, y0
        ir[i] = y0
    return ir


_IR_CACHE: dict[tuple, np.ndarray] = {}


def _cached(kind: str, freq: float, q: float, gain: float = 0.0) -> np.ndarray:
    key = (kind, round(freq, 3), round(q, 4), round(gain, 3))
    if key not in _IR_CACHE:
        _IR_CACHE[key] = _design(kind, freq, q, gain)
    return _IR_CACHE[key]


def _design(kind: str, freq: float, q: float, gain: float) -> np.ndarray:
    w = 2.0 * np.pi * min(freq, SR * 0.45) / SR
    cw, sw = np.cos(w), np.sin(w)
    alpha = sw / (2.0 * q)
    if kind == "low":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "high":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "band":
        b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "peak":
        amp = 10.0 ** (gain / 40.0)
        b0, b1, b2 = 1 + alpha * amp, -2 * cw, 1 - alpha * amp
        a0, a1, a2 = 1 + alpha / amp, -2 * cw, 1 - alpha / amp
    else:
        raise ValueError(kind)
    return _biquad_ir(b0, b1, b2, a0, a1, a2)


def lowpass(x: np.ndarray, freq: float, q: float = 0.707) -> np.ndarray:
    return convolve(x, _cached("low", freq, q))


def highpass(x: np.ndarray, freq: float, q: float = 0.707) -> np.ndarray:
    return convolve(x, _cached("high", freq, q))


def bandpass(x: np.ndarray, freq: float, q: float = 1.0) -> np.ndarray:
    return convolve(x, _cached("band", freq, q))


def peak(x: np.ndarray, freq: float, gain: float, q: float = 1.0) -> np.ndarray:
    return convolve(x, _cached("peak", freq, q, gain))


# MARK: Delay lines
#
# A feedback comb depends on itself a whole delay ago, so a block one delay long
# can be written in one go from the block before it.


def comb(x: np.ndarray, delay: int, feedback: float) -> np.ndarray:
    y = x.astype(np.float64, copy=True)
    for i in range(delay, len(y), delay):
        end = min(i + delay, len(y))
        y[i:end] += feedback * y[i - delay:end - delay]
    return y


def allpass(x: np.ndarray, delay: int, feedback: float) -> np.ndarray:
    y = -feedback * x
    y[delay:] += x[:-delay]
    for i in range(delay, len(y), delay):
        end = min(i + delay, len(y))
        y[i:end] += feedback * y[i - delay:end - delay]
    return y


_COMBS = (1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617)
_ALLPASS = (556, 441, 341, 225)


def room(x: np.ndarray, decay: float = 1.8, damping: float = 4200.0,
         predelay: float = 0.018, spread: int = 23) -> np.ndarray:
    """A stereo plate: eight combs into four allpasses, the plain Schroeder
    arrangement. Damping is taken off the send rather than inside each comb's
    loop, which keeps the whole thing vector arithmetic.
    """
    send = lowpass(highpass(x, 180.0), damping)
    lead = seconds(predelay)
    if lead:
        send = np.concatenate([np.zeros(lead), send])[:len(x)]
    sides = []
    for offset in (0, spread):
        wet = np.zeros(len(send))
        for delay in _COMBS:
            d = delay + offset
            wet += comb(send, d, 10.0 ** (-3.0 * d / (SR * decay)))
        wet /= len(_COMBS)
        for delay in _ALLPASS:
            wet = allpass(wet, delay + offset, 0.5)
        sides.append(wet)
    return np.stack(sides)


# MARK: Stereo


def pan(x: np.ndarray, position: float) -> np.ndarray:
    """Equal power, −1 left to +1 right."""
    angle = (np.clip(position, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(angle), x * np.sin(angle)])


def widen(stereo: np.ndarray, delay: float = 0.011, level: float = 0.5) -> np.ndarray:
    """A hair of Haas: one side arrives late and quieter, and the pair opens out."""
    lag = seconds(delay)
    out = stereo.copy()
    out[1, lag:] += level * stereo[0, :-lag]
    out[0, lag:] += level * stereo[1, :-lag]
    return out


def chorus(x: np.ndarray, rate: float = 0.55, depth: float = 0.006, mix: float = 0.35) -> np.ndarray:
    t = np.arange(len(x)) / SR
    lag = depth * SR * (0.55 + 0.45 * np.sin(2.0 * np.pi * rate * t))
    index = np.arange(len(x)) - lag
    wet = np.interp(index, np.arange(len(x)), x, left=0.0)
    return (1.0 - mix) * x + mix * wet


# MARK: The end of the chain


def saturate(x: np.ndarray, drive: float = 1.6) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def compress(x: np.ndarray, threshold: float = -14.0, ratio: float = 3.0,
             smoothing: float = 0.05) -> np.ndarray:
    """One smoothed envelope, with the gain taken from it."""
    kernel = np.exp(-np.arange(seconds(smoothing * 4)) / max(seconds(smoothing), 1))
    kernel /= kernel.sum()
    level = np.sqrt(np.maximum(convolve(np.mean(x ** 2, axis=0) if x.ndim > 1 else x ** 2, kernel), 1e-12))
    over = 20.0 * np.log10(np.maximum(level, 1e-9)) - threshold
    reduction = np.where(over > 0.0, over * (1.0 / ratio - 1.0), 0.0)
    gain = 10.0 ** (reduction / 20.0)
    return x * (gain if x.ndim == 1 else gain[None, :])


def trim(x: np.ndarray, peak_level: float = 0.89) -> np.ndarray:
    """Scale so the loudest moment sits at `peak_level`."""
    top = float(np.max(np.abs(x)))
    return x if top < 1e-9 else x * (peak_level / top)


def wrap(x: np.ndarray, length: int) -> np.ndarray:
    """Fold the overhang of a loop back onto its own start, so the tail of the last
    bar is already sounding under the first and the seam is inaudible.
    """
    out = x[..., :length].copy()
    overhang = x[..., length:]
    span = min(overhang.shape[-1], length)
    if span > 0:
        out[..., :span] += overhang[..., :span]
    return out
