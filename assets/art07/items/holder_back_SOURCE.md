# Holder underside generation provenance

- Tool: built-in `image_gen.imagegen` only.
- Reference: `assets/art06/items/holder_front.png` (inspected before generation).
- Candidate: `holder_back_candidate.png`.
- Generated source: `/Users/alvachen/.codex/generated_images/01a09017-9ae4-7133-8488-0261275cc69c/exec-a1ebf4f6-1afa-4349-a774-c03de3ac00b6.png`.
- Status: **REJECTED FOR INTEGRATION**. Both initial generation and targeted correction returned RGB with a painted checkerboard rather than true alpha transparency. Candidate kept for review only; do not point game resources at it.
- Read-only PIL validation: RGB, 1536 × 1024; no alpha channel. No Python or other pixel editing performed.
- Visual review: exact type of brass candlestick shown from underside, stepped circular foot and central brass fastener, muted ochre/olive painted finish, no diagnostic scratches or exposed iron, no text, fully framed. Corrected candidate height approximately 80% of canvas.

## Initial prompt

Use case: stylized-concept
Asset type: one transparent PNG game inventory item sprite, landscape 1536x1024.
Input image 1: identity and painted material/style reference for the exact brass candlestick; do NOT preserve its surrounding glow or background.
Primary request: show the underside of this exact same plain brass candlestick, turned over toward the viewer. Its broad circular stepped foot is the main visible part, angled slightly in 3D so the underside is clearly readable; the foot has a dark concentric recessed underside with one simple central brass fastener. A little of the same turned stem may show behind the foot, without hiding the underside. Preserve the reference object's proportions, stepped foot shape, subdued aged brass finish and handmade painterly realism. This is an ordinary non-diagnostic underside shared by both solid brass and plated hidden game variants, visually identical between them.
Style/medium: muted gouache illustration, restrained ochre and olive brass tones, softly rough painted metal, warm light from upper right.
Composition: single centered item, whole object fully inside frame with comfortable padding, occupies about 75 percent of canvas height. No crop.
Background: genuine alpha transparency, all empty space fully transparent. Clean cutout without surrounding glow, shadow, vignette, haze or scene. Do not paint a checkerboard.
Constraints: only one candlestick. No diagnostic scratches, no exposed iron or silvery core, no inscriptions or text, no labels, no watermark, no diagram arrows, no additional objects.

## Targeted correction prompt

Use case: background-extraction. Edit target: attached brass candlestick underside sprite. Preserve this exact candlestick, its geometry, angle, ochre/olive gouache finish, plain concentric underside and central brass fastener. Make only the following production cleanup: REMOVE THE ENTIRE PAINTED CHECKERBOARD BACKGROUND and provide real PNG ALPHA TRANSPARENCY; no replacement color, no checkerboard pixels, no shadows or glow. All background pixels must have alpha=0. The file must be RGBA with actual transparent pixels. Also reduce the object uniformly, centered, so its full height spans about 75% of the 1024-pixel-high canvas with about 128px top/bottom padding. Canvas stays landscape 1536x1024. No additions, no text, no diagnostic scratches, no metal core reveal. Transparent isolated game asset.

## Final production version: magenta key background

- Final asset: `holder_back.png`.
- Generated source: `/Users/alvachen/.codex/generated_images/01a09017-9ae4-7133-8488-0261275cc69c/exec-18ab8c1e-0383-4f27-bd40-d6343e1dc372.png`.
- Workflow updated by parent: use opaque magenta background with runtime chroma-key shader; actual alpha is no longer required. Earlier candidate rejection applies only to the checkerboard version.
- Output visually inspected: uniform saturated magenta backdrop, no checkerboard/gradient/shadow; candlestick underside angle and geometry retained. No code modified.
- Read-only PIL validation: RGB, 1536 × 1024. Generated magenta is visually flat but not numerically exact `#ff00ff`: dominant pixel `(250, 3, 250)`, corners `(238,13,242)`, `(246,18,244)`, `(235,35,237)`, `(241,30,240)`. Runtime keying should allow color-distance tolerance; no pixel postprocessing was performed.

### Final edit prompt

Use case: precise-object-edit. Edit the attached game item sprite. Change ONLY its background: replace the entire gray-and-white checkerboard with perfectly flat uniform solid RGB(255,0,255), hexadecimal #ff00ff, saturated chroma-key MAGENTA. Every empty background pixel must be solid magenta. Background must have absolutely no checkerboard, gradient, shadow, vignette, glow, mottling, texture, pattern or decorations. Preserve the exact existing brass candlestick underside silhouette, 3D angle, concentric recessed foot and central brass fastener, warm upper-right lighting, all object material and muted ochre/olive gouache detail. Do not color or tint the object magenta. Keep the same full object scale, centered placement and landscape 1536x1024 canvas. No alpha transparency is required; output an RGB PNG with a solid magenta background. No text or additional objects.
