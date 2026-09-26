# v42：隐藏阴德与香炉反馈

本地开发基线为已合并的 `0e6f595`（v41）。开发工作树 `.artifacts/first-debt-merit`，分支 `codex/first-debt-merit-v42`。不推送、合并或制作试玩包。

## 规则

阴德初始0、整数范围-100～100，与商誉独立。归还双镯、现金和解均在实际交物／付款时加10，每局第一账仅一次；商量、暂缓、拒绝和出售不加。本批没有其他增减途径，不影响经济、风险、客流和结局。

金额／库存／结案／阴德共同原子保存。动画播放记录使用既有事件历史与动作日志，回放核对实际值，拒绝修改数值或伪造播放记录。v41及更早档不增字段、不补奖。

玩家正文、状态栏、账本、结算和存档摘要不显示阴德名称或数值。开发测试可以读取 `RunState.hidden_merit`。

## 香炉

陈小满结案对白读完或用Esc收起，离场后播放3秒：0～0.5秒香头微亮，0.5～2秒暖白烟气舒展，2～3秒淡回原状。复用原香炉和烟气材质，无新增资产、音效、字幕、收益弹窗、常驻光效。

柜台被菜单／册页／对白遮挡、存在危机或香烟异常时暂缓；恢复安全可见柜台后播放。播放中有危机则立即停止，死亡或离开柜台也停止。不消耗游戏时间、不抢经营焦点，不表示危险已经解除。

开始播放前原子保存已播放记录；保存失败显示真实错误及重试／稍后，阴德保持已经结案的数值、动画仍待播放。退出在播放前可补看，开始后退出不重播。内部表现事件不占普通事件名额、不出现在剧情列表、不参与随机事件计数。

红黑账簿异动与主动翻阅后的“清／和”回响照旧；动画不授予任何阴账知识。

## 本地启动

正式新游戏：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-merit
```

直接测试归还结案：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-merit -- --merit-preview=return
```

测试现金和解：末尾改为 `--merit-preview=pay`。

两份快速入口均来自初始300银元、种子42正常经营的合法操作回放，归还为第21夜，和解为第22夜；只跳到结案前，不直接篡改现金或阴德。点击陈小满 → 说说话 → 选择归还或交付款项，读完后看左侧香炉。快速入口使用独立测试档案库 `user://tests/v42_preview/`。

默认新运行 `first_debt_merit`，自动位 `auto/first_debt_merit`，兼容路径 `user://first_debt_merit/autosave_v42.json`；六个手动槽共用。旧局不升级，体验新机制需新游戏或上述快速入口。

## 验收

见 [本批报告](qa/first-debt-merit/REPORT.md)。自动测试脚本为 `merit_routes.gd`、`merit_durability.gd`、`merit_process.gd`、`merit_recovery_durability.gd`；实窗测试 `merit_ui.gd`，传 `-- wide` 检查1600×900。均在项目路径通过 Godot `--script tests/脚本名` 运行。
