# 开铺准备 · 版本15

2026-09-07：v15新开局从第二夜起开放。第一夜保留开场流程；旧局继续原规则。当前默认v16铜镜第一章继承本页准备规则，v15独立入口仍保留。

## 玩家操作

每夜最多准备两次，每项每天一次，不推进营业时间。可以直接点「开铺营业」，放弃剩余次数；已知消息免费复看。按钮只显示动作名称、费用与次数，具体效果放在鼠标悬停说明中。

| 动作 | 费用 | 实际效果 |
| --- | --- | --- |
| 招揽客人 | 3大洋、准备1次 | 增加1位普通潜在来客；不保证成交或利润 |
| 托人捎话收货 | 准备1次 | 选定货类，替换1位未透露的普通来客；总人数不变，取消选择免费 |
| 备茶候客 | 5大洋、准备1次 | 当夜普通新客多等20分钟，包括招揽和定向来客；议价耐心不变 |
| 打听来客 | 准备1次 | 获知2位普通来客的大致时段、货类及出售／活当意向 |

定向收货可选瓷器、金属器、首饰、钟表、文房、绣品。剧情人物、关键活当、钢笔机会及其他特殊编排不被替换；已取得的来客口信不会因后续准备而失效。

招揽的新客安排在18:00—01:30之间，按5分钟步长抽取，与已有新客至少相隔15分钟；赎当办理造成的顺延仍然适用。早关门、超时和未接待均按原规则处理。

第四至六夜保留一次性的「调查收货消息」，耗准备1次，提前得知第六夜钢笔收货细目；到第六夜19:00自然公开。新规则不再要求联系收货人取得介绍信，实际出售仍受货类、品相、时间和往返20分钟限制。

## 运行、账目与兼容

- 独立运行标识 `prepared_seven`，内容与存档版本15；独立清单 `data/preparation_manifest.json`，场景 `scenes/prepared_seven.tscn`。
- 自动位置 `auto/prepared_seven`，独立旧式路径 `user://prepared_seven/autosave_v15.json`。版本14与更早存档保留自己的内容入口、介绍信规则和第四夜准备门槛。
- 当前默认标题入口使用版本16，继承 `variety.preparation_version = 1`。版本15的独立场景保留，历史版本继续通过存档库读取。
- 基础来客编排不被改写；准备记录保存动作、费用、选类、影响的来客和已知口信。统一回放生成有效编排，运行和存档校验使用同一结果。
- 准备费用进入流水和日结的「准备支出」，扣减经营净收益；夜初现金保留准备前余额。重复提交不重复扣钱，保存失败恢复费用、次数和来客。
- 营业期间不能手动保存的原规则保留。开铺按钮先保存准备完成的开铺前状态，再进入营业；关门未结算时可手动保存。

## 验证

```sh
godot --headless --path . --script res://tests/preparation_tests.gd
godot --path . --script res://tests/preparation_ui_smoke.gd
godot --path . --script res://tests/preparation_ui_smoke.gd -- wide
godot --path . --script res://tests/preparation_ui_smoke.gd -- default
godot --path . --script res://tests/preparation_ui_smoke.gd -- wide default
```

跨进程使用 `tests/preparation_checkpoint_process.gd`，依次传入 `start / attract / tea / finish / second / target / intel / third / sixth / end / read`。Windows源码验证脚本已加入相同准备测试，本次实际执行平台为macOS。

本地最终记录位于 `.godot/qa/preparation_v15/final/results.json`：32项串行检查全部通过，包含256种子的准备编排、旧版经营／存档回归、11步跨进程恢复、版本15双分辨率完整七夜、当前默认入口双分辨率第二夜准备，以及旧版UI和标题页。

实际查看了准备页、悬停说明、类别选择、准备支出流水、来客口信及收货页面截图。最终验收日志无 `SCRIPT ERROR`、`Parse Error`、`Invalid call`、`ERROR:` 或失败标记。早期调试日志单独保留，不作为最终通过证据。

本次合并为源码更新，不制作安装包。

2026-09-08发布前在独立目录重跑上述32项，并补查5项铃铛／美术回归；37项全部通过。详见 [发布验证](qa/preparation-v15/validation.md)。
