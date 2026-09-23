# 默认完整新局整合验证

日期：2026-09-22；基础为线上 main `fc90ece`（PR #52），交付前再次通过远端引用核对。环境：macOS / Godot 4.6.1。

## 行为与改动

`scenes/start.tscn` 和 Windows 常规 `play.cmd` / `play-unified.cmd` 统一进入 `unified_ten`（十夜，内容及存档版本30）。主线、阿七、铜镜调查和托梦沿用当前 main；设施、知识、折扇品相和议价启用 PR #52 的规则；军阀、棉袄采购、牌子和口碑从 PR #50 的独立工程移入共享系统。

新配置使用原经营数值和实际解锁条件，不预发钱、装备、关系或支线进度。旧运行的数据文件不改写，旧档按原 manifest 读取，新游戏始终回到统一默认配置。

整合额外修复：知识柜学会后鉴物台图录仍隐藏；真迹压价记录未接入普通口碑；军方让价与折扇专用收购价不同步；真实破损让价需要同步公平报价基准。所有变更保留旧运行的功能开关与存档结构。

## 已执行

- campaign: MIRROR REUNION: 3528 passes, 0 failures
- facilities: UNIFIED FACILITIES: 130 passes, 0 failures
- procurement: UNIFIED PROCUREMENT: 125 passes, 0 failures
- saves: UNIFIED SAVES: 27 passes, 0 failures
- aqi: AQI COMPANION: 3299 passes, 0 failures
- social: SOCIAL V27: 1706 passes, 0 failures
- introduction: MILITARY INTRODUCTION: 176 passes, 0 failures
- history: V27 BOOK HISTORY: 201 passes, 0 failures
- fan_condition: FAN CONDITION: 2078 passes, 0 failures
- knowledge: SHOP KNOWLEDGE: 140 passes, 0 failures
- ui1280: UNIFIED UI: 49 assertions, 0 failures
- ui1600: UNIFIED UI: 49 assertions, 0 failures

统一剧情测试从第一夜真实操作推进十夜，覆盖铜镜调查／会面／四结局、忽略或第二夜响应门外哭声、阿七六条选择路线。设施测试同一新局完成孙大元介绍、接单、知识学习、两夜升级、工具购买、自然折扇来访、选点鉴定与压价交易；采购测试实际买入三件自然生成的棉袄后交货，验证奖励、重复提交与写盘失败回滚。

存档验证包括不同进程生成和冷回放、手动保存封铺状态后重载合账并回房、历史军阀／折扇／托梦配置载入后新游戏返回统一默认。测试均使用隔离存储，不改写玩家存档。

真实 OpenGL 窗口在1280×720和1600×900完成鼠标操作：默认标题新游戏、孙大元三段交谈、往来簿接单、设施柜学习、折扇破损检查与图像选点落笔。截图已人工检查。

- [军阀登门](qa/unified-full-game/1280-military.png)
- [统一游戏采购簿](qa/unified-full-game/1280-procurement.png)
- [知识学习后的鉴物台](qa/unified-full-game/1600-appraisal.png)

原始通过日志在 `docs/qa/unified-full-game/`。首次新工程资源导入在大量历史截图导入尾段退出，第二次导入成功；之后上述真实窗口和脚本验证未出现资源缺失或脚本错误。

## 未执行

Windows实机、发行包和线上CI未执行；未重新制作试玩包。自动脚本覆盖的是列出的路线和组合，不代表穷尽所有随机经营选择。Windows脚本只做静态检查，常规入口已统一，但启动仍需现有Godot环境。
