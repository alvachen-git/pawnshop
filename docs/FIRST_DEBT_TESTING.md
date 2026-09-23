# 第一账测试入口（整合发布）

最新默认游戏为v39，发布工作树：`/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-release`。

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-release
```

新游戏包含第一账与v38经营鉴定功能；旧档保留原运行。下列v31快捷指令仍可使用，`--dragon-preview=buy`明确进入独立v31测试局，并不代表默认v39。可把下列旧开发路径替换为发布工作树。原开发目录保留用于对照。

# v31 本地测试

本批目录：`/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/dragon-search`。
以下为v31开发期间的测试记录；本次线上发布与主线整合以本文开头及发布报告为准。

## 正常从第一夜开始

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/dragon-search
```

选“新游戏”，进入v31。固定种子可加`-- --seed=42`。旧档按原剧情与原价格运行。

## 直接测试新段落

直接进入确认凤镯归属后的陈小满交谈：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/dragon-search -- --dragon-preview=before-fd_search_motive
```

可将参数末尾换成：

| 参数 | 入口 |
| --- | --- |
| `seller` | 第11夜，凤镯卖家，正常交易与资料查看 |
| `before-fd_search_motive` | 第13夜，双窝镯匣、帮助寻找／暂缓／商谈赔偿 |
| `search-ready` | 第14夜开铺前，寻找行动 |
| `invite-ready` | 第15夜开铺前，已收到口信，可约陆掌眼 |
| `lu` | 第15夜19:00，陆掌眼带龙镯来验看 |
| `quoted` | 同次会面，已报价格，可买入或暂缓 |
| `buy` | 购买专用快捷入口：第15夜，现银369、已报价200，可直接购买；购买后剩169 |

这些入口由**初始300银元、固定种子42的真实经营动作**生成，包含主线商誉与费用。不是直接改夜次或伪造证据。每次启动重新从选定入口开始；档案隔离于`user://tests/v31_preview/<入口>_library.json`，不改正式自动位与手动槽。

建议先用`before-fd_search_motive`：答应后继续当夜经营；次夜准备时委托，当夜收铺读口信；再下一夜准备预约，19:00空柜谈价。正常经营测试路线第15夜完成归还，实际进度取决于玩家选择与资金。

## 回归脚本

在本目录运行`/opt/homebrew/bin/godot --headless --path . --script tests/<脚本>.gd`：

- `dragon_routes`：新游戏完整路线，生成`.godot/qa/v31/`资金充足测试阶段和`v31-natural/`正常经济阶段。
- `dragon_durability`：以上资金充足阶段的保存失败、重试、重复提交和金额边界。
- `dragon_process`：另进程恢复上一步写出的结果；须先运行durability。
- `dragon_edges`：预约、停业顺延、风险/死亡、商誉客流与证据门槛的边界断言。
- `dragon_long`：百夜、超过4096条动作、冷回放及主动结束。
- `dragon_ui`：真实窗口检查，去掉`--headless`；追加`-- wide`为1600×900，默认1280×720。

GUI验收用初始2000的专用测试定义覆盖资金，正式新游戏仍300；上面的快捷试玩入口用正常300银元路线。测试不改变玩家现有档案。

## 2026-09-23 陈小满预约修复

答应寻找或选择“眼下先缓缓”后，陈小满不会次夜自动来。需要重谈、交还或赔偿时，在开铺前选择“约陈小满来谈 · 准备1次”，再于开铺后空柜点击她“说说话”。答应后的寻镯、收信、约陆掌眼可独立推进，不必每日邀请陈小满。

已有v31测试存档可以继续读取，不必新开；须完全退出旧游戏进程，重新启动同一开发目录。旧日志仍按原流程验证，恢复后未预约的陈小满不显示。

专项回归：`tests/chen_invitation.gd`、`tests/chen_invitation_process.gd`、`tests/chen_invitation_ui.gd`（实际窗口，追加`-- wide`检查1600×900）。测试使用独立QA存档，完整线路见[专项报告](qa/chen-invitation-v31/REPORT.md)。

## 钱不够时直接测试购买

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/dragon-search -- --dragon-preview=buy
```

`buy`直接载入资金足够的`quoted`剧情测试档，陆掌眼已在柜前；读完当前短对白后选择“付200银元收下龙镯”。不修改你的正式存档或正常初始资金。每次用此命令启动都重新回到购买前；本次购买进度写入独立的`user://tests/v31_preview/quoted_library.json`。

## 陈小满归还收尾与立绘

退出旧进程后重启本开发目录，读取归还前的v31存档即可查看新收尾，无需新开整局。已完成归还的存档不会重新触发交物或倒退剧情。将双镯交还后逐页继续，最后显示红黑账簿轻动，读完自动离场；Esc也可收起。原物仍只扣除一次，总耗时仍为5分钟。

专项实机脚本：`tests/chen_return_art_ui.gd`，追加`-- wide`为1600×900；使用已生成的`.godot/qa/chen-invitation/return-meeting.json`独立QA样本（测试初始2000，非正常经济试玩）。[截图、日志及验证边界](qa/chen-return-v31/REPORT.md)。
