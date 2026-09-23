# 人物用图与身份定稿
## 2026-09-23：富客固定身份

v37新局中，绸缎庄东家为周锦生，机器厂老板为李衡，梨园名角为程玉笙，古玩行掌柜为沈季安，洋行大买办为Edward。各自固定人物ID与立绘；跨夜来访、当票及赎回保持一致。普通客人仍按原规则命名；v36及更早记录不改名。


## 2026-09-22：五类富客专用立绘（本地待体验）

延续现有半写实水粉笔触与民国当铺氛围，按稳定客人身份使用独立画作。不得再映射到普通客人的脸。

| 身份 | 立绘（`assets/art04/customers/wealthy/`） | 外貌辨识 |
| --- | --- | --- |
| 绸缎庄东家 `customer_wealthy_silk` | `silk.png` | 四十多岁、瘦长脸、细髭、黑瓜皮帽；浅色长衫配紫褐马甲，捻看蓝色绸料 |
| 机器厂老板 `customer_wealthy_factory` | `factory.png` | 四十多岁、方脸短发、紧蹙眉；深色三件套、表链、折起的账纸 |
| 梨园名角 `customer_wealthy_opera` | `opera.png` | 五十岁上下女子、眼角细纹、面颊岁月感、鬓边银丝的波浪短发、珠耳饰；青绿旗袍、披肩、小首饰匣 |
| 古玩行掌柜 `customer_wealthy_antique` | `antique.png` | 年长、秃顶圆脸、圆眼镜、尖白须；深绿长衫与黑马甲，手持图册 |
| 洋行大买办 `customer_wealthy_comprador` | `comprador.png` | 中年、棱角窄脸、黑框圆眼镜、细胡须、油亮背发；深蓝双排扣西装、皮夹与手套 |

生成来源见同目录 `generation.json`、`identity-revisions.json`、`silk-redesign.json`、`opera-age-revision.json`。最初的圆脸灰发绸缎东家已按负责人反馈替换；后续以当前 `silk.png` 为准。梨园名角按后续反馈增加外观年龄，保留原有身份、衣装与持物。原图洋红背景通过现有柜台材质去底，人物接受当前夜间光照。此次只调整画面和鉴定信息层次，不改变交易规则、客流或存档。

## 2026-09-17：铜镜丈夫与普通夜市货郎分开

负责人确认：铜镜剧情图已采用原普通货郎的脸，现将该形象正式固定为丈夫，并另画普通货郎。

| 身份 | 唯一正式立绘 | 外貌辨识 |
| --- | --- | --- |
| 铜镜故事的丈夫（`mirror_husband`，调查人物 `mirror/husband`） | `assets/art04/customers/special/mirror_husband.png` | 棕色旧鸭舌帽、瘦长脸、大耳、深蓝短褂、斜肩带；一手扶肩带，另一手交谈 |
| 普通夜市货郎（`customer_hawker`） | `assets/art04/customers/ordinary/hawker.png` | 五十多岁外观、结实身材、宽额、灰白短发与短髭；褐马甲配灰绿衬衣，双臂托旧布袋，斜眼盘算 |

铜镜相关剧情插图、回忆、丈夫来访、夫妻重逢都应以正式丈夫 PNG 为人物参考。不要因旧字段 `asset.customer_hawker` 或旧生成记录而重新选择普通货郎的脸；运行时按稳定身份选择人物。

丈夫源图完整保留负责人附图对应的原画像素，1254×1254 RGB 洋红底。新普通货郎由内置 ImageGen 重新设计，1254×1254 RGBA，真实透明背景；完整提示词和来源见 `assets/art04/customers/ordinary/provenance/hawker-v3-manifest.json`。

先前不戴帽、穿靛蓝马甲、摸下巴的丈夫设计已停用，历史稿仍留存于 `artifacts/special-customers-20260916/v1/mirror_husband.png`。历史画廊及旧生成记录不再代表丈夫现行形象。此次调整不改变剧情、人物关系、对白、来客排期或存档结构；外观年龄只用于美术辨识。
