# v28：梦中求助与对质入口提速

> 历史版本说明。当前默认为 [v29夜半来声](MIRROR_DREAM_V29.md)，本页仅描述v28自动入梦与当时的交付。

基于线上 main `3a30f42881c4e407e3e7ad83bd2de686eef86b5c`，本地分支 `codex/mirror-dream-performance`。本批为本地交付，未推送或合并。默认新游戏为独立 v28 `mirror_dream_ten`，保留十夜经营、阿七与四种铜镜结局。成长设施继续使用原独立入口。

## 完整启动指令

当前开发工作区在 `.tools/v25-playable`。在任意 PowerShell 窗口中粘贴：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v28.cmd"
```

快速查看托梦（与正常存档隔离）：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v28.cmd" -Stage bedtime
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v28.cmd" -Stage dream
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v28.cmd" -Stage after
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v28.cmd" -Stage ready -Wide
```

- `bedtime`：第四夜寝屋，点击就寝并确认，完整体验入梦。
- `dream`：未读完的梦境，从第一页开始；可收起，再用寝屋的“继续梦境”返回。
- `after`：已听完求助，查看铜镜物品见闻；继续下一夜后，原有调查入口按材料开放。
- `ready`：丈夫已完成三段问答，可请女子现身，检查进入对质的流畅度。
- 不带 `-Wide` 为1280×720；带上为1600×900。第一次生成测试档会稍等，之后会使用已验证的测试档。

启动器为纯 ASCII 的 CMD/PowerShell 包装，兼容 Windows PowerShell 5.1，无需修改系统脚本策略。`-Check` 仅检查启动后退出。测试档使用工程内 `.godot/test-appdata`，不会覆盖正常存档。普通新局自动位为 `user://mirror_dream_ten/autosave_v28.json`；存档库按运行隔离。历史 v27 可运行 `scenes/start_v27.tscn`，历史 v26 使用原有 `play_v26.cmd`。

## 梦境规则

以实际收镜日期为准：收镜后的下一夜入睡，仍持有铜镜且未完成结局，女子入梦一次。覆红、没照过客或未查旧档都不妨碍。卖镜不播；第十夜收镜的下一夜仍待发生，不增加第十一夜。危机先处理，死亡后不播。

八页依次为入梦、现身、等待、谋生求药、典镜、求助、旧当票方向、醒来。女子直接站在普通客人的柜前位置，不在镜框内；以暗光、偏冷的肤色、眼角沿脸颊流下的暗红血泪和衣摆轻微虚化表现梦中异样。等待与悲伤两种表情均保留血泪，沿用既有人物身份和水粉画风。女子的求助是自述，不提前透露母子死讯、货郎身份、另组家庭或顾先生隐瞒；不替玩家答应，也没有奖励选项。

翻页与收起不耗时、不扣命、不写调查事实。收起后返回同一阅读页；重新读取未完成存档则从第一页播放。未读完不能绕过梦境推进日期。最后“醒来”把梦境记录和原有睡眠结算一次提交，失败全部回滚，原页可重试。已完成不重播。

铜镜见闻中的“梦中求助”只记实际听闻，并按已查材料给出下一项原有调查方向。查访仍付原有时间和费用，可迟查、完全不查或后来卖镜。

## 性能与兼容

对质入口保留原有校验、完整回滚快照、日志和存档校验。每次通知内复用读取模型；常驻提醒使用轻量状态；隐藏页在打开时构建；对质覆盖下的柜台在收起时更新；纸张按钮复用中文字体。没有删减规则或将长等待藏进动画。

四种结局、固定交涉结果与三段各5分钟保持不变。旧内容和存档不迁移、不补播。重要情报奖励、怨气用途和换物补救仍未开发。

测试、性能明细和实际窗口截图见 [本批验收记录](qa/mirror-dream/REPORT.md)。
