# 街坊妇人：柜台站姿修订

2026-09-12，按负责人截图反馈修正左手缺失、倚靠姿态及身体与柜沿关系。使用内置 image_gen 两次编辑，保留原妇人的身份、灰布衣、水粉笔触和疲惫神情。旧版 neighbor.png 保留。

新版为 1254×1254 RGB 洋红底，由现有运行时着色器去底，不是真透明 PNG。第一轮透明请求返回了烘焙棋盘格，未接入。第二轮替换背景，并把中央腰腹遮挡线提前到手腕高度，保留两只完整的前伸手。

源图：assets/art04/customers/neighbor.png；空间参考：assets/art04/counter_room.png 及负责人提供的游戏截图。

最终生成文件：exec-36cad7b9-3079-4829-ab35-b519568e89c4.png。

## 第一轮提示词

Use case: precise-object-edit / identity-preserve.
Asset type: replacement isolated character sprite for an existing Republican-era Shanghai pawnshop Godot game.
Input image 1 is the EDIT TARGET and identity reference, the old woman on magenta. Input image 2 is the supporting EMPTY SCENE for perspective and lighting only. Input image 3 is the problematic existing composite for spatial context only.
Create ONE improved replacement character sprite, not a scene or UI. Preserve the exact same recognizable weathered Chinese neighborhood woman's face, age, graying bun, worried reserved expression, faded charcoal cotton blouse with cloth fasteners, and restrained matte semi-realistic gouache brushwork. Correct her anatomy and pose.
She is STANDING UPRIGHT on the customer side of a waist-high counter, balanced relaxed shoulders, upper arms hanging naturally, elbows close to her sides and lower than the counter's top. Both forearms reach a short distance forward to rest BOTH HANDS gently palm-down on the same implied horizontal countertop, hands clearly separated about torso width, wrists naturally connected to worn cuffs. The viewer is behind the counter, slightly above her hand level. Her LEFT hand (image right) must be fully visible with anatomically coherent fingers; her RIGHT hand (image left) must also be complete, relaxed fingers slightly forward, no clenched fist. She is not leaning her body weight on the table, not sitting, not crossing arms, not holding objects. Hands seen from slightly above, coordinated perspective with the provided table.
Framing: square canvas, woman centered, full crown with about 5% top margin, shoulders, elbows, cuffs and both whole hands visible with side margins. The hands lie around 82–87% of image height. Continue her lower blouse / torso naturally BELOW the hands down to the image bottom (this extra torso will be hidden by the actual game counter). Do NOT crop the torso at the hand level, do NOT truncate an arm. Her stature should look natural, no exaggerated head or broad hunched torso.
Background: genuine transparent RGBA, all area outside woman alpha=0. No checkerboard drawn into RGB, no magenta, no scenery, no table, no wooden edge, no text, no props, no UI, no floor. Clean natural opaque silhouette without colored fringes. Soft subdued neutral warm face and hand light, muted charcoal-gray blouse. Keep the original rough opaque handpainted look rather than photography, anime, glamour or smooth 3D.
Output only the isolated woman sprite at high resolution.

## 第二轮提示词

Use case: precise-object-edit.
Edit the provided improved woman sprite. Keep her recognizable face, hair, shoulders, arms, both complete hands, clothing colors, pose and handpainted gouache style exactly unchanged.
Make only two production sprite corrections:
1. Replace ALL baked checkerboard and pale background outside the woman's silhouette with PERFECTLY UNIFORM SOLID MAGENTA #FF00FF. This is chroma-key backing, NOT scene lighting. No magenta contamination on hair or skin, no checkerboard, no background texture or shadows, no color variation. Keep clean sharp antialiased character edges.
2. The lower CENTRAL blouse currently extends to the same bottom line as her fingers. Remove ONLY the central lower torso below an implied horizontal counter back-edge at about y=1070 of this 1254px source (85.3% canvas height), BETWEEN the two wrists/hands. Replace that small lower-central blouse area with the same solid magenta background, so the body is occluded BEHIND the real counter while both hands extend forward and remain completely visible. Continue the horizontal occlusion wherever exposed lower blouse or sleeve would otherwise hang below that line, but do NOT cut either wrist or hand or any fingers. The hands are foreground and MUST stay complete. This is a character sprite with counter occlusion already accounted for. Do not paint an actual counter or any wood. Preserve square canvas, exact overall character scale and head location.
Output one final high-quality sprite on flat pure magenta, no text, no border.
