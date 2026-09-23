# 本轮物品美术发布验收

2026-09-23，以远端 main `43caaf1` 为发布基线，分支 `codex/item-art-release-20260923`。
默认场景仍为 v29 `mirror_dream_call_ten`。本轮不发布本地 v30 玩法整合；`assets/item_art_v30` 仅为素材目录名称，不要求内容升级到 v30。

## 范围

- 接入砚台、紫砂小壶、绣片、烛台、铜镜、钢笔、怀表，重绘暗哑黄铜烛台及有表壳厚度的怀表正反面。
- 按试玩反馈缩小壶、钢笔、烛台、青花小碗、银簪及砚台，增加桌面接触阴影和统一光照。
- 银戒指、银锁采用本轮新图和小首饰比例，替换 main 上旧银戒指呈现；保留原背面、线索门槛及自定义资源优先级。
- 柜台、鉴定、库存、成交回执共用资源。物品 ID、玩法、排班、存档格式不变。

## 在发布基线上重新执行

| 验证 | 结果 |
| --- | --- |
| 默认 v29 九类物品，真实窗口 1280×720 | 1143 assertions / 0 failures |
| 默认 v29 九类物品，真实窗口 1600×900 | 1143 assertions / 0 failures |
| 银戒指、银锁七夜货品场景，真实窗口 1280×720 | 198 assertions / 0 failures |
| 银戒指、银锁七夜货品场景，真实窗口 1600×900 | 198 assertions / 0 failures |
| 资源映射、知识筛选、自定义资源与铜镜结局契约 | 120 assertions / 0 failures |
| main 既有银戒指交互回归（headless） | 55 assertions / 0 failures |

以上合计 2857 项检查，0 失败。真实流程覆盖自然来访、免费翻图、鉴定、正常收购、库存与 v29/v21 支持节点的存档编解码恢复；日志见本目录 `validation-*.txt`。导入和脚本检查通过，两种分辨率代表性柜台截图已复查。未做 Windows 打包或全部历史存档迁移。

旧 v30 本地验收截图、提示词与验证日志作为设计迭代证据保留在相邻目录，不能当作远端游戏版本的证据。仓库收录链接所需截图；完整原始过程图仍在本地 `.artifacts/item-art-grounding`。

## 本次发布基线截图

| 物品 | 1280×720 | 1600×900 |
| --- | --- | --- |
| 黄铜烛台 | [截图](1280_item_brass_holder_counter.png) | [截图](1600_item_brass_holder_counter.png) |
| 怀表 | [截图](1280_item_pocket_watch_counter.png) | [截图](1600_item_pocket_watch_counter.png) |
| 钢笔 | [截图](1280_item_fountain_pen_counter.png) | [截图](1600_item_fountain_pen_counter.png) |
| 银戒指 | [截图](1280_item_silver_ring_counter.png) | [截图](1600_item_silver_ring_counter.png) |
| 银锁 | [截图](1280_item_silver_lock_counter.png) | [截图](1600_item_silver_lock_counter.png) |

## 复查命令

在该版本仓库根目录运行：

```sh
godot --path .
godot --path . --script res://tests/item_art_grounding_ui.gd
godot --path . --script res://tests/item_art_grounding_ui.gd -- wide
godot --path . --script res://tests/silver_jewelry_art_ui.gd
godot --path . --script res://tests/silver_jewelry_art_ui.gd -- wide
godot --headless --path . --script res://tests/item_art_contracts.gd
```

新测试截图和测试存档写入 `.godot/qa/`，不覆盖玩家存档。银饰可加 `-- review-ring` 或 `-- review-lock` 直达真实来访并保留窗口。
