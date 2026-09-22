# 人物用图与身份定稿

## 2026-09-17：铜镜丈夫与普通夜市货郎分开

负责人确认：铜镜剧情图已采用原普通货郎的脸，现将该形象正式固定为丈夫，并另画普通货郎。

| 身份 | 唯一正式立绘 | 外貌辨识 |
| --- | --- | --- |
| 铜镜故事的丈夫（`mirror_husband`，调查人物 `mirror/husband`） | `assets/art04/customers/special/mirror_husband.png` | 棕色旧鸭舌帽、瘦长脸、大耳、深蓝短褂、斜肩带；一手扶肩带，另一手交谈 |
| 普通夜市货郎（`customer_hawker`） | `assets/art04/customers/ordinary/hawker.png` | 五十多岁外观、结实身材、宽额、灰白短发与短髭；褐马甲配灰绿衬衣，双臂托旧布袋，斜眼盘算 |

铜镜相关剧情插图、回忆、丈夫来访、夫妻重逢都应以正式丈夫 PNG 为人物参考。不要因旧字段 `asset.customer_hawker` 或旧生成记录而重新选择普通货郎的脸；运行时按稳定身份选择人物。

丈夫源图完整保留负责人附图对应的原画像素，1254×1254 RGB 洋红底。新普通货郎由内置 ImageGen 重新设计，1254×1254 RGBA，真实透明背景；完整提示词和来源见 `assets/art04/customers/ordinary/provenance/hawker-v3-manifest.json`。

先前不戴帽、穿靛蓝马甲、摸下巴的丈夫设计已停用，历史稿仍留存于 `artifacts/special-customers-20260916/v1/mirror_husband.png`。历史画廊及旧生成记录不再代表丈夫现行形象。此次调整不改变剧情、人物关系、对白、来客排期或存档结构；外观年龄只用于美术辨识。
