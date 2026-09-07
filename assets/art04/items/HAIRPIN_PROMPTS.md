# 旧银簪正面素材

工具：内置 `image_gen`。风格参考：`artifacts/art04_concepts/05_paint_refined_v2.png`。
运行时关联：`placeholder.silver_hairpin`（由主任务接入）。
最终文件：`hairpin_front.png`，1536×1024 RGBA，alpha 范围 0–254，1486011 像素完全透明。正面无修补、缺口、字铭等鉴定线索。

## 首次生成提示词

Use case: stylized-concept.
Asset type: ONE isolated 2D game inventory sprite for an ordinary old silver hairpin in a Republican-era Shanghai pawnshop.
Input image 1 is a style reference only: match its modest semi-realistic handpainted gouache. Do not copy its scene, bowl, people, UI, or text.
Subject: a single simple old silver hairpin, suitable for an ordinary neighborhood woman's daily hair arrangement. One long slender slightly tapering silver shaft with a small flattened head bearing a very shallow restrained five-petal flower embossing. Humble everyday silver, darkened with age, matte gray with softened edges and sparse brush highlights. Front surface intact: no cracks, chips, repair seams, inscriptions, numbers, maker marks, or visible authenticity clues. One hairpin only.
Style: matte SEMIREALISTIC HANDPAINTED GOUACHE, muted slate silver and warm gray brush planes, restrained broad painterly marks matching the reference. Not a photo or 3D render, not polished jewelry.
Composition: full hairpin lying diagonally from lower left toward upper right, head at upper right, shallow overhead 3/4 view. Broad landscape canvas approximately 1536 x 1024, hairpin length spans 85% of width, enough margin all sides. Readable at small game UI size.
Background: genuinely transparent PNG ALPHA channel, alpha 0 everywhere outside the object. No surface, floor, tabletop, paper, mat, colored backdrop, gray checkerboard, cast shadow or gradient. The output must have a true transparent alpha channel, not a drawn simulation of transparency.
Avoid: no jewels, no gold, no ornate filigree, no elaborate imperial ornament, no bright chrome, no glowing edges, no luxurious presentation, no text or labels, no extra objects.

首稿为 RGB，棋盘被绘入背景，不作为运行时素材。

## 背景提取提示词

Use case: background-extraction. Edit target is the provided silver hairpin sprite. Change ONLY the background: remove ALL the white and light-gray checkerboard pixels and output a PNG with a GENUINELY TRANSPARENT ALPHA CHANNEL surrounding the hairpin, alpha 0 outside the object. Checkerboard is not a background color and must not be painted into output. Preserve the hairpin itself precisely, including its slender diagonal form, modest flower embossed head, darkened silver surface, intact silhouette and gouache brush marks and colors. Remove the floor shadow if necessary for a clean transparent cutout. No new objects, no other changes. One isolated item sprite, full hairpin in frame.

提取输入：`/Users/alvachen/.codex/generated_images/01a07a7e-cbb9-7390-9dd6-aeade91ec46d/exec-b432884e-40bc-4d3c-a156-5ef0e4283b7e.png`。
最终原始输出：`/Users/alvachen/.codex/generated_images/01a07a7e-cbb9-7390-9dd6-aeade91ec46d/exec-e472eb0b-82e8-4e7b-a7c5-d8b23edf0b95.png`。
