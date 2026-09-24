"""Render a real Pingtan recording as a quiet, continuously looping AM radio.

Usage: python3 tools/create_shop_radio_audio.py /path/to/Pingtan_Treasure.ogg
Requires ffmpeg. Source, attribution and release caveat: assets/audio/radio/README.md.
No speech synthesis or generated melody is used.
"""

import argparse
import array
import hashlib
import math
from pathlib import Path
import subprocess
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
START_SILENCE_SECONDS = 5
START_FADE_SECONDS = 1
SOURCE_SHA1 = "08a03f47a3c4fdcff8f434b3c964384dbd9e984a"


def write_wav(path, samples):
    pcm = array.array("h", (round(max(-.99, min(.99, x)) * 32767) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def render(source):
    if hashlib.sha1(source.read_bytes()).hexdigest() != SOURCE_SHA1:
        raise ValueError("Unexpected source recording; check the provenance before replacing it")
    # Preserve a long performance passage; avoid frequent cuts or invented tune fragments.
    filters = (
        "highpass=f=420,lowpass=f=2450,"
        "equalizer=f=1250:t=q:w=1.2:g=3.5,"
        "equalizer=f=2300:t=q:w=1:g=-3,"
        "acompressor=threshold=0.10:ratio=2:attack=12:release=180:makeup=1.25,"
        "aecho=0.95:1:38:0.06,"
        "loudnorm=I=-18:TP=-3:LRA=6"
    )
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", "3.5", "-i", str(source), "-t", "154",
        "-vn", "-ac", "1", "-af", filters, "-ar", str(RATE), "-f", "s16le", "pipe:1",
    ])
    pcm = array.array("h", raw)
    if sys.byteorder != "little":
        pcm.byteswap()
    samples = [x / 32768.0 for x in pcm]
    # Four-second tail/head overlap makes the loop boundary continuous.
    overlap = 4 * RATE
    body = samples[overlap:-overlap]
    seam = []
    for i in range(overlap):
        alpha = .5 - .5 * math.cos(math.pi * i / (overlap - 1))
        seam.append(samples[-overlap + i] * (1 - alpha) + samples[i] * alpha)
    samples = body + seam
    duration = len(samples) / RATE
    output = []
    for i, sample in enumerate(samples):
        t = i / RATE
        # Keep the narrow speaker tone and slow reception movement, without added noise.
        reception = .91 + .06 * math.sin(2 * math.pi * 5 * t / duration)
        reception += .03 * math.sin(2 * math.pi * 13 * t / duration)
        voice = math.tanh(sample * 2.2) / 1.9 * reception
        output.append(voice)
    destination = ROOT / "assets/audio/radio"
    destination.mkdir(parents=True, exist_ok=True)
    # Play this lead-in only on a fresh start; Godot loops from second 6 onward.
    intro = output[-START_FADE_SECONDS * RATE:]
    for i in range(len(intro)):
        intro[i] *= .5 - .5 * math.cos(math.pi * i / (len(intro) - 1))
    programme = [0.0] * (START_SILENCE_SECONDS * RATE) + intro + output
    write_wav(destination / "programme.wav", programme)
    preview_dir = ROOT / ".artifacts/radio-audio"
    preview_dir.mkdir(parents=True, exist_ok=True)
    # Preview at an easily audible level. The game applies its existing -14 dB BGM gain.
    preview = programme[:45 * RATE]
    for i in range(len(preview)):
        preview[i] *= min(1, (len(preview) - i) / RATE)
    write_wav(preview_dir / "pingtan_radio_clean_preview.wav", preview)
    print(f"Rendered 5s silence + 1s fade-in + {duration:.1f}s radio loop; 45s preview.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    render(parser.parse_args().source)
