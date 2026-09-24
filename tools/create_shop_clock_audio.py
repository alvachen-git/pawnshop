"""Generate a slow clock with detuned room resonance, without external recordings."""

import math
import random
import struct
import wave
from pathlib import Path


RATE = 44100
LOOP_SECONDS = 48
TICK_INTERVAL_SECONDS = 3
ROOM_SWELL_SECONDS = 16
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/shop_clock_loop.wav"


def build_loop():
    samples = [0.0] * (RATE * LOOP_SECONDS)
    rng = random.Random(2200)
    # Frequencies and modulation complete whole cycles in the loop. This keeps
    # the quiet, slightly dissonant room tone continuous across the loop seam.
    for frame in range(len(samples)):
        t = frame / RATE
        swell = 0.78 + 0.22 * math.cos(2 * math.pi * t / ROOM_SWELL_SECONDS)
        samples[frame] = swell * sum(
            gain * math.sin(2 * math.pi * frequency * t + phase)
            for frequency, gain, phase in (
                (73.0, 0.012, 0.0),
                (76.125, 0.009, 0.7),
                (109.5, 0.005, 1.1),
                (146.4375, 0.0035, 0.4),
            )
        )
    for beat in range(LOOP_SECONDS // TICK_INTERVAL_SECONDS):
        pitch = (0.90, 0.74)[beat % 2]
        start = beat * TICK_INTERVAL_SECONDS * RATE
        # A muted escapement impact and wooden case resonance, every three seconds.
        filtered_noise = 0.0
        for frame in range(int(RATE * 0.18)):
            t = frame / RATE
            filtered_noise += 0.18 * (rng.uniform(-1.0, 1.0) - filtered_noise)
            attack = min(1.0, t / 0.001)
            tail = min(1.0, (0.18 - t) / 0.025)
            impact = filtered_noise * math.exp(-t / 0.007) * 1.8
            body = sum(
                gain * math.sin(2 * math.pi * frequency * pitch * t) * math.exp(-t / decay)
                for frequency, gain, decay in (
                    (410, 0.42, 0.020),
                    (1130, 0.24, 0.012),
                    (2370, 0.06, 0.004),
                )
            )
            rebound = 0.0
            if t >= 0.013:
                rt = t - 0.013
                rebound = 0.13 * math.sin(2 * math.pi * 770 * pitch * rt) * math.exp(-rt / 0.010)
            samples[start + frame] += (impact + body + rebound) * attack * tail
        # A diffuse, delayed wooden resonance; no extra attacks between ticks.
        for frame in range(int(RATE * 1.65)):
            t = frame / RATE
            envelope = (1 - math.exp(-t / 0.14)) * math.exp(-t / 0.38)
            envelope *= min(1.0, (1.65 - t) / 0.25)
            resonance = (
                0.035 * math.sin(2 * math.pi * 173 * pitch * t)
                + 0.025 * math.sin(2 * math.pi * 181 * pitch * t)
                + 0.010 * math.sin(2 * math.pi * 347 * pitch * t)
            )
            samples[start + frame] += envelope * resonance
    # Remove DC before scaling, preserving the quiet ambience under the ticks.
    mean = sum(samples) / len(samples)
    samples = [value - mean for value in samples]
    peak = max(abs(value) for value in samples)
    return b"".join(struct.pack("<h", round(value / peak * 0.72 * 32767)) for value in samples)


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(RATE)
        sound.writeframes(build_loop())
    print(OUTPUT)


if __name__ == "__main__":
    main()
