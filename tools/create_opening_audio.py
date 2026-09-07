"""Small synthesized placeholder foley; no external recordings or dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

out = Path(__file__).resolve().parents[1] / "assets" / "opening"
rate = 22050
rng = random.Random(7)
for name, length, pitch, decay in [("paper", .24, 900, 18), ("key", .55, 1900, 9), ("door", .48, 130, 9), ("clock", .7, 620, 6), ("stamp", .18, 100, 35), ("floor", .3, 80, 15), ("factory", 1.0, 65, 0)]:
    samples = bytearray()
    for n in range(int(rate * length)):
        t = n / rate
        envelope = math.exp(-decay * t) * min(1, t / .004)
        noise = rng.uniform(-1, 1)
        tone = math.sin(2 * math.pi * pitch * t)
        if name == "factory":
            pulse = math.exp(-45 * (t % .25))
            value = .1 * tone + .2 * noise * pulse
        elif name in ("key", "clock"):
            value = .23 * (tone + .5 * math.sin(2 * math.pi * pitch * 2.71 * t)) * envelope
        else:
            value = (.45 * noise + .35 * tone) * envelope
        samples.extend(struct.pack("<h", int(max(-1, min(1, value)) * 20000)))
    with wave.open(str(out / (name + ".wav")), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(rate)
        sound.writeframes(samples)
