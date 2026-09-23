# v27 美术来源

## 孙大元与普通客人统一半身比例 · 2026-09-18（当前使用）

- `sun_dayuan_visit_halfbody.png`：内置 imagegen 生成，实际输出1254×1254 RGBA，原图透明像素保留。原文件 `C:/Users/alvachen/.codex/generated_images/01a0aac2-e688-7b13-9811-e3cc1348d709/exec-191f55e6-2adb-405c-ab47-59ac3855ab55.png`。
- 参考现有 `neighbor_v2.png`、`citizen.png` 的方形半身构图和画法，保留册中孙大元照片的身份特征，同时附上上一版孙大元的实机截图指出胸口被截断的问题。
- 在同一1600×900场景比较三位人物，改为完整头—肩—胸腹—腰带的半身素材。运行时保持原图比例，以接近其他客人的约445像素方形范围放置，腰部由原柜沿遮挡；旧长幅素材保留，不再使用。

完整提示：

Create a replacement GAME CHARACTER SPRITE for the same pawnshop.
REFERENCE 1: existing woman customer, precise model for the GAME'S painted art style and head-to-upper-body proportion, not identity.
REFERENCE 2: existing man customer, style, camera distance and visible head-to-waist body anatomy.
REFERENCE 3: Sun Dayuan's original old photograph, preserve this man's recognizable broad middle-aged Chinese face, short moustache, heavy eyebrows, cap, uniform and diagonal leather strap. Do NOT copy photograph rendering.
REFERENCE 4: rejected current Sun sprite in actual scene. Its torso is too truncated at chest and head looks heavy; FIX this. Do not copy its figure composition.
Output single sprite on TRUE TRANSPARENT RGBA, 1024x1024 SQUARE. Camera and anatomy matching reference 1: whole cap, head, neck, shoulders, COMPLETE CHEST AND ABDOMEN DOWN TO WAIST BELT. Square half-body portrait, not full length. Upright adult officer with normal human proportions, moderately broad shoulders, ample length between collar and waist, no oversized head, no short barrel-like chest. Cap top near y=30, chin near y=340, shoulder tops near y=335, waist belt near y=890, lower jacket continuing to bottom y=1000 for in-game foreground occlusion. Face width about 230 pixels, shoulders approximately 700 pixels wide. Full elbows fit frame, upper arms relaxed, BOTH HANDS BEHIND BACK and NOT VISIBLE. Slight asymmetry / weight on one leg; restrained appraising eyes and closed mouth, officious expression, not smiling or heroic. Keep fictional man's identity, no extra weapons or props.
Exact aesthetic: hand-painted gouache with small irregular distinct brush planes and restrained warm highlights matching reference 1 and 2, subdued natural skin and dark grey olive wool, worn brown belt, matte surfaces. No photographic skin pores or studio lighting, no giant camouflage-like patches. Preserve fabric form and seam structure. Face and body painted with SAME brushwork. Gentle diffuse light, no bright rimlight, no glow or halo.
Only figure, no counter, no table, no background, no paper, no lettering, no embedded shadow. Sprite will be placed at the SAME roughly 460x460 runtime bounds as existing customers and real countertop will mask bottom near waist. DO NOT provide a complete scene.

## 孙大元绘画版与柜台遮挡修正 · 2026-09-18

- 当前来访立绘改为 `sun_dayuan_visit_painted.png`，1024×1536 RGBA，内置 imagegen 生成。原文件 `C:/Users/alvachen/.codex/generated_images/01a0aac2-e688-7b13-9811-e3cc1348d709/exec-dc9f7936-2691-457a-90ce-199383470ada.png`。透明PNG原样复制，无代码修改像素。
- 参考：册中孙大元照片、真实柜台画面 `.godot/qa/coat_folded_1600_01_counter.png`、被替换的首版人物。原照片与首版立绘保留供对照。
- 双手置于身后，灰褐/灰橄榄军服采用较大的可见笔触，收敛摄影式高光与细碎表面纹理。
- 不再使用截断手部的 AtlasTexture。完整人物绘制在原柜台木沿之后；遮挡前景复用游戏原背景纹理和同一套光照参数，限于场景区域，不覆盖底栏，仅在此人物接待时启用。

完整生成提示：

