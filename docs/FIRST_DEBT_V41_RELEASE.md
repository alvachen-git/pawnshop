# 第一账补救发布整合 · v41

基于线上 main `a2c4d20`，保留金镯鉴定／美术、店铺背景音乐与夜间钟声，整合本地 v40 第一账核实、赔偿收尾、凤镯预约补买、阿七主动提醒及头像反馈、鉴定栏查看内圈与凤尾。

默认运行`first_debt_recovery_release`、内容版本41、自动位`auto/first_debt_recovery_release`。线上v40 `bangle_unified`与本地v40 `first_debt_recovery`继续按各自manifest读档，不迁移既有事实；返回默认标题的新游戏进入v41。六个手动槽共用。

## 本地启动

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-recovery-release
```

直接测试第十一夜卖家：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-recovery-release -- --recovery-release-preview=seller
```

快捷阶段还有`recall`（营业前约回）、`truth`、`compensation`、`pay`。来自v41初始300银元、种子42的正常行动回放，预览档案隔离在`user://tests/v41_preview/`，不覆盖正式档。旧`--recovery-preview`仍运行本地v40。

## 验证与范围

验证记录见[发布整合验收](qa/first-debt-recovery-release/REPORT.md)。v40原开发说明与截图保留，当前默认与入口以本文为准。没有制作Windows试玩包，没有验证完整四十九夜内容。
