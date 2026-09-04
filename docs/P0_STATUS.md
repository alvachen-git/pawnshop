# 《鬼市当铺》P0 状态

更新日期：2026-09-04

## 当前Milestone

**M3 · 已完成实现，验证结果见下方；等待项目负责人试玩验收，未开始M4**

M0–M2均获明确确认；本次授权为“测试ok，继续M3”。下方M0/M1/M2条目为历史交付记录，不代表当前限制。

## M3交付

- [x] 现货/在当/已售/已赎权属，成本占款与历史实例分离
- [x] 两个数据驱动买家：偏好品类/渠道、窗口、报价倍率、每夜额度；无固定市场价兑换
- [x] 出售原子提交现金/物品/销售记录/流水，重复意图无效
- [x] 活当放款与收购共用有限轮次/耐心，生成当票，在当物品禁售
- [x] 当户窗口内返店赎回、利息利润、逾期绝当转现货、下一夜可出售
- [x] 一次续当请求接口及独立内容测试夹具；未加入正式续当剧情
- [x] 分类现金流水、销售成本、已实现盈亏、现货成本、在当本金与日结对账
- [x] M3存档版本、当票/销售/流水/权属/逐夜财务校验，损坏存档拒绝
- [x] 写档失败深度回滚绝当和库存状态，重复重试不产生额外结果
- [x] Inventory/Ledger/Trade/Night独立View/Presenter，业务不依赖JSON或UI节点
- [x] 未到期当票在第3夜运行结束时保留，不强制提前绝当
- [x] 无M4事件导演、全量内容或M5鬼货开发

## M3验证记录

- Godot 4.7.2编辑器导入及固定柜台启动通过，无脚本解析/缺失资源错误。
- **236项核心断言通过**：包括M0–M2全部回归，以及买家价差、现金不足、成本占款、真实亏损、额度/期限、赎回/续当/绝当、三夜存档与失败回滚。
- **M3 headless UI：100项检查通过；真实OpenGL UI：107项检查通过**。视口鼠标输入走通出售、两张当票、次夜赎回、读档恢复、夜末绝当、第三夜出售及结束。
- **M2真实UI回归88项、M1真实UI回归73项均通过**。
- 三个独立进程依次放款存档、读档赎回再存档、读档核对，全部通过。
- 已查看实际1280×720渲染截图：买家机会、在当库存、当票流水、日结；长面板可滚动，底部日结按钮可操作。截图在忽略目录`.godot/qa/m3_*.png`。
- 自动测试只清理自身user://tests/临时文件；未删除或改写玩家旧存档。无提交/推送/PR。
- 环境仅有既知Windows根证书读取报错，不影响纯本地内容、存档或渲染。

## M3主要文件与试玩门禁

- `core/inventory/commerce_service.gd`、`commerce_read_models.gd`：买家机会、出售和经营只读模型。
- `core/pawn/pawn_controller.gd`、`pawn_ticket.gd`：放款、当户请求、赎回/续当与绝当。
- `core/economy/financial_summary.gd`、`economy_manager.gd`：统一记账及财务摘要。
- `core/save/commerce_save_codec.gd`：M3跨实体存档对账。
- `core/content/commerce_schema.gd`、`commerce_domain_validator.gd`及Buyer/PawnTerms DTO/Definition：数据源解耦与两级验证。
- `data/buyers/buyers_m3.json`、`data/pawn_terms/terms_m3.json`：当前新增权威内容，Manifest content_version=4。
- `tests/m3_tests.gd`、`m3_ui_smoke.gd`、`m3_checkpoint_process.gd`：核心、真实UI与跨进程验证。
- **先关闭旧试玩窗口，再启动M3并新游戏**。save_version=3，不迁移旧M2档；读取旧档失败会保留文件，新运行首次夜末会覆盖旧检查点。仍只支持单窗口、夜末存档。
- README已给出收购18→卖12/24、活当27→赎33、第二客活当20→未赎绝当→第三夜出售三条测试路径。
- 当前仍使用2物品、2顾客及重复三夜客流，不代表完整P0内容或时长达标。
- **M3交付后停止，等待负责人亲自测试与明确确认；未开始M4。**

## M2历史交付

