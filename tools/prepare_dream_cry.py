"""Derive the quiet door-side cue from the attributed CC0 recording.

Requires numpy and soundfile. Original MP3 is retained unchanged beside output.
"""
from pathlib import Path
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.godot/audio-tools'))
import numpy as np
import soundfile as sf

directory = ROOT / 'assets/mirror_dream/audio'
source, rate = sf.read(directory / 'crying-woman-source.mp3')
mono = source.mean(axis=1) if source.ndim == 2 else source
mono = mono[:int(rate * 18)].copy()
# Smooth low-pass approximates a closed wooden door, without pitch shifting.
taps = 129
n = np.arange(taps) - (taps - 1) / 2
kernel = np.sinc(2 * 1700 / rate * n) * np.hamming(taps)
kernel /= kernel.sum()
filtered = np.convolve(mono, kernel, mode='same')
delay = int(rate * .085)
filtered[delay:] += .10 * filtered[:-delay].copy()
filtered -= filtered.mean()
filtered *= (10 ** (-7 / 20)) / max(np.abs(filtered).max(), 1e-8)
fade = int(rate * .7)
filtered[:fade] *= np.linspace(0, 1, fade)
filtered[-fade:] *= np.linspace(1, 0, fade)
# Slight pan to the room's door side; game gain adds further attenuation.
stereo = np.column_stack([filtered * .80, filtered])
with wave.open(str(directory / 'door-sobbing.wav'), 'wb') as out:
    out.setnchannels(2); out.setsampwidth(2); out.setframerate(rate)
    out.writeframes((stereo * 32767).astype('<i2').tobytes())
print(f'{len(filtered)/rate:.2f}s, {rate}Hz, peak {20*np.log10(np.abs(stereo).max()):.1f}dBFS')
