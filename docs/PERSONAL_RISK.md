# 命灯个人风险 · v22

基于实施开始时的 main `5883ef3261e83d82a139f6e6f6eeb57f1121bbf9`，新运行 `life_lamp_seven`，内容/存档版本 22。继承 main 默认的夜客运行及既有铜镜剧情，没有增加随机危险或玩家治疗剧情。

## 规则

命灯累计损伤为 0–4；0 正常、1 轻度、2 中度、3 高度、4 熄灭死亡。玩家只看到火焰、身体感受和观察文案，不看到损伤数字或等级。

- 普通实际受害一档，明确攻击两档。`PersonalRisk.damage(state, event_instance, total = 1, cause, source)` 的 `total` 是**该事件累计伤害目标**。
- 铜镜追看成功记一档；后续同一个人危机回头看，把该事件升级为两档，只补一档。过期追看、普通使用、收手和正确避险不受伤。
- 个人铜镜事件标识为 `mirror/<visit_id>`；铺内攻击为 `shop/<night>/<item_id>`，分别累计。铺内存放违规及正确覆布只改变店铺危机。
- 最新 main 已有的湿包布也使用统一个人记录：实际影子跟随才受伤，同一块布的一条事件链不重复计伤。新运行不再沿用湿布按夜加重、封存后清零的独立命灯规则；店铺货损规则保留。
- 睡眠、卖镜、覆布和封存包布都不恢复命灯。
- `PersonalRisk.recover(state, event_instance, amount = 1, cause)` 只供明确剧情调用，最低恢复到正常；死亡后无效。恢复不会清除受伤事件的去重记录。
- 双焰字段保留为独立演出扩展，本版恒为关闭；命灯不会自行触发镜中人、敲门或镜面异常。

## 剧情接口

事件选项支持 `personal_damage: true`（默认一档）、`personal_damage: 2`（重伤），或 `personal_recovery: true / 1..4`。同一选项不能同时配置伤害和治疗；每次合法事件发生都有独立实例标识。当前恢复事件只存在于测试夹具。

个人损伤记录保存事件实例、夜次、分钟、受害阶段、损伤/恢复量、事件总伤害、来源和原因。寝屋通过 `PersonalRisk.lamp_state` 读取表现，不再从 `mirror_scar`、`mirror_survived` 推断个人受害。

## 保存与兼容

v22 用公开操作记录重放真实服务，核对损伤来源、恢复、交易、时间、房间阶段和死亡资产；不通过补造封铺或日结来容纳营业中死亡。营业中耗尽命灯立即结束，不收取尚未发生的夜末息费。

最外层操作统一提交存档，死亡、事件和损伤同一次发布。写盘失败回滚全部可变对象，包括客人状态、报价、物品线索、预选当票处置和个人记录；成功后才发出界面通知。操作校验不进行磁盘写入，不产生新的剧情。

实际受害和恢复会自动保存，营业中的自动存档可重建仍在柜前的客人。手动保存保留原来的时机限制和六个共用位置。

正式存档库沿用 `user://save_library/library_v1.json`，新自动位置为 `auto/life_lamp_seven`；独立旧式文件位置为 `user://life_lamp_seven/autosave_v22.json`。旧运行和旧存档仍由旧规则处理，不追溯补扣；读取旧运行后“新游戏”回到 v22。

## 本地查看

在本工作树根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preview_life_lamp.ps1
```

默认直接进入寝屋，可用顶部按钮切换五种灯态；点“返回试玩”恢复正常流程。切换灯态只用于设计预览，不修改真实损伤。

完整 v22 游戏试玩：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preview_life_lamp.ps1 -Play
```

脚本可加 `-Width 1280`（默认 1600），自动寻找已有 Godot 4.6.1，也支持 `-GodotPath`。附带试玩脚本使用 `.artifacts/life-lamp-preview/user` 隔离测试存档，不影响现有个人进度。

[灯态对照](qa/life-lamp/lamp-comparison.png) · [本次验收结果](qa/life-lamp/RESULTS.md)
