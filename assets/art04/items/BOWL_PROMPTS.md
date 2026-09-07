# 青花小碗正面素材

工具：内置 `image_gen`。参考：`artifacts/art04_concepts/05_paint_refined_v2.png`。

最终素材：`bowl_front.png`，1536×1024 RGBA。alpha 范围 0–254；680160 像素完全透明。共享正面未增加裂痕、修补或缺口等真伪线索。

## 首次生成提示词

Use case: stylized-concept.
Asset type: ONE isolated 2D game item sprite, a small blue-white porcelain bowl, for the native Godot game 鬼市当铺.
Input image: reference image 1 is the approved main game screen; use ONLY the bowl on its counter as the shape, perspective, material, and painting-style reference. Do not reproduce the screen or any other objects.
Primary request: generate just this ordinary small Chinese blue-white porcelain bowl, seen from slightly above in a three-quarter frontal view so the elliptical rim and empty interior are visible, on a genuinely transparent alpha background. Square canvas approximately 1024 x 1024. Center the whole bowl, occupying approximately 85% of image width and 60% of image height. Preserve the squat everyday bowl form with a small foot ring, off-white ceramic and sparse muted cobalt floral decoration.
Style/medium: matte SEMIREALISTIC HANDPAINTED GOUACHE with visible restrained broad brush marks and softly irregular painted edges, matching reference. Practical, humble, old everyday object; not ornate, luxurious, or polished. Modest diffuse warm overhead illumination, readable silhouette when scaled down to 160 x 140 pixels.
Materials: warm gray off-white slightly aged porcelain, muted faded blue flower pattern and two thin blue rim lines. Intact continuous rim and surface with NO visible cracks, repairs, chips, or authentication clues, because this sprite must be shared across hidden authenticity variants.
Backdrop: truly transparent alpha everywhere outside the bowl; at most a small very faint soft contact shadow with partial transparency immediately beneath its foot.
Avoid: no mat, no wood, no counter, no backdrop color, no checkerboard drawn into the image, no text, no labels, no frame, no extra objects, no gold, no glow, no strong glossy highlights, no photorealistic product photography, no 3D render, no fantasy ornament.

首稿为 RGB 并将棋盘绘入背景，未作为运行时素材保存。

## 透明背景提取提示词

Use case: background-extraction. Edit target is the provided bowl sprite. Change ONLY the background: remove ALL the white and light-gray checkerboard pixels and output a PNG with a GENUINELY TRANSPARENT ALPHA CHANNEL surrounding the bowl, alpha 0 outside the object. Checkerboard is not a background color and must not be painted into output. Preserve the bowl itself precisely, including its form, muted blue flowers, intact rim, gouache brush marks and colors. Remove the floor shadow if necessary for a clean transparent cutout. No new objects, no other changes. One isolated item sprite, full bowl in frame.

提取参考为首稿 `/Users/alvachen/.codex/generated_images/01a07a7e-cbb9-7390-9dd6-aeade91ec46d/exec-0e43c453-ce77-4510-a3d2-6cbfc521584f.png`。
最终原始输出 `/Users/alvachen/.codex/generated_images/01a07a7e-cbb9-7390-9dd6-aeade91ec46d/exec-952d0d60-7784-465f-b7eb-ce6cade2fb6f.png`。
