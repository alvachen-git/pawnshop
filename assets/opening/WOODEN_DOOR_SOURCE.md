# Wooden door opening

Source: [Creaky Door Slow 01](https://freesound.org/people/Rudmer_Rotteveel/sounds/590947/) by Rudmer_Rotteveel, published 2021-10-04; retrieved 2026-09-24.

License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The source page identifies this as a creaky door opening slowly and explicitly permits use without credit, including commercial use. Attribution is retained voluntarily.

Downloaded file: `wooden_door_source.mp3`, the publicly linked high-quality MP3 preview at https://cdn.freesound.org/previews/590/590947_4921277-hq.mp3 (not the original lossless WAV).

Game file: `wooden_door_open.wav`, decoded to 44.1 kHz, stereo, PCM16. Duration 1.770771 seconds. No pitch/time change, synthesis, layering, trimming or normalization. Existing runtime gain is -10 dB. Format conversion does not restore fidelity lost in the MP3 source.

Reproduce conversion:
```
ffmpeg -i assets/opening/wooden_door_source.mp3 -ar 44100 -c:a pcm_s16le assets/opening/wooden_door_open.wav
```

The previous procedural sound and its generator are retired under ignored `.artifacts/retired-door-synthesis/` and are no longer runtime sources. Click timing and the independent AudioStreamPlayer are unchanged.

This pass verifies provenance, decoding and Godot resource import; listening acceptance remains with the player.

SHA-256:
- `wooden_door_source.mp3`: `197e3ea25414032e5a2d728b6f0a83f3d0dfc7368504056a2d0cda0b7d5a3cb4`
- `wooden_door_open.wav`: `e8807b47c951470ee34f3b24218c732ef16bbd7b82cc520da98c8b318efbca3e`
