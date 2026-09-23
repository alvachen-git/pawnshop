# Fountain pen back source

- Generator: built-in `image_gen` edit; no CLI fallback or manual pixel editing.
- Date: 2026-09-16.
- Input edit target: `assets/art09/items/fountain_pen_front.png`, viewed before editing.
- Destination: `assets/art09/items/fountain_pen_back.png`.
- Original generated output: `/Users/alvachen/.codex/generated_images/01a09106-c8b8-7291-ab43-99ddd950a3f5/exec-d6fdff42-88c9-4761-ae65-00266cb34b17.png`.
- Visual inspection: same capped diagonal pen, clip invisible, nib hidden, original silhouette and metal bands retained, muted charcoal/olive/amber gouache material, no added cracks, ink stains, brand, text, props or obvious halo.
- Scope: one back-side asset only; no code/test edits or runtime execution.
- Verified output: opaque RGB, 1536 × 1024. Non-magenta bounding box front (44,91,1502,908), back (45,91,1502,908); framing matches within one pixel under the same threshold.
- Generated magenta is approximate rather than bit-exact `#ff00ff`: dominant RGB (250,4,250); corners (237,14,241), (245,20,243), (235,37,238), (240,33,241). Existing shader tolerance is required.

## Exact prompt

```text
Use case: precise-object-edit.
Asset type: reverse-side inventory sprite, opaque RGB 1536x1024 PNG.
Input image is the exact fountain_pen_front.png EDIT TARGET. Produce the reverse side of this SAME capped 1930s celluloid fountain pen by rotating the pen 180 degrees around its OWN LONG AXIS ONLY.
Change only: show the back of the cap and barrel. The brass pocket clip is now entirely on the far hidden side, with NO visible clip, no clip tip, and no attachment marks on the visible surface. In the former clip area show uninterrupted dark charcoal, muted smoky olive and amber celluloid marbling matching the same material.
Strict invariants: preserve exact image dimensions 1536x1024, original pen length and width, silhouette, complete-object margins, lower-left to upper-right diagonal angle, object position and scale, rounded barrel end at lower-left, closed cap at upper-right, cap mouth seam and original slim metal band. Preserve the original cap finial contour and modest metal rim. Keep the pen securely capped so the nib remains completely hidden. This is NOT a horizontal image flip, NOT a change of direction, NOT an uncapped pen.
Preserve matte opaque semi-realistic gouache brushwork, painterly dark charcoal/olive/amber marbling palette, subdued old brass, modest small highlights. The reverse-side marbling should be the same material and color distribution without introducing new damage.
Background: perfectly flat solid pure magenta #ff00ff, no glow, no shadow, no vignette, no ground plane. Clean object-colored silhouette with no magenta spill or halo. Opaque RGB, no transparency.
Do not add cracks, ink stains, dents, brand names, lettering, symbols, nib, new metal fittings, duplicate objects, props, hands, table, box or watermark.
```
