"""Renders every sound the game makes into Scopa/Audio/.

    python3 Tools/SoundForge/forge.py [--only name ...]

Nothing here is recorded: the music and the sounds are built from the same
instruments, in numpy, so they share one room and one tuning. Every voice takes a
fixed seed, so re-running is deterministic and a change to one cannot move another.

The loops are Apple Lossless in CAF rather than AAC. An AAC file comes back from
the decoder with encoder padding on the front and a different length, and a loop
off by a few hundred samples ticks once every time round.
"""

import argparse
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))

import dsp  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "Scopa" / "Audio" / "Sounds"

LOOPS = {
    "music_lungomare": music.lungomare,
    "music_tavolo": music.tavolo,
}

ONE_SHOTS = {
    **sfx.CATALOGUE,
    "sfx_victory": music.victory,
    "sfx_defeat": music.defeat,
    "sfx_roundover": music.roundover,
}


def write_wav(path: Path, audio: np.ndarray) -> None:
    """16-bit, with a scrap of dither so the quiet tails of the bells do not step."""
    frames = audio if audio.ndim > 1 else audio[None, :]
    interleaved = frames.T.reshape(-1)
    noise = np.random.default_rng(0).triangular(-1.0, 0.0, 1.0, interleaved.shape) / 32768.0
    clipped = np.clip(interleaved + noise, -1.0, 1.0)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(frames.shape[0])
        out.setsampwidth(2)
        out.setframerate(dsp.SR)
        out.writeframes(struct.pack(f"<{len(clipped)}h", *np.round(clipped * 32767).astype(np.int32)))


def convert(source: Path, destination: Path, codec: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["afconvert", "-f", "caff", "-d", codec, str(source), str(destination)],
                   check=True, capture_output=True)


def forge(only: set[str] | None) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as scratch:
        for name, make in {**LOOPS, **ONE_SHOTS}.items():
            if only and name not in only:
                continue
            audio = make()
            staging = Path(scratch) / f"{name}.wav"
            write_wav(staging, audio)
            target = OUT / f"{name}.caf"
            convert(staging, target, "alac" if name in LOOPS else "LEI16@44100")
            channels = "stereo" if audio.ndim > 1 else "mono"
            print(f"{name:18} {audio.shape[-1] / dsp.SR:6.2f}s  {channels:6}"
                  f"  {target.stat().st_size / 1024:7.0f} kB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*", help="render only these, by file name")
    forge(set(parser.parse_args().only or []) or None)
