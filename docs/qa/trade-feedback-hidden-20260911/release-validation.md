# 远端整合验收 · 2026-09-11

基线：`origin/main` 的 `3b729326f386a367160569f03fe974942b99d583`。隔离分支：`codex/trade-feedback-release-20260911`。环境：macOS / Godot 4.6.1；此记录不代表 Windows 实机或安装包验收。

保留 main 的 v21 夜市默认入口、职业赎当背景、四段灯光、寝屋及睡眠确认进入次日的行为。整合中适配新版交易布局；灯光刷新保留人物与物品动画透明度。夜客只报价一次的限制及湿布禁忌继续在报价前显示。议价轮次与耐心数值按负责人确认隐藏，不改底层规则。

## 最终复测

核心及跨进程：16 组，116,662 项断言，0 失败。

| 套件 | 断言 |
| --- | ---: |
| run_all | 1,800 |
| run_room | 701 |
| run_market | 5,931 |
| run_complete_seven | 22,189 |
| run_pawn | 107 |
| run_bargaining | 182 |
| reception_feedback_tests | 113 |
| customer_departure_tests | 78 |
| run_opening | 100 |
| run_pawn_chance | 41,813 |
| pawn_chance_merge | 41 |
| run_night_market | 38,610 |
| run_early_redemption | 4,736 |
| pawn_chance_checkpoint 写 / 读 | 98 / 10 |
| run_night_market process-read | 153 |

实际窗口：21 组，2,549 项断言，0 失败。

| 套件 | 1280×720 | 1600×900 |
| --- | ---: | ---: |
| receipt_ui_smoke | 103 | 103 |
| trade_feedback_lifecycle_ui | 32 | 32 |
| bargaining_ui_smoke | 58 | 58 |
| waiting_departure_ui_smoke | 59 | 59 |
| pawn_ui_smoke | 100 | 100 |
| night_market_ui | 116 | 116 |
| night_lighting_ui | 76 | 76 |
| pawn_chance_ui | 131 | 131 |
| opening_ui_smoke | 94 | 未重跑 |
| integrated_ui_smoke | 503 | 未重跑 |
| seven_ui_smoke | 321 | 未重跑 |
| art02_ui_smoke | 200 | 未重跑 |
| manual_save_ui_smoke | 81 | 未重跑 |

合计 **37 组、119,211 项断言，0 失败**。最终日志位于 `release-logs/`；扫描无 `SCRIPT ERROR`、`Parse Error`、`Invalid call`、`ERROR:`、`FAIL`，`git diff --check` 通过。人工核对新版夜客禁忌与职业背景截图，交易按钮及活当条款可读。

首次整合测试发现夜市测试菜单受已有存档影响、旧 Art02 验收仍要求成交瞬间清除物品；分别改为测试专用新局菜单、演出结束后检查。最终数据均来自修正后重跑，不把首次失败计作通过。原始主工作区和无关美术草稿不纳入发布。

推送前未发现仓库配置 GitHub Actions 工作流；本记录仅声明上述本地整合验证，不声称线上 CI 或 Windows 检查通过。
