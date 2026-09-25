"""Edit the CC0 Contax 1935 recording into game sounds; no synthesis.

Source: animationIsaac, Freesound 234118. See audio/SOURCE.md for provenance.
Requires numpy and soundfile in the build environment only.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.godot/audio-deps'))
import numpy as np
import soundfile as sf

DEST = ROOT / 'assets/camera_desk/audio'
source, rate = sf.read(DEST / 'source/contax1935_animationIsaac_234118.mp3')
assert rate == 48000
source = source.mean(axis=1) if source.ndim == 2 else source


def excerpt(start, end):
    samples = source[round(start * rate):round(end * rate)].copy() * .80
    # Edge fades only; preserve recorded pitch and internal timing.
    edge, tail = round(.002 * rate), round(.008 * rate)
    samples[:edge] *= np.linspace(0, 1, edge)
    samples[-tail:] *= np.linspace(1, 0, tail)
    return samples


def write(name, samples):
    peak = float(np.max(np.abs(samples)))
    assert 0 < peak < .98, (name, peak)
    sf.write(DEST / name, samples, rate, subtype='PCM_16')
    print(name, 'seconds', round(len(samples) / rate, 3), 'peak', round(peak, 3))


# Two intact exposures from the author's different-speed recording.
fast = excerpt(15.125, 15.365)
slow = excerpt(21.815, 22.320)
write('recorded_fast.wav', fast)
write('recorded_slow.wav', slow)

# Fault illustrations are editorial effects, not real fault recordings.
for name, samples in [('fast', fast), ('slow', slow)]:
    delayed = np.zeros(round(.8 * rate) + len(samples))
    press = excerpt(21.815, 21.856) * .45
    delayed[:len(press)] = press
    delayed[round(.8 * rate):] = samples
    write('recorded_sticky_' + name + '.wav', delayed)
write('recorded_jam.wav', excerpt(21.815, 21.912))
