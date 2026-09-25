# 相机柜台手绘风格修订

2026-09-25。按用户确认的建议，将柜台相机从摄影式商品图改为半写实水粉。Product Design 用于沿用项目视觉基准与检查实际界面；内置 imagegen 用于重绘 PNG。

## 范围

- 资源：assets/camera_desk/camera_counter_painted.png，RGBA，1536×1024。
- 柜台、库存和出售通用正面图接入新图。相机位置与显示框保持原设置。
- 原相机整体图仍保留供鉴定参考；铭文、镜片、光圈及四种冒牌图样未改动，不降低证据可辨性。
- 交易参数、音效、查验记录及存档语义未变。
- 原图仍在 camera.png，新图单独保存，便于复核。

## 调整

机身使用灰绿暖黑色块和可见笔触，减少细密皮革颗粒；金属改为暗哑暖灰银色，降低高光反差；镜头反射弱化，并用透明接触阴影连接桌面。没有通过整体模糊制造手绘感。

美术基准：docs/ART04_GOUACHE_DIRECTION.md，以及用户提供的柜台截图 codex-clipboard-a6f70748-0e63-4341-80e2-d16d7a80fff2.png。Product Design 保存的另一项目（蜀汉）风格未混入本项目。

## 来源与生成指令

内置 imagegen；未使用图像处理脚本修改成品。

第一轮：exec-18c4ee39-d989-4911-8e0b-82cbe6a9fd81.png；缩小到柜台后仍偏细碎，追加第二轮。

最终：C:/Users/alvachen/.codex/generated_images/01a0c8e1-5d71-7373-a439-546928f9c776/exec-efd5ee67-847c-4f30-967f-7c2bcada63ed.png，原样复制到项目资源。

### 初次指令

Use case: style-transfer. Input image 1 is the CAMERA ASSET EDIT TARGET. Input image 2 is STYLE, LIGHTING and PERSPECTIVE REFERENCE ONLY (painted pawnbroker counter with a customer). Repaint the camera of input 1 as a production-ready transparent PNG game prop that belongs in the hand-painted environment of input 2. Output ONLY the camera and its subtle translucent contact shadow, no table, scene, person, lettering labels or UI. Keep the camera's exact silhouette, lens position, component count and mild top-down three-quarter viewpoint. Landscape 3:2 canvas with camera occupying approximately 86% width, 77% height; centered, entire prop uncut with 7-10% transparent padding. Real alpha transparency, not black background, no halo or studio vignette.

Art direction: realistic painted 1930s game prop, opaque gouache / restrained oil-paint strokes, broad deliberate brush planes matching the old man's hands and counter in image 2. Visible medium-sized brushwork, subtle worn patina, simplified broken strokes for leather texture rather than granular photographic pores. Black lacquer becomes muted warm charcoal with faint olive reflected light from the green cloth. Nickel is dull warm pewter with restrained ivory/ochre brush highlights; NO mirror-shiny chrome, no crisp white pinlights, no photorealistic product render, no black crushed shadows. Keep coherent readable body, dials and lens rings; do NOT blur or smear the object. Lens glass dark desaturated olive-brown with one small soft warm reflection, not an eye-catching gold glow. Tiny lettering may be hinted naturally, do not add counterfeit lettering or defects: this counter image is neutral across identities. Thin painterly edges, no outlines. Light from upper left matches image 2, gentle room fill. Include a narrow diffuse dark olive-brown CONTACT SHADOW hugging the bottom base and a very modest soft shadow to the lower right, with no opaque floor patch. Warm gray-green ambient bounce under the body makes it sit on cloth. The result should have the SAME visual density and painterly material treatment as the background reference, not photographic sharpness.

### 定向修订

Repaint the isolated camera in image 1 again. Image 2 is the target GAME ART STYLE; pay particular attention to the painted fingers, wood and green cloth, NOT the photographic camera that is being replaced in image 2. Output only the camera with true alpha transparent background and a narrow natural contact shadow. Preserve the silhouette, parts, pose, lens, 3:2 canvas and location from image 1. Stronger opaque gouache hand-painting is required, not a photo with texture overlaid. Front black leather should be broad muted charcoal-olive painted planes with only a FEW broken dry-brush accents, completely remove dense repeated leather grain/diagonal knit marks. The object is viewed at 200px wide in the game so use medium broad brush strokes that survive shrinking. Body darkest areas should be lifted warm charcoal (not absolute black). Nickel metal should be matte gray-beige/pewter, low contrast, no white rim highlights or polished chrome. Restrained flat warm midtones; lens reflection subdued gray-olive, no bright gold hotspot. Silhouette edges softly painted but clean, no cartoon black outlines and no blur. Reduce shiny white highlights by about half, simplify tiny dial ticks. Give the underside subtle green cloth reflected light. NO coarse all-over noise pattern, NO black or glowing halo around object, no visible flat background plane. Base anchored by a small diffuse olive-brown semi-transparent contact shadow only. It should read like a period game background painter painted this prop with the same brush as the surrounding room.
