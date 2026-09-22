# Neighbor sprite generation

Built-in image_gen. Source style reference: artifacts/art04_concepts/05_paint_refined_v2.png. Character: intro_neighbor / 街坊妇人.

Result: neighbor.png is 1254x1254 RGB with magenta chroma background, NOT an alpha PNG. Initial true-alpha request returned baked checkerboard RGB and was not accepted. Runtime chroma keying must tolerate generated color variation. No image postprocessing was performed.

## Original prompt

Use case: stylized-concept.
Asset type: ONE isolated customer sprite for a fixed-counter 2D Godot game set in Republican-era Shanghai.
Reference image 1 is the approved art direction and scene. It is a STYLE, PALETTE, LIGHTING and POSE reference only. Create a DIFFERENT customer: an ordinary working-class middle-aged Shanghai neighborhood woman (街坊妇人). Do not copy the man's face.
Subject: tired middle-aged Chinese woman about 45–55, ordinary asymmetric weathered face with age and daily labor traces, unstyled graying dark hair tied into a plain small bun; plain faded charcoal-gray cotton blouse with simple cloth fastenings and worn sleeves, no decoration. Frontal upper-body pose, both shoulders visible, leaning slightly toward the viewer, one bent forearm with hand resting at the bottom at an implied counterline. No actual counter. Natural semi-realistic anatomy, reserved concerned expression, everyday unglamorous person.
Style: restrained semi-realistic handpainted GOUACHE, broad matte brushwork, simplified planar shading, natural skin. Match reference's plain aged lived-in treatment. NOT photorealistic, not beautiful calendar-girl, no qipao, no jewelry, no makeup, no decorative fabric, no youthful beauty, no heroic posing.
Composition: nearly square 1024x1024 target canvas, full crown and bun, both shoulders and entire resting hand uncut. Customer silhouette fills canvas with tight 2–4 percent margin, body terminates along a clean counter-height bottom edge below hand.
Background: genuine TRANSPARENT RGBA PNG with alpha=0 around the subject. Actual transparent pixels, not a checkerboard drawn in RGB. NO BACKGROUND, no floor, no wood counter, no props, no shadow outside silhouette, no text, no UI, no frame, no effects. Soft neutral warm lighting and subdued gray-brown palette as reference.

## Final chroma prompt

Use case: precise-object-edit. Edit the referenced woman sprite, change ONLY the background. Replace the entire checkerboard background with totally flat uniform saturated MAGENTA #FF00FF. This is intentional chroma-key backing for a Godot game sprite: no variation, gradients, texture, pattern, shading, or additional colors anywhere outside the woman's silhouette. Preserve the woman exactly: same ordinary tired middle-aged Shanghai woman, plain hairbun, same face, worn charcoal-gray blouse, matte coarse semi-realistic gouache brushwork, both shoulders, complete crown and bun, bent forearm and visible resting hand. No magenta light cast onto the woman. Keep square framing and clean bottom silhouette. No words, counter, props, floor, shadow, or scenery. ONLY change checkerboard to uniform magenta backing.
