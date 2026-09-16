# Pawn hanging sign provenance

- Production asset: `pawn_hanging.png`
- Generation: built-in imagegen, 2026-09-15; original copied without resizing or pixel edits.
- Approved composition reference: `docs/qa/shop-hud/approved-reference.png`
- Final source: built-in ImageGen transparent extraction, copied unchanged into this directory.
- Dimensions: 1197 × 1314, genuine RGBA PNG. 995,728 fully transparent pixels. Alpha-positive bounds: x=33..1142, y=26..1303; alpha >=128 artwork bounds: x=125..1071, y=29..1229.
- Text: sole gold traditional character 當, matching the selected mock. No game title lettering.
- Content: dark oxblood diamond wood plaque, aged brass rim, short wall bracket and two short chains.
- Final extraction prompt: Extract this pawn sign from the background. TRANSPARENT BACKGROUND required. Remove the fake checkerboard background completely. This output is a production sprite and must have an alpha channel. Keep the bracket and red diamond sign with gold 當 unchanged. Output PNG with genuinely transparent surrounding empty area and transparent empty holes inside the bracket and rings.

Initial generation used the approved screenshot only as reference, asking for an isolated compact antique hanging sign with a blackened brass bracket, dark oxblood diamond wooden plaque, sole gold pawn character, no other objects or text, and transparent background. Two opaque intermediate generations were rejected; only the validated transparent extraction is included here.
