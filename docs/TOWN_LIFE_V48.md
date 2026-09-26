# 街巷百业 v48 · 本地整合试玩

> 2026-09-26：同目录启动器现默认进入 v50。继续本文 v48 旧进度请添加 -Legacy；新版说明见 [TOWN_LIFE_V50.md](TOWN_LIFE_V50.md)。

基于 main f3719f5（含 #74）创建 codex/town-life。新内容只由 data/town_life_manifest.json / town_life_v48 启用；scenes/start.tscn 及旧清单不变。已整合周怀安、特殊客晚间出场与回访、湿包持货、陆掌眼介绍与出货、活当利息、留声机和开铺前回收商。

## 启动

完整新局：双击 play-town-life.cmd，或在 PowerShell 执行：

```powershell
& "D:\CodexData\runs\pawnbroker-town-life\play-town-life.cmd"
```

加 `-Wide` 使用 1600×900；默认 1280×720。新局存档位于 Godot 用户目录下的 `town_life_v48`，不会读取或覆盖旧试玩进度。

## 独立测试

预置不保存进度，关闭重开即可重置。以下命令都接在启动脚本之后：

| 参数 | 场景与建议操作 |
| --- | --- |
| `-Stage porter` | 脚夫：留意赶工价与截止时间，分别试首报、错过截止、首报失败 |
| `-Stage musician` | 乐师带二胡：只能活当，尝试高息，再改中／低息 |
| `-Stage washerwoman` | 洗衣妇带背心：交谈问修补，之后深入检查核对线索 |
| `-Stage soldier` | 士兵：正常态度；另可用 `-Military 20`、`-Military -20` 测试另外两种态度 |
| `-Stage goods -Item abacus` | 单品鉴定、买入和出货预置 |
| `-Stage military` | 往来簿 → 军阀 → 采购：一件棉袄、两件可穿背心可混交；另有破损／在当背心不能选 |

`-Item` 可用：`abacus`、`copper_handwarmer`、`kerosene_lamp`、`leather_suitcase`、`erhu`、`padded_vest`。支持带 `item_` 前缀。默认完好；`-Condition mended` 为修补档，背心用 `worn`；`flawed` 为最差档。

## 玩法与实现边界

- 第三夜开始，四种新职业加入普通客位；职业先等权，再选择商品。固定人物、特殊客、主线和明确邀约保留。
- 赶工价按报价提交时判断；首次失败即失效。已有实物证据谈出的更低价格仍可成交。乐师的二胡只活当，三夜到期与实际利息仍按现有规则。
- 洗衣妇的修补问话花五分钟，不扣耐心，每次来访一次，只透露一条实际品相。士兵到柜前冻结本次态度，不因刷新而改价。
- 军需改称御寒衣物，棉袄与夹棉背心混合三件，一次奖励50。供给通道仍20%，命中后各半；普通背心可能破损。
- 士兵每件携货20%内部来源标记，按物品实例保存在版本化 shop_growth.town_life.origins；独立随机流，不影响真假、品相、定价或其他随机结果。当前无识别能力与后果，所有玩家模型不含标记。内部查询：TownLife.internal_origin。出售、交付仍留历史，完整命令重放校验阻止伪造。
- 未制作高级鬼货任务，继续只保留抱包客三次成交资格。

## 自动验证

- tests/town_life_rules.gd：职业边界、六商品十八档、概率、交易与混交回滚、隐藏来源、特殊高档货专属价格。
- tests/town_life_rules.gd -- journey：周怀安两种结果，第二十夜与冷读档。
- tests/town_life_campaign.gd：真实新客交易、跨夜、赎当、军需、湿包与抱包回访、来源历史重放。
- tests/town_life_pawn.gd / town_life_gramophone.gd：在新内容清单上复用既有完整鉴定、活当与存档验收。
- tests/town_life_ui.gd [-- wide]：实际游戏的四职业、六货和军需页面。

最终执行结果见 TOWN_LIFE_V48_QA.md。本轮仅供本地验收，未发布。
