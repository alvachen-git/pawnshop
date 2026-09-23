# Fountain pen front source

- Generator: built-in `image_gen`; no CLI fallback or manual pixel editing.
- Date: 2026-09-15.
- Style references inspected: `assets/art04/items/hairpin_front.png` and `assets/art06/items/holder_front.png`.
- Destination: `assets/art09/items/fountain_pen_front.png`.
- Original generated output: `/Users/alvachen/.codex/generated_images/01a09106-c8b8-7291-ab43-99ddd950a3f5/exec-6bf000c8-8777-4697-8e79-e78078af48f2.png`.
- Visual inspection: one capped pen, hidden nib, charcoal/olive/amber painted marbling, single plain brass clip, complete silhouette from lower-left to upper-right, clean margins; no props, text, shadow, or obvious halo.
- Scope: one asset only; no code/test edits or runtime execution.
- Verified output: opaque RGB, 1536 × 1024. Generated magenta is approximate rather than bit-exact `#ff00ff`: dominant RGB (252,3,251); corners (239,12,242), (247,19,244), (237,34,240), (242,30,240). Existing shader tolerance is required.

## Exact prompt

```text
Use case: historical-scene.
Asset type: isolated inventory item sprite for a 1930s Shanghai pawnshop game, wide 1536x1024 opaque PNG.
Input images: hairpin_front.png and holder_front.png are STYLE REFERENCES ONLY for painted material texture and substantial gouache brushwork; do not copy their background, glow, objects or layout.
Primary request: ONE imported 1930s celluloid fountain pen, securely CAPPED. A dark charcoal barrel with smoky muted olive and amber marbling. Matching closed cap at the upper-right end with exactly ONE simple plain aged-brass pocket clip and ONE slim brass cap band. The lower-left barrel end is gently rounded. Unbranded, modestly worn, no lettering or logos. The nib is entirely hidden inside the closed cap; no separate cap, no exposed tip, no ink.
Composition: entire pen diagonally from lower-left to upper-right, a clear three-quarter product-object view without photographic staging. Pen silhouette spans about 85 percent of canvas width, with comfortable complete-object margins at both ends. Use a convincingly robust vintage pen with a broad enough barrel to read clearly when image is displayed around 200x130 pixels. All object edges contained. No other objects.
Style/medium: matte opaque semi-realistic gouache, broad irregular painted patches, tactile restrained painterly texture, simplified natural worn material planes, small subdued highlights. Dark umber, smoky olive, charcoal and amber with muted old brass. Match the two references' painterly realism. Not glossy product photography, not vector, not 3D render.
Background: absolutely flat solid pure MAGENTA #ff00ff across all empty pixels, for an existing chroma-key shader. Opaque RGB image. Crisp clean silhouette with natural object-colored edges. No ground plane, no cast shadow, no vignette, no glow or halo, no magenta reflections on the pen.
Avoid: table, paper, hands, box, ink bottle, books, scenery, captions, typography, branding, watermark, glowing outlines, exposed nib, duplicate pen, transparent or checkerboard background.
```
