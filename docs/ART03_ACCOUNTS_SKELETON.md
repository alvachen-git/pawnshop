# ART03：库存、当票、账本与日结美术骨架

2026-09-04。对应优先级 1，按项目 A07/A08/A10 与 F01/F02 的方向继续低保真验证。复用 ART02 的纸墨主题与物品缩略图，不引入正式精绘或复杂特效。

## 本地试玩

默认游戏主场景已接入：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn"
```

独立美术试玩使用同一套主场景和单独存档：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn" --scene res://scenes/art03_review.tscn
```

该入口沿用 ART02 清单选择当前 M7 内容，保存到 `user://tests/art03_review.json`。没有预造的现金、物品或交易记录，先开铺完成一笔收购／活当即可查看货签。清单引用工作区数据，未冻结内容快照。

## 玩家可见结构

| 页面 | 骨架 |
| --- | --- |
| 库存 | 铺中货物／已售与已赎两种筛选；现货件数、现货成本占款、在当本金分列。货签显示缩略图、名称、原始成本或放款、已知估值和状态章。 |
| 货物详情 | 展开已见物证与各买家的出售入口；不可用原因直接显示。未揭露的品相和真值不进入详情。在当货物通往当票，持有鬼货通往原有存放与规矩界面。 |
| 账本流水 | 默认本夜，可切换全部；按最近交易在前显示物品、收支类型、金额、时间、余额和已实现毛利。 |
| 债务 | 借据本金、每日利息与铺面开支、短款金额、补齐夜次；另列已计息费、实际付款与经营净收益。沿用原有真实借据和破铺历史。 |
| 当票 | 每张独立纸票，票号、物品、当户、本金、赎金、入当及到期夜次；办理窗口和耗时。原有赎回／续当操作更新票据与账目。 |
| 日结 | 夜末现金、现金变化、经营净收益（无息费约定时为交易毛利）分列；现金收支逐行对账。短款与期限优先显示；下一夜／合卷按钮固定在下方。 |

状态章由真实 `ownership_state` 和 `ticket.status` 驱动。绝当票写明到期未赎、原物转现货，不将其写成收到赎金。票面 `001` 等编号是本局出票顺序的展示编号，原票据 ID 保留在标题悬停信息中；未新增存档字段。

纸张采用干净内容区、细分隔线与少量印泥红。状态既有文字也有颜色；未依赖花纹、毛笔字或颜色单独表达是否能出售。多票和长流水在右侧抽屉内滚动，原柜台、导航和底栏不移位。

## 接入边界

- `core/inventory/commerce_visual_read_models.gd`：只读整理结构化货签、当票和流水；`CommerceReadModels` 保留原正文与命令列表，附加 `visual` 字段。
- `ui/art/account_paper.gd`：纸票、状态章、金额层级、分隔线及动作的共用构件。
- `ui/inventory/inventory_panel.gd`、`ui/ledger/ledger_panel.gd`：本地筛选、展开与页签；动作仍发给原 Presenter。
- `ui/night/night_resolution_presenter.gd`、`night_resolution_view.gd`：从已结算摘要展示账页；危机待处理、死亡、破铺仍走既有正文与流程。
- `ui/counter/counter_screen.gd`：库存到当票／鬼货页的导航接线。

没有变更买家条件、金额算法、赎回／续当规则、夜末结算或存档版本。禁止把估值当成可用现金，也不把收货和放款直接算为亏损。原始金额与经营结果始终来自已有系统。

## 验证入口

```sh
godot --headless --editor --quit --path .
godot --headless --path . --script res://tests/run_all.gd
godot --path . --script res://tests/art03_ui_smoke.gd
godot --path . --script res://tests/art03_ui_smoke.gd -- wide
godot --path . --script res://tests/art03_debt_ui_smoke.gd
godot --path . --script res://tests/art03_debt_ui_smoke.gd -- wide
godot --path . --script res://tests/art03_extension_ui_smoke.gd
```

库存与票据脚本在既有 M3 三夜流程上增加空态、筛选、物证复看、当票状态、流水范围和日结检查。债务脚本沿用 M6 实际交易、短款、破铺及铜镜流程。续当脚本使用独立测试当约，验证续费、延长期限及后续赎回；测试当约不进入默认游戏。

通用 UI 测试助手现在通过真实点击展开货物详情、切到当票页，再点击出售／赎回操作；未直接发信号跳过界面。测试只使用独立临时存档。

最终截图与日志见 `artifacts/art03/final/`，视觉对照与验收见根目录 `design-qa.md`。上一批 ART02 验收记录保留在 `artifacts/art02/design-qa.md`。

Godot 4.6.1 / macOS 验证结果：库存与票据流程在1280×720、1600×900各163项、0失败；债务与夜间流程各409项、0失败；续当58项、0失败；当前M0–M7核心1798项通过。最终运行日志无脚本错误，`git diff --check`通过。

后续正式制作可替换纸张九宫格、印章字形、授权字体和未覆盖的物品缩略图；本批不把正式资产任务标记完成。
