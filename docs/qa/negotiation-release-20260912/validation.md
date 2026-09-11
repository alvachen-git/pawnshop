# 独立议价弹窗与谈价反应优先 · 发布验收

基线：远端 main 的 5883ef3（PR #27）；发布分支 codex/trade-negotiation-ui-20260912。
此次在隔离工作树移植本地已经确认的改动，没有整目录覆盖旧开发分支。

## 范围

- 商量价钱改为居中独立弹层：单层滚动、固定返回入口、Esc/遮罩关闭、键盘焦点限制与防点击穿透。
- 交易页删除重复的物品介绍和已知鉴定线索，最新谈价反应在顶部，当前接待的旧回应按新到旧排列。
- 真实公开要价变化使用深绿/暗红与“调低/调高”文字；不变使用普通墨色及“要价未变”。
- 保留 main 的夜间来客操作禁忌、活当背景信息、客户回复、夜市状态及货物鉴定新功能；不回退已有版本。
- 不改议价成本或规则；临时回应不写入存档，换客/读档/新局不串旧回应。内部参数仍不展示。

## 复核

Godot 4.6.1 macOS，发布目录全新导入，串行执行：

| 测试 | 通过检查 | 失败 |
| --- | ---: | ---: |
| run_negotiation_reactions | 18 | 0 |
| run_bargaining | 182 | 0 |
| run_night_market | 38610 | 0 |
| run_goods_expertise | 8544 | 0 |
| bargaining_ui_smoke 1280×720 | 81 | 0 |
| bargaining_ui_smoke 1600×900 | 81 | 0 |
| variety_ui_smoke | 114 | 0 |
| bargain_modal_production_ui（当前默认夜市入口） | 166 | 0 |
| customer_reply_ui | 108 | 0 |
| night_market_ui | 116 | 0 |
| reception_feedback_ui_smoke | 65 | 0 |
| 合计 | 48085 | 0 |

日志同时检查 SCRIPT ERROR、Parse Error、Invalid call、ERROR:、FAIL，无命中。git diff --check通过。当前仓库没有配置GitHub Actions工作流，未宣称CI或Windows真机通过。

实际截图见同目录 modal-1280.png、reaction-1280.png、latest-first-1600.png。当前默认内容是night_market/autosave_v21，未改为旧开发目录的v19入口。

原开发目录的未提交修改、美术资源与文档改动留在原处；只提交本功能涉及的文件。
