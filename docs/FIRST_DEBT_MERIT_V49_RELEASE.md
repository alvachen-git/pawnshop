# v49 第一账阴德与香炉反馈发布

基线为 main 银楼v48、青帮及街巷百业提交 `e62a23d`，在隔离分支 `codex/first-debt-merit-release-v48` 整合。默认运行 `first_debt_merit_release`，独立自动位与档案库遵循v47的版本隔离方式。原开发树 `.artifacts/first-debt-merit` 保留。

## 玩家行为

- 初始隐藏阴德0，范围-100～100；归还双镯加10，实际支付300银元和解加5，第一账每局仅一次。商量、暂缓不加；不影响商誉、经济或风险。
- 现银不足300时付款按钮置灰并直接说明原因，无法点击。商量不扣钱；确认付款原子扣300、耗5分钟并记“和”。归还仍记“清”。
- 陈小满离场后香头短暂闪耀，暖光与舒展烟气约3秒后淡回。危机优先、不阻挡营业；动画开始前保存已播放记录，失败可重试。
- 红黑账簿与主动翻阅后的清／和回响保留。

## 主线整合与兼容

v49复制银楼v48运行配置，只增加新运行ID和香炉事件；保留银楼解锁、银价与收货，以及开铺前回收、陆掌眼卖货与教学、利息选择、相机及留声机鉴定。街巷百业、青帮、特殊客与周怀安独立入口维持主线现状，没有擅自并入默认局。

v42阴德原型、v43调整版与主线上同号其他运行按各自运行ID识别，旧存档不迁移。原型v42赔偿仍10，调整版v43为5。v48及更早无阴德运行不补奖；新增 `scenes/start_recycler_v47.tscn` 保留v47入口和档案库。

## 启动

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-merit-release
```

直接测试整合版赔偿，从商量开始：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt-merit-release -- --merit-release-preview=pay
```

夹具来自正常300初始资金的经营回放：第15夜、502银元，付款后202。归还预览换为 `--merit-release-preview=return`：第17夜、259银元、双镯齐备。均使用隔离测试库；正式存档不受影响。旧 `--merit-preview` 保留v43原型测试功能，不是整合版。

## 验收

[发布验收日志与截图](qa/first-debt-merit-release/REPORT.md)。Windows试玩包和Windows实际运行不在本次发布范围。
