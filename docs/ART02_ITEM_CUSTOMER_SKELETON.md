# ART02：物品检视、顾客与议价骨架

2026-09-04。沿用《美术设计规范 V0.2》《UI 线框规范 V0.1》与已接受的固定柜台布局；按负责人要求使用低保真图形验证功能。Product Design 用于来源对照与实际画面验收，直接扩展现有 Godot 场景。

## 本地运行

正常游戏已接入这些界面：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn"
```

独立美术试玩入口使用同一个主场景，固定选择本批 M7 内容清单，并使用 `user://tests/art02_review.json`：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn" --scene res://scenes/art02_review.tscn
```

也可在编辑器打开 `scenes/art02_review.tscn` 按 F6。该清单引用工作区内容文件，并非内容冻结快照；正式数据修改会影响样板。角色的品相仍按正式规则抽取，测试脚本才选用确定性的验收种子。

## 已交付

| 骨架 | 可见行为 |
| --- | --- |
| 柜台货物 | 青花碗、烛台、铜镜使用不同轮廓；点击货物进入鉴定；成交后清除，换客时更新 |
| 检视 | 免费切换正背面；取得对应线索后出现侧光、划痕或镜缘／镜背细节；换客恢复正面 |
| 鉴定 | 图像旁列出证据估值与玩家判断；已见线索、取证操作、判断选项分层展示 |
| 顾客 | 旧城住户、货郎、书生、房产掮客四个中性半身模板；衣饰区分身份，无诚实度或底价暗示 |
| 对话 | 身份、停留期限、当前回答与已问口供；长口供在抽屉完整显示，柜台摘录可悬停查看 |
| 议价 | 顾客要价、证据估值、剩余轮次三列；收购与活当各自输入和提交，保留原施压与拒绝操作 |
| 三态 | 同一门框、柜台、人物及物品锚点；沿用暖色营业、深夜压暗及冷光红灯鬼市预览 |

## 资源与接入

- `assets/art02/items/`：12 张 512×320 SVG。每类正、背面各一张，以及两种局部细节。只有已取证的细节进入可见列表。
- `assets/art02/customers/`：4 张 360×430 SVG，中性半身模板。
- `ui/art/counter_visual_catalog.gd`：集中维护资源 ID 与路径；正式替换可继续使用已有 `visual_asset_id`、`portrait_asset_id`。
- `core/trade/counter_visual_read_models.gd`：只读组织公开名称、证据估值、已取证线索、已问回答与既有经营数据；不输出真实价格、顾客底价、隐藏品相或未问回答。
- `ui/counter/counter_view.gd`：负责主场景的角色、物品与口供摘录。
- `ui/appraisal/appraisal_panel.gd`、`ui/dialogue/dialogue_panel.gd`、`ui/trade/trade_panel.gd`：继续通过原有 Intent/Presenter 调用玩法，未新增交易结算路径。

配置中的非空检视图仍可优先使用。替换局部资源时需同步维护线索映射，不能把修补、铁芯等尚未知晓的信息画入免费正背面。镜背刻字目前以清晰的文字线索为准，图内短线仅验证局部构图，不是假造的可读铭文。

三态切换仅影响表现；禁时鬼市仍为美术预览，没有新增鬼市经营机制。系统中文字体、纸木配色、细边框及少量磨损线继续复用，正式纸纹、印章、角色表情和精绘素材属于后续任务。

## 验证

```sh
godot --headless --editor --quit --path .
godot --headless --path . --script res://tests/run_all.gd
godot --path . --script res://tests/art02_ui_smoke.gd
godot --path . --script res://tests/art02_ui_smoke.gd -- wide
godot --path . --script res://tests/counter_visual_smoke.gd -- wide
```

真实鼠标验证：点击货物、免费翻面、问口供、取得细节、追问、查看历史、收购、换客、活当、铜镜鉴定与夜末结算。界面测试使用独立存档。截图与回归记录保存在 `artifacts/art02/`；来源及迭代见根目录 `design-qa.md`。

最终结果：1280×720 与 1600×900 各 184 项断言、0 失败；三态与抽屉脚本 102 项、0 失败；当前工作区 M0–M7 回归 1798 项通过，最终日志扫描无脚本错误。首轮有存档类型错误的回归日志保留为失败过程证据，未作为通过依据。

本批只提供表现层及验收脚本。为运行当前全套回归，另修复 `tests/m7_tests.gd` 两处局部变量的类型声明，未修改其断言。工作区同时存在其他经营和存档开发，本批未提交、推送或覆盖这些改动。
