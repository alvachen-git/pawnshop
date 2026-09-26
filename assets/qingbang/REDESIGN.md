# 沈伯钧与青帮徽记修订

2026-09-26，根据用户反馈调整。使用内置 image_gen 生成并编辑，原始旧人物 `shen_bojun.png` 保留，运行时改用 `shen_bojun_enforcer.png`。

## 接入素材

- `assets/qingbang/shen_bojun_enforcer.png`：黑礼帽、深色长衫与披肩外套、宽肩厚颈、玉扳指；眉骨、右侧脸颊和左侧下颌三道愈合的刀疤。保留透明背景与柜台前景遮挡。
- `assets/qingbang/qingbang_emblem.png`：深褐旧墨盘龙圆印，与军阀双旗圆章采用一致尺寸。仅为游戏虚构徽记，不宣称是历史青帮标识。
- 往来簿左侧只显示阵营、图标、人物姓名；关系态度在右侧单列“态度”，青帮中立改为“尚未交好”，军阀中立改为“尚无交情”。不显示分数。
- 拜访、收费、砸店对白改为短句、直接要求和威胁。历史事件结果文本不变，避免因为润色对白而影响已存进度的重放。

## 人物生成提示词

Generate a redesigned character sprite for an existing Republic-era Shanghai pawnshop game. Reference 1 is the OLD sprite to replace: deliberately invent a completely different face, silhouette and clothes, do NOT preserve its likeness, swept hair, narrow face, brown waistcoat or clasped hands. Reference 2 supplies painterly background palette only. New fictional Qingbang neighborhood enforcer Shen Bojun: Chinese man about 48, broad square jaw, thick neck, solid wide shoulders, close-cropped hair mostly hidden beneath a low black felt fedora with shallow crown and modest brim, small healed diagonal scar crossing one eyebrow, stern hooded eyes aimed straight at viewer, clean shaven, closed unsmiling mouth, chin slightly lifted. Dark charcoal traditional long changshan with stand collar and simple frog closures; an unbuttoned dark ink-blue long coat draped on shoulders, muted jade thumb ring. One hand gripping the opposite wrist LOW near beltline, fingers anatomically correct, elbows kept inside silhouette. Composed territorial authority, stocky street boss, NOT a polite merchant, not a modern movie gangster, no suit/tie, no gun, no cigarette, no bags. Head-to-below-waist framing, square image, figure fills most canvas height; realistic head small relative 2.6-head-wide shoulders. Full hat and shoulders uncropped, below waist body continues through bottom edge to be occluded by game counter. Opaque gouache and rough oil-paint brush planes, matte worn fabric, very subdued warm grey ochre/ink-blue palette, ambient cool street light with faint warm shop bounce. Avoid photographic skin pores, 3D plastic, studio rim lighting, slick digital skin, glamorous polish. Single person ONLY on genuine transparent alpha, no counter, no background, no text. Keep character readable at 350 pixels tall.

## 刀疤编辑提示词

Edit ONLY the facial scars of this exact character sprite. Preserve his precise face identity, expression, proportions, black fedora, dark long coat, changshan, jade ring, hand pose, painterly gouache brush strokes, muted colors, framing, and genuine transparent alpha background. Make him recognizably knife-scarred: strengthen the existing diagonal old healed cut across the eyebrow on image left, add one clearly visible long healed diagonal scar from the outer cheekbone toward the lower cheek on image right, and one shorter healed scar near the opposite jaw on image left. Exactly THREE asymmetrical old scars overall. Scars are pale muted raised/recessed skin tissue with a thin dark brown shadow, strong enough to read at game sprite scale. Natural, weathered, intimidating; NO fresh blood, NO open wounds, NO stitches, NO change to eyes or anatomy. Do not add other objects or change any clothing or body pixels unnecessarily.

## 徽记生成提示词

Create one game faction emblem asset, a fictional Qingbang faction mark for a Republic-era Chinese pawnshop ledger. Use attached military emblem ONLY to match dry worn dark-brown ink, circular framing, transparent holes and icon scale. New design: a single bold coiled Chinese dragon shown in a compact round silhouette, head in side profile with angular snout and two short horns, one sweeping thick curved body curling into center, two simple claw shapes. An imperfect thin circular ink border. Restrained woodblock/seal engraving, rough rubbed ink breaks, strong negative space, extremely simplified detail to stay recognizable at 64px. Monochrome dark umber brown #3c291b, flat stamped ink, transparent background and transparent negative spaces. No lettering, no Chinese characters, no flags, no weapon, no decorative corner elements, no shading, no colored paper, no square panel, no 3D. Center one large emblem with a small even 5 percent transparent margin. This is a made-up game emblem, not an authentic historical society insignia.

## 验证

Godot 导入通过；界面检查 156 项通过（1280×720、1600×900），规则边界检查 38 项通过。截图与结果保存在 docs/qa/qingbang-redesign/。本次不改变玩法或存档格式。