Use case: style-transfer and identity-preserve. Asset: replacement transparent character sprite for a historical Chinese pawnshop game.
Reference 1 is the SAME fictional man Sun Dayuan's book photograph, for facial identity and costume only. Reference 2 is the actual game screenshot: MATCH THE HAND-PAINTED STREET AND WOODEN ARCHITECTURE style, NOT its placeholder cartoon customer. Reference 3 is the rejected prior sprite: keep character identity, but FIX its photographic cutout look, bright skin, microtexture, and problematic forward hands.
Paint Sun Dayuan as a reserved, slightly stocky middle-aged Chinese local officer, broad face, heavy brows, short moustache, same peaked cap, muted grey-olive tunic and worn leather diagonal belt. His arms are held BEHIND HIS BACK in a composed officious stance; shoulders subtly turned, face toward player. BOTH HANDS ENTIRELY BEHIND HIS BODY, no hands in front, no hands resting on a table. Upper arms and elbows follow body's sides, no cropped hands or floating fingers.
RENDERING: strongly hand-painted historical game illustration, visible broad irregular brush planes like the background's wooden cabinets and stone paving, restrained facial planes, matte gouache/oil texture; edge variation inside silhouette, not studio portrait photography, not photoreal skin pores, not cinematic CGI. Muted earthy grey, olive, umber; skin subdued cool ochre, shaded as if standing underneath shop awning. Diffuse cool overcast daylight from upper right, very subtle warm shop fill, low specular highlights, no golden rim light, no halo. Face readable and recognizably same man, not cartoon or anime, not hyper-detailed plastic.
Composition: portrait 1024x1536 true transparent RGBA. Single figure from whole cap to mid thighs, entire shoulders and elbows inside canvas with ~8% side margins. Head approximately top 5%-28%, shoulders at 33%, waist belt about 70%, upper thighs continue to bottom 95%. The game will occlude his lower torso behind its real wooden counter. Do not draw any counter, table, foreground edge, ground shadow, room, props, border, text, paper, glow, or background. NO forward hand gesture. Genuine transparent pixels outside the figure, no smoky transparency halo. Deliver only the production sprite.

## 孙大元柜台立绘 · 2026-09-18

- `sun_dayuan_visit.png`：内置 imagegen 生成，1024×1536 RGBA；原图保留透明度，无代码抠图或像素加工。
- 原始文件：`C:/Users/alvachen/.codex/generated_images/01a0aac2-e688-7b13-9811-e3cc1348d709/exec-3e5718b9-015f-4e1d-a271-ff0946ca4976.png`。
- 参考一：`assets/social_book/sun_dayuan.png`，册中原照片不变。参考二：`.godot/qa/coat_folded_1600_01_counter.png`，真实柜台光色。
- 同一人的宽脸、短须、军帽、皮带保持一致，改为彩色、略转身和腰前克制的交谈手势。运行时通过 AtlasTexture 取上部1160像素，使下身自然藏于柜台后，原PNG未裁改。

完整提示：

Create a production transparent character sprite for an existing Chinese Republican-era pawnshop game. Reference 1 is the fictional character Sun Dayuan's old ID photograph: preserve his recognizable broad middle-aged Chinese face, thick brows, small dark mustache, stocky build, peaked officer cap, period military tunic and leather cross strap. Reference 2 gives the actual game scene's warm muted painterly realism and light. Depict the SAME man as a living visitor standing opposite the player behind a shop counter, shown cap to upper thighs, fully visible upper body with both hands. This is not an enlarged photograph: natural warm skin color, dusty gray-olive wool uniform, worn brown leather; subtly turned shoulders and head facing the player, officious composed expression, slightly raised chin, assessing eyes, one hand resting loosely near belt and the other making a restrained conversational gesture near waist. No stiff studio posing; no salute, no weapons, no goods. Mid-40s to early-50s, authoritative local military bureaucrat, unglamorized and grounded. Painterly realistic historical-game illustration matching scene, subdued colors and restrained small fabric details, soft ambient lighting slightly warmer from upper-left. Single figure, clean silhouette, not photoreal pasted studio photo; keep face recognizable from reference. Transparent RGBA background, no paper frame, no photograph aging, no room, no counter (game renders counter separately), no lettering. Portrait canvas 1024x1536, figure fills approximately 85% height, margin around cap and shoulders and hands; torso terminates below the belt for natural placement behind the counter.

生成方式：内置 imagegen，2026-09-17。保留原始透明 PNG，没有用代码重画或替代美术。

