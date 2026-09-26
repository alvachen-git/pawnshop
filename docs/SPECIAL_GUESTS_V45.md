# 湿包客修订试玩 v45

2026-09-25。基于现有 `codex/special-guests` 隔离试玩继续修改，未推送、未发布。

## 玩家确认的规则

- 进入卧房空闲状态后1—2秒出现第一段异响，后续播放起点间隔4—8秒；片段不重叠、不连续重复。菜单、物件观察、梦境、就寝确认框和剧情期间暂停，恢复后重新计时。
- 购买当夜算第1夜。第5次持货就寝开始，每晚扣1格命灯；每件物品每夜只扣一次。读档、重复点击、恢复命灯均不能让同夜重复扣减。
- 只检查湿包客卖出的具体实例。在库和陈列都算持有；售出、交付、转出、损失后立即停止后续异响和扣减。同名普通货不受影响。物品离手不会自动补回已失命灯。
- 第4夜开始出现久留异常；第5夜起就寝前出现胸闷、哭声与灯火颤动的预兆。扣灯后的卧房叙述逐次加重，第四次累计损耗可按既有命灯规则进入终局。哭声为本轮增加的叙述，音频仍使用既有滴水、木响、低沉摩擦片段。
- 不恢复旧版禁问伤害、湿灰损货、封布操作，也不修改其他特殊客的交易与回访规则。

## 启动

在 PowerShell 中：

```powershell
# 完整18夜，新规则独立存档
& "D:\CodexData\runs\pawnbroker-special-guests\play-special-guests.cmd"

# 新立绘及湿包客交易
& "D:\CodexData\runs\pawnbroker-special-guests\play-special-guests.cmd" -Stage wet

# 第5个持货夜：进入后试听，再点击就寝，观察扣灯和哭声叙述
& "D:\CodexData\runs\pawnbroker-special-guests\play-special-guests.cmd" -Stage bedroom-aged

# 刚买入后的卧房，只试听，尚不扣灯
& "D:\CodexData\runs\pawnbroker-special-guests\play-special-guests.cmd" -Stage bedroom
```

加 `-Wide` 使用1600×900；默认1280×720。预置进度不保存。

## 隔离及实现

- 新清单 `data/special_guests_wet_v45_manifest.json`，新局 `special_guests_wet_v45`，规则版本2；新场景 `scenes/start_special_guests_wet_v45.tscn`。
- 正式试玩保存库 `user://special_guests_v45/library.json`，备用自动存档路径 `user://special_guests_v45/autosave_v45.json`。v44原场景、清单、局定义和旧文件保留；不追溯给旧局加扣灯规则。
- 持货时间来自已有 `acquired_night`，持有状态来自物品实例与成交来源。伤害复用既有个人命灯记录，键为物品实例与夜次；不新增存档字段。音频随机数与玩法随机序列分离。
- 采用用户选择的第1张：沉重湿包、中年客人。原图具有透明通道，直接使用选定原图，未替换成后续编辑图。新资源 `assets/art04/customers/special/wet_bundle_v45.png`，独立资源ID `special.wet_bundle_v45`；原住户与旧入口立绘不受影响。

## 验证与预览

- `tests/wet_goods_v45.gd`：364项通过，覆盖第4/5/6夜边界、连续四次扣减及卧房死亡、预警、陈列、同名普通货、售出/转出/损失、同夜去重、治疗后去重、存档篡改拒绝、真实写盘与存档库读回、冷启动回放、写盘失败回滚及v44兼容。
- `tests/special_guests_rules.gd`：原v44两个完整18夜分支，867项通过。
- `tests/special_guests_ui.gd`：1280×720和1600×900各49项通过，已核对截图真实像素尺寸；立绘、短延迟、4—8秒计时、暂停/恢复/读档、第五夜警示、哭声叙述和继续睡醒均通过。
- `tests/run_personal_risk.gd`：2364项通过。`tests/run_night_market.gd`旧夜客回归38610项通过。
- Windows PowerShell 5.1真实启动 `-Stage bedroom-aged -Verify` 返回0；导入与运行无脚本错误。`git diff --check`通过。
- 截图：`.godot/qa/special-guests/{1280,1600}_wet_cloth.png`、`*_wet_warning.png`、`*_wet_pressure.png`。
- 带声音预览：`.godot/qa/special-guests/wet-v45-bedroom.mp4`。直接录制游戏音轨，峰值约0.086，无削波；采样检查见 `wet-v45-audio-check.json`。录像退出时引擎报告1个资源尚占用，不影响有效的视频和音轨；交互UI与规则回归无脚本错误。

## 当票页消息串页修复

2026-09-25：账本结构化页签不再显示全局最近操作消息，避免购买铜镜、翻查短记后的剧情文字混入当票、流水和债务页。本页操作失败仍显示在发起操作的页签，切页、关闭或其他操作后不会污染其他页。铜镜剧情、物品记事及存档数据不变。

验证：`tests/art03_ui_smoke.gd -- ledger-context` 与 `-- ledger-context wide` 在当前v45入口各31项通过，覆盖真实铜镜短记消息、空当票、真实活当生成票据、金额与到期信息、切页无状态变化、本页错误仍可见。原旧入口全流程中有过时的营业按钮步骤，本次未把该旧流程计为通过。`git diff --check`通过。

实际画面：`.godot/qa/ledger_clean_1280_ledger_empty.png`、`ledger_clean_1280_ledger_populated.png`，以及对应1600×900版本。
