# Citizen sprite generation

Built-in image_gen. Source: artifacts/art04_concepts/05_paint_refined_v2.png.

Result: citizen.png is 1254x1254 RGB with magenta chroma background (corner 238,15,240), NOT an alpha PNG. Two real-alpha attempts returned baked checkerboard RGB and were not accepted for runtime. The final asset requires runtime chroma keying with tolerance for generated color variation. No image postprocessing was performed.

## Original prompt

Use case: background-extraction and identity-preserve.
Asset type: one production-ready transparent character sprite for a fixed counter 2D Godot game, Republican-era Shanghai pawnshop.
Input image 1 is the approved reference. Extract/reconstruct ONLY the central middle-aged male customer, preserving his identity, facial proportions, clothing, front-facing pose and resting hand. Remove everything else.
Subject: ordinary weathered working-class Shanghai man, tired believable face, short dark slightly unkempt hair, fine stubble, plain worn charcoal-gray traditional gown, natural anatomy, shoulders and upper torso with his bent right forearm and one resting hand at bottom. The crown of the head and both shoulder edges must be fully visible. The entire visible customer silhouette should be one clean cutout, terminating at a horizontal counterline below the hand.
Style: retain the approved restrained semi-realistic handpainted GOUACHE look, matte broad brush marks and simplified planar light, coarse worn cloth. Clearly a painted illustration rather than photographic detail. Plain, aged, everyday, no beauty glamor, no heroic features, no ornate decoration. Warm subdued skin and dark gray cloth with soft diffuse lighting.
Framing: nearly square canvas about 1024x1024; tight 2–4 percent transparent margin around the complete upper-body silhouette, subject nearly filling the canvas, body at bottom. This sprite will fit a 420x355 upper-center game slot.
Background: genuinely TRANSPARENT background with alpha=0 outside the silhouette. No checkerboard pattern drawn into image, no white background, no scenery, no furniture, no wood counter, no ground shadow, no frame, no words or UI, no object.
Invariants: same customer identity and original frontal pose as reference, not another character; same visible resting hand. Preserve the matte coarse semi-realistic gouache style. No ghost or magic effects. Deliver PNG with real transparent alpha.

## Alpha retry prompt

Use case: background-extraction.
Remove the baked checkerboard background from this image, making all background pixels genuinely transparent. Output must be RGBA PNG with a real alpha channel, fully transparent alpha=0 around the character. Do not paint a checkerboard or white/gray background. Preserve the character exactly: same identity, anatomy, pose, hand, dark gown, matte coarse gouache brushwork, complete crown and shoulders. Change only the background to actual transparency. Do not add any object, shadow, frame, text, floor, or scenery. Keep tight margin and square framing. This will be composited as a customer sprite into a game, so actual alpha is essential.

## Final chroma prompt

Use case: precise-object-edit. Edit the referenced customer sprite, change ONLY the background. Replace all checkerboard background with a totally flat uniformly saturated MAGENTA #FF00FF field. This is a chroma-key game asset, therefore no variation, gradients, texture, shading or other colors anywhere outside the man's silhouette. Preserve the man exactly: tired middle-aged Shanghai worker, same face, plain dark-gray gown, semi-realistic broad matte gouache brushwork, shoulders, crown, bent right forearm and visible hand, entire silhouette. No magenta tint or spill on the man. Keep square tight framing. No text, counter, props, shadow or floor. Uniform magenta backing is intentional.