- `cotton_coat.png`：靛蓝旧棉袄，完整物品；对应原文件 `exec-5984c012-e7e0-478d-97b3-7515fd6b04af.png`。
- `military_plaque.png`：刻有“军方照应”的旧木牌；对应原文件 `exec-4b51246b-8fb2-4a0e-9699-5c6e814fc3cb.png`。

原文件目录：`C:/Users/alvachen/.codex/generated_images/01a0aac2-e688-7b13-9811-e3cc1348d709/`。游戏引用的是本目录副本。

## 折叠棉袄替换 · 2026-09-17

- 当前使用 `cotton_coat_folded.png`，内置 imagegen 生成，1536×1024 RGBA，保留原始透明度和阴影，没有代码抠图、重画或加工像素。
- 原始文件：上述原文件目录下 `exec-596d4785-ea60-44f8-be7c-a0c8c95f258f.png`。旧立式 `cotton_coat.png` 留作对照，当前物品正面与鉴定图均改用折叠图。
- 参考：游戏实机柜台 `.godot/qa/v27_1600_10_cotton_counter.png`（替换前）及旧棉袄素材。
- 柜台采用专属横向大尺寸与同步点击范围，其他货物保持原有尺寸。

完整提示：

Create ONE replacement production game prop sprite, not a screenshot or moodboard. Use case: precise-object-edit. Reference 1 is the actual pawnshop scene: use ONLY its painterly realistic historical materials, muted earthy lighting and countertop camera perspective. Reference 2 is the old jacket: retain its humble faded indigo cotton, Chinese frog fasteners and pale worn lining, but completely replace its upright invisible-mannequin silhouette with an EMPTY GARMENT folded and RESTING FLAT on a horizontal table. Subject: a single adult-sized early Republican-era Chinese cotton-padded winter jacket, naturally folded into a broad low rectangular bundle, sleeves tucked inward underneath, lower hem folded up under the body, relaxed flattened stand collar visible at the far edge, two or three rope frog fasteners along the upper front panel. Show layered thick compressible cotton edges, gravity creases, softly rounded corners, slight asymmetry; clean enough to wear, gently rubbed edges, no holes or extreme patches. Camera: pawnshop player's elevated three-quarter view looking down at the tabletop about 40 degrees, broad front folded edge nearest camera, very slight clockwise rotation. It must look like a weighty real folded cloth bundle, NOT a tiny standing jacket, shirt on hanger, rigid cardboard, glossy 3D plastic, miniature, floating clothes or upright torso. Style: restrained realistic hand-painted historical game asset, tactile matte woven cotton, soft imperfect hand stitching, dusky blue and charcoal with warm subdued highlights consistent with the scene, not hyper-sharp studio product photography. Lighting: soft warm upper-left light, tight natural translucent contact shadow immediately underneath folded bundle. OUTPUT: genuinely transparent RGBA PNG, landscape canvas 1536x1024, prop centered and occupying about 88 percent of canvas width, silhouette roughly twice as wide as high; entire prop and its soft shadow visible, minimal transparent margin. NO table, NO background, NO scene, NO person, NO UI, NO lettering, NO checkerboard texture. Preserve true transparent alpha. Deliver the folded coat sprite only.

## 棉袄生成提示

Create a single production game asset for a Chinese Republican-era 1920s pawnshop 2D illustrated game. A humble indigo charcoal cotton-padded winter jacket 棉袄, frog buttons, thick cotton lining, visibly used but intact, folded sleeves resting naturally, three-quarter front view, whole jacket visible. Painterly realistic textured oil/ink historical prop illustration, warm muted sepia lighting matching dark antique wooden pawnshop, no person, no hanger, no scene, no text. Isolated cutout on genuinely transparent RGBA background, not checkerboard, with soft local contact shadow only. Square composition, object occupies 80%, readable at small inventory thumbnail size.

## 木牌生成提示

Single game prop asset, horizontal hanging wooden plaque for a Chinese Republican-era 1920s pawnshop. Weathered dark walnut board, thin carved frame, small dull brass nails, two short hemp hanging loops above, discreet small faded red fictional procurement-office seal (no real political symbol). Four large legible antique gold brush Chinese characters, exactly left-to-right: 军方照应. Front-on flat view, whole object, transparent RGBA background with generous transparent margins, no room, no person, no other text. Warm aged sepia painterly realism consistent with an antique pawnshop visual novel. The wooden sign itself aspect ratio 3 to 1, centered, text readable at 180 pixels wide. Do not include artificial checkerboard background.