- [x] 每夜预生成顾客来访槽，支持等待、超时、耐心/轮次耗尽及关门离场
- [x] 可观察物品基本信息，识货/辨真前置动作、工具、证据及估值收窄
- [x] 卖家问答、未证实口供和独立玩家判断
- [x] 隐藏底价/精确耐心、有限正式报价和一次性证据施压
- [x] 拒客消耗时间；非法/现金不足/重复信息不会提交试探动作
- [x] 收购扣款、实例入库、收购流水和来访结果同步提交，旧visit_id不能重复成交
- [x] 库存/账本只读展示已知估值和成本，未接入出售、典当
- [x] 错误判断能以60收购真实价值20的修补器，现金支出及估值缺口真实存在
- [x] 两件普通物品、两类顾客，嵌套内容源校验、领域引用/证据可达性校验
- [x] 物品/顾客及其嵌套定义只读，JSON和独立内存Provider业务结果等价
- [x] 各功能独立Presenter/View，无万能UIController，UI不包含价格/耗时/耐心规则
- [x] 夜末保存库存/流水/来访历史，恢复时跨实体对账及seed变体核对
- [x] M1日循环和三夜启动试玩路径回归通过

## M2验证记录

- 内容/领域/存档测试：**150项断言全部通过**，包括M0、M1回归和新增ID内容测试。
- M2无界面UI回归：**80项检查全部通过**。
- M2实际OpenGL窗口回归：**88项检查全部通过**，用视口鼠标及报价控件走通鉴定、施压、成交、拒客、错误收货、读档和三夜结束。
- M1实际窗口UI回归：**73项检查全部通过**。
- 独立进程写档/读档恢复M2交易库存、现金及流水通过。
- 查看1280×720实际渲染截图：来客、口供、证据、议价、库存、流水及日结；长面板使用滚动容器，底部结算按钮保持可用。
- 固定柜台主场景可直接启动，无脚本解析或缺失资源错误。
- 测试只使用user://tests/下独立测试存档，不改写玩家存档。没有提交、推送或创建PR。

## M2历史边界与人工验收

- 当前三夜复用4个来访槽/夜的测试编排，不代表完整三夜差异内容或30–50分钟经营P0完成。
- 出售、买家、当票、正式债务、EventDirector、鬼货风险仍未实现；已实现盈亏留到M3。
- 长鉴定内容可滚动；精确底价/耐心和未揭露真值不显示。玩家手工判断不是自动鉴定。
- `save_version=2` / `content_version=3`拒绝旧M1存档且保留原文件。请新游戏试玩；新运行夜末保存将覆盖旧自动存档。
- 默认启动不自动读档，不支持夜内即时保存；仅允许单个试玩窗口写档。
- 试玩推荐：开铺 → 问修补史 → 器型/底足/侧光检查 → 用补釉证据施压 → 报价18 → 库存/账本 → 关门日结 → 下一夜读档。详细步骤见README。
- 沙箱Windows根证书读取报错不影响本地内容、存档或OpenGL渲染。

## M2主要文件

- `core/customer/`、`core/appraisal/`、`core/trade/`：来访、证据、议价及柜台应用服务。
- `core/economy/`、`core/inventory/`、`core/state/item_instance.gd`：最小原子收购链。
- `core/content/counter_schema.gd`、`counter_domain_validator.gd`及类型化定义：运行时内容校验。
- `core/save/counter_save_codec.gd`：M2存档对账和引用校验。
- `data/items/items_m2.json`、`data/customers/customers_m2.json`、`data/runs/p0_daily_loop.json`：当前生效内容，由manifest明确引用；旧M0样例不参与运行。
- `ui/appraisal/`、`ui/dialogue/`、`ui/trade/`、`ui/inventory/`、`ui/ledger/`：各功能独立View/Presenter。
- `tests/m2_tests.gd`、`tests/m2_ui_smoke.gd`、`tests/m2_checkpoint_process.gd`：M2自动验收。

## M0目标

