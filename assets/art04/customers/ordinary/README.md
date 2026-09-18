# 普通客人柜台立绘 · 2026-09-15

八类职业的定稿已接入柜台及对话头像。富户管事为 v3；货郎于 2026-09-17 重新设计为灰发老行商，其余为 v2。原戴帽货郎现固定为铜镜丈夫，详见 `docs/CHARACTER_IDENTITY_REFERENCES.md`。保留不同动作、面部特征和神态。

## 素材

| 文件 | 职业 | 动作 |
| --- | --- | --- |
| citizen.png | 旧城住户 | 犹豫着探手 |
| hawker.png | 夜市货郎 | 托着旧布袋，斜眼盘算 |
| scholar.png | 旧书铺先生 | 摘镜细听 |
| agent.png | 富户管事 | 核单抬眼 |
| seamstress.png | 绣坊女工 | 攥裙踌躇 |
| watchmaker.png | 钟表修理匠 | 卷袖回话 |
| teahouse.png | 茶馆掌柜 | 搭巾含笑 |
| bookkeeper.png | 失业账房 | 收帕迟疑 |

均为 1254×1254 PNG。新货郎是 RGBA 透明图；其余七位是 RGB 洋红底。正式运行由 `CounterVisualCatalog.portrait_material` 使用已有 `counter_cutout.gdshader` 去底并清理发丝边缘。**除新货郎外，文件本身没有透明 alpha。**

## 摆放与身份

- 使用柜台半身构图。`CounterVisualCatalog.ORDINARY_PLACEMENT` 分别记录每人方图显示高度、原图下摆位置和水平中心。
- 下摆贴合背景原画 y=445/941 的柜台后沿，保持等比缩放；八人的手都处于交谈动作，不添加接触桌面的假阴影。
- 只根据八个普通职业 customer_id 选择这批素材；熟客 `familiar/*` 和特殊人物使用独立立绘，丈夫不再与普通货郎共用图。
- 柜台和对话共用同一选择函数；氛围着色及入场/离场沿用现有逻辑。
- `person_id` 仅增加到只读视觉模型，用来区分熟客。未修改来客编排、对白、经济数值或存档格式。

## 来源与验收

生产源图位于本目录；内置 ImageGen 的完整提示词和历史来源存于相邻 `provenance/v2-manifest.json` 与 `provenance/agent-v3-manifest.json`。其中生成器绝对路径与历史草稿路径仅用于溯源，不是运行依赖。2026-09-17 新货郎的完整生成记录见 `provenance/hawker-v3-manifest.json`，旧 v2 记录保留为历史来源。

实际渲染验收：`tests/ordinary_customers_visual.gd`。两种尺寸 1280×720、1600×900，八位职业逐张查看，另含三种氛围、首客身份与离场验证。截图使用正式场景的视觉夹具，柜台物品与时刻来自隔离的开局存档，并非八次实际营业记录。

随提交保存的运行结果、场景截图及验收说明：`docs/qa/ordinary-customers/`。重新运行测试会将全部截图写入本地 `artifacts/ordinary-customers-20260915/standees/`。
