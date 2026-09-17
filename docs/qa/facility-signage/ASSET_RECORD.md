# 设施标识修订 · 资源记录

日期：2026-09-16。工具：内置 Image Gen，无CLI调用。用户要求重新设计旧账柜、“铺内”和返回柜台标识，返回只用特殊箭头引导。

- 运行资产：`assets/facilities/return-arrow.png`（相对项目根目录）。1536×1024，RGBA，保留原透明通道。
- SHA256：`653b9b671426045835322361fc0a4175f9603413958e7c0d04845ee5d475c5d2`。
- 生成来源：Image Gen；内部会话与执行编号仅保留在本地。
- 参考图：用户第三张返回按钮截图，留档为本目录`request-return.png`。
- 改动：`ui/shop/facilities_room_view.gd`替换三类标识；现有界面回归增加实际点击新箭头的验证。导航服务、交易、费用和保存未改动。

## 完整生成提示词

Create ONE production game UI navigation arrow asset on a genuinely transparent RGBA background. Style reference supplied: semi-realistic opaque gouache 1930s Chinese pawnshop, restrained aged wood and dull brass, brown olive gray setting. Subject: a slim elegant RIGHT-pointing navigation arrow, clearly reads as arrow at 80x40 pixels. Unique designed silhouette: narrow dark walnut shaft inset with a warm muted ivory/brass line, a gracefully tapering prominent pointed brass arrowhead, tiny symmetrical stepped traditional joinery at the tail. Mostly clear ivory-brass silhouette for readability against dark timber. Front-facing, horizontally aligned, no perspective, no writing. Occupy central 85% width and 45% height of a wide 3:2 canvas, generous fully transparent padding. Painterly understated craft, lightly weathered but intact, soft subtle shadow only beneath arrow. No text, no characters, no label, no rectangular sign, no frame, no circular button, no broad plaque, no extra objects. Match the references' palette and matte painted texture; do not copy their ugly paper rectangles. This image will be used as a small clickable exit arrow in an existing native game.