- [x] Godot 4.7.2 GDScript项目配置
- [x] 可直接启动的固定柜台2D占位场景
- [x] 柜台、状态、鉴定、对话、交易、库存、账本、夜间结算UI拆分
- [x] ScreenFlowCoordinator仅管理Panel显隐
- [x] ContentProvider抽象
- [x] JsonContentProvider正式实现
- [x] InMemoryContentProvider测试实现
- [x] Source Schema校验、DTO映射、领域校验和ContentCatalog
- [x] 最小ItemDefinition和CustomerDefinition
- [x] 最小RunState，阶段固定为PRE_OPEN
- [x] 自动测试和实际启动验证
- [x] 架构与决策文档

## 当前明确未实现

- [ ] 鬼货存放规则、正式债务、完整8物品/4顾客内容
- [ ] EventDirector
- [ ] 泣血铜镜与夜间异常
- [ ] 夜内即时存档、跨版本存档迁移（不属本次M3）

## 门禁

M3完成后停止，等待项目负责人验收；不自动进入M4。

## M1交付

- [x] RunDefinition JSON配置三夜、18:00起始、540分钟、5分钟步长和占位动作
- [x] RunDTO → 只读RunDefinition/DayActionDefinition，与数据源解耦
- [x] PRE_OPEN、OPEN、CLOSED_PROCESSING、NIGHT_RESOLUTION、DAY_SUMMARY、RUN_ENDED
- [x] 查看和现实等待免费；耗时动作才推进分钟
- [x] 自由关门、不可重开、关门后处理、跨午夜和03:00封铺
- [x] 超时动作拒绝；恰好耗尽立即封铺
- [x] 夜间结算占位、日结和连续三夜结束
- [x] 夜末自动存档、下一夜检查点、读档恢复、新游戏确认
- [x] 存档版本/状态校验、写入失败回滚、重试与旧存档保留
- [x] DayFlowPanel/Presenter、NightResolutionView/Presenter和实时ShopStatusView
- [x] 技术文档、决策与试玩步骤更新

## M1验证记录

- Godot 4.7.2 Standard编辑器导入、主场景启动通过，无脚本解析或缺失资源错误。
- 内容/领域/持久化测试：**82项断言全部通过**，包含M0回归。
- UI无界面输入回归：**67项检查全部通过**。
- 实际OpenGL渲染窗口UI回归：**73项检查全部通过**，视口鼠标输入走完三夜，含读档确认、恢复和取消新游戏。
- 独立Godot进程分别写档/读档：全部通过。
- 人工查看渲染截图：开铺前、19:00关门后、封铺、日结、三夜结束和中文确认框；1280×720布局无裁切遮挡。
- 测试文件使用user://tests/隔离；只清理本次生成的临时测试存档，不改玩家存档。
- 回归过程中修复JSON数字恢复为浮点导致的状态类型不一致，以及UI测试内嵌弹窗坐标换算；最终回归无失败。

## M1历史限制

- M1占位动作不生成现金收支、物品或风险；平安夜仅是结算流程占位。尚未达到完整P0的30–50分钟经营体验。
- 夜内不保存；新运行首次日结会覆盖同一自动存档。默认启动不自动读档，可在营业页主动读取。
- 当前仅单实例存档，不支持多窗口同时写档、硬件掉电事务或旧版本自动迁移。
- 沙箱环境的Windows根证书存储读取报错不影响本地内容、存档或渲染；未引入网络依赖。

## M1主要文件

- `core/day/`：ActionResult、TimeController、DayController、RunSession。
- `core/save/`：SaveCodec、SaveManager。
- `data/runs/p0_daily_loop.json`、`core/content/`：运行内容、源校验、DTO与定义映射。
- `ui/day/`、`ui/night/`、`ui/status/`：独立功能展示与Presenter。
- `scenes/main.tscn`：固定柜台组合场景。
- `tests/run_all.gd`、`tests/m1_tests.gd`、`tests/ui_smoke.gd`、`tests/checkpoint_process.gd`：自动验收。
- `README.md`：启动、存档与建议人工试玩路径。

## M0验证记录

- Godot版本：4.7.2.stable.official。
- 内容与架构测试：16项断言全部通过。
- 主场景冒烟：无界面启动成功，退出码0。
- 已验证：JSON/内存Provider等价契约、源Schema错误、重复ID、跨内容失效引用、主场景加载和Panel独立切换。
- 沙箱环境无法读取Windows根证书存储，但不影响本地内容加载、测试或场景启动。
