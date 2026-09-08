# 泣血铜镜 v16 合并前验证

2026-09-08。在独立工作区基于 `origin/main` 的 `fbd0d78`（七夜整合与开铺准备）整理并验证本次变更。Godot 4.6.1，macOS；导入项目后串行执行。

24项全部通过。最终测试日志无 `SCRIPT ERROR`、`Parse Error`、`Invalid call`、`ERROR:` 或失败标记。完整套件摘要见 [results.json](results.json)。

| 检查 | 结果 |
| --- | --- |
| `free_cloth_tests` | FREE CLOTH TESTS: 303 passes, 0 failures |
| `bell_tests` | BELL TESTS: 195 passes, 0 failures |
| `manual_save_tests` | MANUAL SAVE TESTS: 1163 assertions, 0 failures |
| `run_mirror_chapter` | MIRROR CHAPTER TESTS: 4090 passes, 0 failures |
| `mirror_chapter_checkpoint` | MIRROR CROSS PROCESS: 3 assertions, 0 failures |
| `run_all` | M0–M7 TESTS PASSED · 1799 assertions |
| `run_bargaining` | BARGAINING TESTS: 182 assertions, 0 failures |
| `run_pawn` | PAWN TESTS: 107 passes, 0 failures |
| `run_room` | ROOM TESTS: 701 assertions, 0 failures |
| `run_opening` | OPENING TESTS: 100 assertions, 0 failures |
| `run_variety` | VARIETY TESTS: 17079 passes, 0 failures |
| `run_market` | MARKET TESTS: 5931 passes, 0 failures |
| `run_four_night` | FOUR NIGHT TESTS: 42532 passes, 0 failures |
| `run_seven_night` | SEVEN NIGHT TESTS: 136843 passes, 0 failures |
| `run_integrated_seven` | INTEGRATED SEVEN TESTS: 8011 passes, 0 failures |
| `preparation_tests` | PREPARATION TESTS: 305412 assertions, 0 failures |
| `mirror_chapter_ui_smoke_1280` | MIRROR CHAPTER UI: 861 assertions, 0 failures |
| `mirror_chapter_ui_smoke_wide` | MIRROR CHAPTER UI: 861 assertions, 0 failures |
| `bell_ui_smoke_1280` | BELL UI: 88 assertions, 0 failures |
| `bell_ui_smoke_wide` | BELL UI: 88 assertions, 0 failures |
| `art04_ui_smoke_1280` | ART04 UI SMOKE: 118 assertions, 0 failures |
| `art04_ui_smoke_wide` | ART04 UI SMOKE: 118 assertions, 0 failures |
| `preparation_ui_smoke_1280` | DEFAULT PREPARATION UI: 90 assertions, 0 failures |
| `preparation_ui_smoke_wide` | DEFAULT PREPARATION UI: 90 assertions, 0 failures |

铜镜领域测试包含六条七夜路线、能力与议价记录校验、正常检查独立取证、调查及阶段选择。红布检查覆盖零分钟、零耗时行动次数、旧v16历史记录回放与关门禁忌。手动存档与跨进程读取均通过。

实际窗口分别使用1280×720、1600×900；从正式标题进入，点击红布、窥镜、对话、交易、调查和收尾选择，并验证铃铛短按、取消长按、完整长按及空柜台等客。准备检查确认新版仍可完成第二夜准备并开铺。检查了柜台与红布操作截图。

初轮窗口检查暴露了两处测试与当前界面的不同步：铜镜脚本仍找已撤下的桌面按钮；铃铛位置检查排除了恰在边界上的合法位置。测试现改走正式情境入口，并按铃铛实际矩形判断所在区域；重跑后零失败，未改动游戏规则以迎合测试。

本次为源码交付，未生成或验证新的Windows发行包。旧版本的历史内容与已发布验证资料保留；最终对质、女主人离去和物品联动仍属后续开发。
