# v25 阿七陪伴与旧票引子验收

> 本页保留首批交付证据。后续已按玩家反馈调整柜沿遮挡和夜间肤色，最新图像与窗口验证见 [光照修正记录](../aqi-companion-lighting/NOTES.md)。

日期：2026-09-16。基线 main `1a95b11`，开发分支 `codex/next-development-20260915`，工作树 `.artifacts/development`。本报告描述本地源码验收，未推送、合并或生成试玩包。旧v24与更早数据保持冻结。

## 1. 自动回归

macOS / Apple M4，Godot 4.6.1。以下均为最终运行结果，日志未出现 `SCRIPT ERROR`、`Parse Error`、`Invalid call`、`ERROR:` 或失败标记。

| 测试脚本 | 通过 / 失败 | 证据 |
| --- | --- | --- |
| `tests/run_aqi_companion.gd` | 3261 / 0 | [core.log](core.log) |
| `tests/aqi_companion_durability.gd` | 164 / 0 | [durability.log](durability.log) |
| `tests/aqi_companion_coexist.gd` | 951 / 0 | [coexist.log](coexist.log) |
| `tests/aqi_companion_process.gd` | 439 / 0 | [process.log](process.log) |
| 冻结v24 `tests/run_aqi_investigation.gd` | 2711 / 0 | [v24-regression.log](v24-regression.log) |
| 冻结v22 `tests/run_aqi.gd` | 4553 / 0 | [v22-regression.log](v22-regression.log) |
| `tests/run_all.gd` | 1800 / 0 | [core-legacy.log](core-legacy.log) |
| 合计 | **13879 / 0** | 不含下列真实窗口测试 |

覆盖结果：

- 默认内容25、十夜结束、六个基础来客位及原四类夜客调度；64个种子检查客流计划，42的六条完整调查／阿七路线，另以7、2025、91走完整十夜，其中91提前关铺、连续婉拒。拒镜、售镜与不调查均不阻断初见和阴账。
- 初见开铺后零耗时；姓名、帮助、婉拒、夹纸发现／未发现；寝屋线索不能提前查看，复看不重复历史；收铺不重复初见。
- 第二次来访按修风车结果回应；两种陪伴许可、当日拒绝后次夜再问、主动请走和跨夜返回；每日聊两句、折小船／小鸟及复看已选结果。
- 普通买卖、铜镜查访和丈夫会面使用原流程；另以真实活当产生第八夜原当户赎回，验证陪伴在场但不能聊天、办理费用和完整回放有效。阿七没有客位或物品实例。
- 真实5分钟动作与有中央客人时的鉴定动作从21:55跨至22:00，动作完成后隐藏，原客人仍可继续接待；不添加自动告别事件；提前关铺隐藏。营业中手动保存仍被拒绝。
- 开铺、初见、再访、许可、三天首次闲聊及旧票的写盘失败：内存完整回滚、原磁盘字节不变、重试成功且只新增一次，自动位可解码恢复。
- 在独立生产／读取进程间，以清空缓存的完整动作回放恢复各段快照，并续走下一段。拒绝伪造许可、离开、旧票、核对状态、版本、金钱，以及跳过初见直接进入寝屋。
- 第十夜旧票独立于陪伴、帮助、草图；暂收不显示“七”字和第五夜出货确认，对照后即显示并可从账本复查。票据不产生库存、金额或财务债务。
- 第十夜危机存在时，旧票仅排队、界面隐藏且选择被拒绝；危机处理后再展示。真实未覆镜的连续受害仍可在见过阿七后死亡，死亡立即清除后续呈现。未为阿七强制保命。

## 2. 真实窗口检查

通过实际 macOS OpenGL/Metal 图形窗口运行 `tests/aqi_companion_ui.gd`，不是 headless 或虚拟布局。两种窗口的鼠标与键盘事件均通过Godot窗口输入路径提交，截图取自实际渲染视口。

| 尺寸 | 检查结果 | 日志 |
| --- | --- | --- |
| 1280×720 | 124项通过，0失败 | [ui-1280.log](ui-1280.log) |
| 1600×900 | 124项通过，0失败 | [ui-1600.log](ui-1600.log) |

检查了开铺前无人预告、正常光照初见、全部选项可见、帮助／问名／夹纸、许可后小头像、普通客人同屏、忙碌提示、聊天与理纸、Esc收起和回到头像、Enter重开、同页重开首选项焦点、账本与菜单收起聊天、主动请走、22:00隐藏、旧票核对、账本「旧事」与回房，以及旧v24载入后标题新开返回v25。修正了日常对白遮挡账本入口、同页重开不恢复选项焦点的问题。

主要截图：

| 场景 | 1280×720 | 1600×900 |
| --- | --- | --- |
| 第七夜开铺初见 | [初见](1280-arrival.png) | [初见](1600-arrival.png) |
| 左侧陪伴与客人同屏 | [同屏](1280-customer.png) | [同屏](1600-customer.png) |
| 日常三选项 | [闲聊入口](1280-topics.png) | [闲聊入口](1600-topics.png) |
| 折纸选择 | [小船／小鸟](1280-paper_options.png) | [小船／小鸟](1600-paper_options.png) |
| 旧票核对 | [日期疑点](1280-ticket_comparison.png) | [日期疑点](1600-ticket_comparison.png) |
| 账本复查 | [旧事](1280-old_affairs.png) | [旧事](1600-old_affairs.png) |

## 3. 目视与试玩结论

代理逐张检查真实渲染截图：左侧阿七面向中央，头部在1280下约83像素、1600下约104像素；柜沿遮住身体，仅露少量衣领，未新增手臂接触错误。与财神香、中央客人、货物和经营入口分开。表情、绿衣与双辫连续；日常纸面收短后可以直接打开账本。开铺初见保持原已发布的搭桌立绘与正常开铺光照。旧票日期线索和选项在两种尺寸下可读。

上述为代理自动操作加截图目视复核，不等同于用户本人连续试玩签收。阅读节奏、亲近感和是否愿意再见阿七仍需用户实际试玩评价。本批没有Windows运行、打包验收、CI或远端发布结果。

## 4. 复现

从 development 工作树运行；导入后按顺序生成快照，再检查恢复和窗口：

```sh
/opt/homebrew/bin/godot --headless --editor --import --quit --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development
/opt/homebrew/bin/godot --headless --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/run_aqi_companion.gd
/opt/homebrew/bin/godot --headless --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/aqi_companion_durability.gd
/opt/homebrew/bin/godot --headless --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/aqi_companion_coexist.gd
/opt/homebrew/bin/godot --headless --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/aqi_companion_process.gd
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/aqi_companion_ui.gd
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/development --script tests/aqi_companion_ui.gd -- wide
```

隔离测试数据在 `.godot/qa/v25`。本目录保存代表性完整动作快照、最终日志、两种尺寸截图及 [SHA256SUMS](SHA256SUMS)。这些文件用于测试，不能写入玩家的共享档案库。正常试玩见 [剧情说明](../../AQI_COMPANION_V25.md#试玩入口)。
