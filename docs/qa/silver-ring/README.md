# Silver ring tabletop revision — 2026-09-22

Replaces the oversized front-facing silver-ring placeholder with worn-silver artwork in a flat tabletop perspective. The release is isolated on remote main baseline `fc90ece`; unrelated local campaign changes are excluded.

The new RGBA artwork is `assets/art10/items/silver_ring_front.png`. It depicts a worn silver band lying flat with an elliptical opening and a close translucent contact shadow. The original alpha is preserved. The exact built-in image_gen prompt and source are in `assets/art10/items/SILVER_RING_SOURCE.md`.

The catalog upgrades only `goods.silver_ring` and its shipped `silver_ring_front.svg` reference. Explicit custom image paths retain precedence. Counter bounds reduce the visible width to approximately half its former size; the original larger hit target is retained. Appraisal and other consumers of the shared front-image resolver receive the same new artwork. Existing back and evidence illustrations remain unchanged. No item IDs, state, prices, clues, or save schemas were edited. Existing saved front paths resolve to the new artwork; no save migration is needed. A full old-save roundtrip was not run.

## Verification

`tests/silver_ring_art_ui.gd` uses a separate temporary save and a deterministic natural ring visit in the existing goods-expertise scene. The bootstrap reuses an untouched initial run, so the harness explicitly rebuilds it after selecting its seed. The legacy fixture does not always have a save library, so that path assignment is guarded.

- Godot 4.6.1 actual macOS OpenGL windows, 1280×720 and 1600×900: 59 assertions each, 0 failures (118 total); includes a check of the actual production display bounds before taking comparison screenshots.
- Captured before/after using the same live scene, state and customer, swapping only the old/new front texture and its display bounds for the comparison.
- Checked shared appraisal image, preserved custom paths, unchanged state when opening appraisal, and all three original appraisal actions revealing their clues.
- Resource import and `git diff --check` passed.
- No Windows build or full gameplay regression was run. This repository has no GitHub Actions workflow.

Screenshots in this directory use `ring_1280_` and `ring_1600_` prefixes. `after_counter` is the integrated result, `before_counter` the original asset at its original size; `item_silver_ring_front` and `item_silver_ring_evidence` show appraisal.

Reproduce from this checkout:

```sh
godot --path . --script res://tests/silver_ring_art_ui.gd --log-file /private/tmp/pawn-ring-1280.log
godot --path . --script res://tests/silver_ring_art_ui.gd --log-file /private/tmp/pawn-ring-1600.log -- wide
```

The existing player process was not closed or restarted. Save and relaunch the updated checkout to load the new asset and sizing code.
