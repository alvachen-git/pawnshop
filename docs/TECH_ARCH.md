# 《鬼市当铺》技术架构 · M5

## 当前边界

M4已由负责人确认测试通过，2026-09-04授权进入M5。当前增加一件泣血铜镜、规则处理、夜间异常、永久死亡和绝当录；正式债务与完整P0体验验收仍待完成。

## 依赖方向

```text
JSON -> JsonContentProvider -> SourceSchemaValidator -> DTO
     -> ContentMapper -> DomainValidator -> ContentCatalog
     -> 后续领域系统 -> Feature Presenter -> View/Panel
```

核心业务只依赖类型化领域定义和RunState，不读取JSON、不接收原始内容Dictionary，也不依赖Godot Resource。表现层获取的是复制的ReadModel Dictionary，不是原始JSON或权威状态。

未来如需编辑器友好的复杂规则或视觉资源，新增 `ResourceContentProvider` 与 `ResourceMapper`，将Resource转换为同一DTO/领域定义；交易、事件和经济系统无需改写。

## 内容模型边界

- Source：JSON或未来Resource，属于基础设施层。
- DTO：源数据通过Schema校验后的传输结构。
- Definition：只读业务定义，例如ItemDefinition、CustomerDefinition。
- Runtime State：RunState持有ItemInstance、CustomerVisit及TradeSession，不与只读定义混用。
- ContentCatalog：已完整验证的定义快照和唯一查询入口。

当前支持 `items`、`customers`、`runs`、`buyers`、`pawn_terms`、`events`。Manifest的default_run_id决定启动配置，RunDefinition包含夜数、开铺分钟、夜间时长、时间步长、初始现金、seed与占位行动。RunDTO只存在于映射边界；RunDefinition复制标量并生成DayActionDefinition，不持有源Dictionary/DTO。定义使用只读getter，集合返回副本。GDScript的下划线字段是内部约定，不是语言级私有隔离。

SourceSchemaValidator/RunSchema校验源类型、必填、枚举、版本和范围。DomainValidator验证跨记录引用与运行/行动不变量；InMemoryContentProvider也执行领域校验。当前是代码定义的运行时Schema，不支持任意JSON Schema方言或任意表达式。

## 日循环与持久化

```text
DayFlowPanel -> DayFlowPresenter ---+
                                 +-> RunSession -> DayController -> TimeController
NightResolutionView -> Presenter --+      |              |
                                         |           RunState
                                         +-> SaveManager -> SaveCodec -> JSON
```

- Bootstrap装配Catalog、RunDefinition、RunSession及SaveManager；具体存档路径可注入。
- RunSession是应用服务：命令分派、只读快照、持久化协调与失败回滚，不定义价格、事件或风险规则。
- DayController是日阶段唯一转换入口；TimeController只在正式动作时消耗正整数步长分钟，不使用帧计时。
- `PRE_OPEN -> OPEN -> CLOSED_PROCESSING -> NIGHT_RESOLUTION -> DAY_SUMMARY -> 下一夜PRE_OPEN / RUN_ENDED`。OPEN耗尽时间也直接封铺。关门不可逆；03:00之后没有营业动作。
- RunState.game_minutes是从18:00起的连续偏移0..540，展示时才跨日取模；不使用现实时间。
- 耗时超过剩余时间拒绝且不修改状态，恰好耗尽立即封铺。查看UI及确认框不耗时。
- SaveCodec保存稳定运行ID、版本、seed、夜次、阶段、分钟、现金及日结历史；CounterSaveCodec处理物品知识/变体和来访结果，CommerceSaveCodec处理当票、销售和全量财务对账。不保存DTO、定义、节点或资源路径。读档将JSON浮点数严格校验并归一化为整数。
- 检查点仅允许PRE_OPEN、DAY_SUMMARY、RUN_ENDED；夜间结算只生成一次，继续下一夜再次保存，避免重读旧夜。
- SaveManager同目录临时写入、flush、回读校验后rename替换。写入/替换失败回滚本次状态变化；不先删除旧文件。不承诺硬件掉电事务或多进程并发写入保护。
- 当前save_version=4、content_version=5。版本变化会拒绝旧存档，不进行静默迁移；未来确有兼容用例时再实现迁移器。

## M2柜台领域边界

```text
各功能Panel -> 独立Presenter -> RunSession.counter_command
                                   -> CounterService（单次操作协调）
                                      ├ CustomerManager：来访/等待/离场
                                      ├ AppraisalSystem：证据与估值
                                      ├ TradeController：有限报价与施压
                                      ├ DayController：耗时与封铺
                                      └ EconomyManager + InventoryManager：原子收购
```

- CounterService接收显式visit_id、命令、动作/证据ID及报价数额。旧顾客意图在下一位顾客入场后不会误作用于新顾客。
- RunDefinition.customer_slots定义arrival/customer_id/item_id/variant_id；item_id或variant_id为空时，从内容池按固定seed抽取。每夜预生成一次，不因查询UI/重复鉴定重新抽取。M4用可选night_min/night_max过滤本夜来访，仍由CustomerManager生成经营客流；EventDirector管理独立叙事事件。
- ItemDefinition的变体、线索、动作已映射为ItemVariantDefinition、ClueDefinition、AppraisalActionDefinition。CustomerDefinition持有类型化CustomerTermsDefinition与QuestionDefinition。业务不处理原始内容Dictionary。
- 现有ItemDefinition/CustomerDefinition也改为只读getter；集合取副本。JSON/DTO及运行状态均不共享可变集合。
- CounterSchema校验嵌套字段、枚举、重复ID、范围；CounterDomainValidator校验线索引用、真实价值与证据区间一致性、前置证据可达性、工具及时间步长，内存Provider复用同一领域校验。
- 鉴定结果是动作reveals与真实变体clue_ids的交集，前置证据和工具决定是否可做；没有随机成功率。估值取已揭露证据区间的交集。手工判断仅作为玩家判断记录，不改写真值、证据或自动决定报价。
- 顾客口供属于未证实信息，正式询问只做M2最小问答，事件对白在M4由独立EventDefinition提供，仍不实现通用对白图。
- 开价由名义基础价值及顾客倍率计算；隐藏底价由开价与顾客保留比例生成。真实瑕疵可一次性降低要价/底价，无关证据施压损失耐心；报价和施压各消耗一轮。数值均来自内容定义。
- 顾客期限按到达时刻计算，排队和接待共用该期限；任何耗时行动后统一更新。动作结束恰好到离场时限或03:00，先离场/封铺，不允许迟到成交，但已消耗时间。
- 超过剩余营业时间的动作不能开始。现金不足/非法输入/重复信息不提交动作、不消耗轮次，也不返回底价信息。拒收使用数据配置的送客时间。
- 成交先完成合法性、现金、库存去重与时间检查，再同步提交扣款、实例入库、流水和顾客结果，中间不发信号、不等待异步调用。EconomyManager是现金唯一业务写入口，初始化与恢复例外。
- M3在相同收购链上增加PawnController.issue；贷款沿用相同TradeSession，不能切换模式重置轮次。详见M3经营边界。
- CounterReadModels仅输出已获得证据、估值区间、粗略情绪、报价轮次与可用操作，不输出底价/精确耐心/未揭露变体。read_state是持久化快照，功能展示应使用counter_model，不能直接展示存档中的隐藏字段。
- CustomerVisit/TradeSession仅存在夜内。夜末所有来访都有结果，存档保存visit_history；下一夜开铺前按seed重建其排队计划。读档同时检查现金—流水—库存—来访关系，并按seed核对收购物品变体，拒绝半成交或伪造知识状态。

## M3经营边界

- `BuyerDTO -> BuyerDefinition`、`PawnTermsDTO -> PawnTermsDefinition`经过CommerceSchema及CommerceDomainValidator；RunDefinition引用buyer_ids，CustomerDefinition引用pawn_terms_id。新买家/当约只改JSON，不修改交易逻辑。
- `InventoryPresenter / LedgerPresenter -> RunSession.commerce_command -> CommerceService / PawnController`。柜台活当沿用CounterService；各Presenter分开路由自己的用户意图。
- BuyerDefinition定义品类、渠道、估价倍率、夜区间、到访窗口、耗时、每夜额度。只有有效机会才展示可成交报价；报价确定性基于真实变体和买家倍率，与玩家估值不同。窗口关闭、品类不符、额度用完均不可出售。
- ItemInstance持久保留交易历史身份，以`ownership_state = owned / pledged / sold / redeemed`区分现货、在当、已售、已赎；终态不从历史数组物理删除。可售库存和成本只计owned。无员工或正式存放规则。
- PawnTicket记录稳定ID、本金、当约、起始/到期夜、赎金、状态、续当历史和终结时刻。活当报价按当约loan_ratio换算顾客要价与隐藏保留价，但与收购共用TradeSession轮次/耐心。
- M3返当是有窗口的最小机会，不是EventDirector或完整NPC对白：redeem返店赎回、absent无请求、extend_once测试夹具先续当一次后返店赎回。仅允许响应真实可用请求，不允许玩家凭空收赎金。
- 赎金为本金加向上取整的当约息费；续当只收当约费用、延长到期夜，不重复计入贷款本金。到期未赎在03:00结算前转现货；未到期当票即使运行结束仍保留在当。此处绝当不是玩家死亡。
- 所有现金变化仅由EconomyManager记账；每笔有唯一transaction_id、物品ID、分类、金额、余额和realized_profit。收购/放款利润为0，出售利润为卖价减成本，赎回/续当利润只计息费。
- FinancialSummary分列现金流、现货成本、在当本金和本夜已实现盈亏；估值不作为收入，贷款本金不直接记损失。
- SaveCodec v3：CommerceSaveCodec根据销售/当票重建预期流水，验证唯一性、买家窗口/额度、合同期限/赎金/状态、所有权、余额与逐夜财务指标。业务层不接收持久化原始Dictionary。
- RunSession在夜间绝当前深复制ItemInstance/PawnTicket和数组；存档失败回滚权属及当票，重试不重复收费。简单同步事务不引入通用事务框架。

## UI职责

主场景组合以下独立节点：

- CounterView + CounterPresenter：顾客描述、当前物品和等待/离场摘要。
- ShopStatusView：夜次、阶段、时钟、现金与内容加载状态。
- DayFlowPanel + DayFlowPresenter：营业操作意图、可用动作、加载/新游戏确认和状态读模型。
- AppraisalPanel + AppraisalPresenter：证据、鉴定动作和玩家判断。
- DialoguePanel + DialoguePresenter：询问及未证实口供。
- TradePanel + TradePresenter：可编辑报价、有限轮次和证据施压。
- InventoryPanel + InventoryPresenter：现货/在当/已售/已赎、成本与有效买家出货意图。
- LedgerPanel + LedgerPresenter：分类现金流水、已实现盈亏、当票及返当请求意图。
- NightResolutionView + NightResolutionPresenter：鬼货结算、日结与本轮结束展示；旧夹具保持占位结果。
- RiskPanel + RiskPresenter：鬼货处理、危机应对与绝当录。
- ScreenFlowCoordinator：只管理Panel显隐，不包含业务规则。

已接入功能均通过独立Presenter调用应用服务。View不直接修改RunState，也不读取其他Panel内部节点。CounterScreen仅装配Presenter、Panel和信号；ScreenFlowCoordinator仅决定显隐。IntentPanel只复用滚动文本/按钮控件，CounterFeaturePresenter只复用意图传递与刷新绑定，没有价格、时间、耐心或风险规则。

## 可运行性门禁

每个Milestone必须同时满足：

1. 项目可由主场景启动。
2. headless测试通过。
3. 实际启动后当前阶段的完整试玩路径可用。
4. 未完成模块不会破坏已完成路径。
5. 汇报并验收后才进入下一Milestone。

M4、M5均已通过负责人试玩；当前按反馈修订玩家文案，P0剩余项待验收，不自动进入P1。

## M4事件与内容边界

```text
JSON -> EventSchema -> EventDTO -> EventDefinition / EventChoiceDefinition
     -> EventDomainValidator -> ContentCatalog

EventPanel -> EventPresenter -> RunSession.event_command -> EventDirector
                                                        -> RunState flags/history/pending
RunSession命令边界 -> EventDirector.poll -> 待处理事件
BuyerDefinition.required_flags -> CommerceService -> 既有出售链
SaveCodec v4 -> Counter/CommerceSaveCodec -> EventSaveCodec
```

- `RunDefinition.event_ids/flag_ids`明确本轮事件和标记集合，具体角色名、事件ID、夜数没有进入事件/交易核心分支。
- `VisitSlotDefinition.night_min/night_max`只影响本夜编排；缺省保留旧行为。存档核对同一seed及同一夜的实际来访集合，拒绝跨夜伪造来访。
- EventDirector只读取类型化定义；按anchor、conditional、random排序，同类型按priority。随机候选同优先级按weight抽取，种子由运行seed、夜次与已完成历史生成。
- 锚点保底采用M4最小可验证实现：限无条件开铺前，不被一般事件额度、互斥或等待动作跳过。条件剧情使用conditional；非锚点每夜最多一个，未轮到的条件事件只要仍在有效窗口就可在后夜重试。
- 当前没有任意表达式执行器。事件效果只有单向grant_flags；required_flags可触发后续事件或解锁买家，required_items读取现货/在当持仓。涉及现金的机会依然走真实买家窗口、额度、出售与记账。
- 待办只在初始化/新夜/命令完成后产生，状态保存pending_event_id和触发分钟；纯ReadModel查询无副作用。待办期间拒绝所有经营命令，防止从其他面板绕过选择。
- 事件选择在窗口内提交一次。开铺前确认免费，营业/关门阶段选择消耗正整数步长；顾客等待同时推进。过期或重复的事件/选项ID无效。
- EventSaveCodec从选择历史重建flags，以历史时刻的持仓重放事件选择，验证条件、优先级、seed抽取、冷却、次数、顺序、锚点完整性及买家介绍先于出售。待办与下一夜检查点一致；写档失败回滚包含这些新字段。
- EventPresenter仅绑定意图、读模型和切页；EventPanel显示当前事件/选择，再显示历史。没有内容ID、价格或调度规则放入UI。
- 现有M0–M3测试使用独立M3 Manifest，M4测试使用tests/fixtures/m4_manifest.json；M5默认游戏和新增测试使用生产Manifest。仅将旧测试改为显式夹具入口，不降低其原有断言。

## 本阶段主要风险与约束

1. 锚点被快速等待/早关跳过：M4只允许开铺前保底锚点，Schema/领域校验拒绝不支持的锚点形状。
2. 随机刷新刷出有利事件：待办持久保存，查询不抽样，相同seed和历史可重放。
3. 配置前置失效或循环：声明标记集合、跨引用校验、前置可达性检查；不靠运行中静默忽略。
4. 解锁或跨夜保存不一致：从历史选择重建flags，交易与事件分别审计，写档失败整体回滚。
5. 后续内容污染旧验收：旧Manifest作为固定夹具，新生产内容单独验收。
6. 范围失控：M4只做小型事件与内容配置，不引入动态NPC框架、49夜剧情、债务融资或鬼货风险。

本机验证环境为Godot4.6.1/macOS；原技术基线4.7.2尚待对应环境复核。新内容仍是内部测试文字与占位美术，不能作为完整P0时长或美术完成度证明。


## M5风险与死亡

风险模块详见`docs/M5_GHOST_GUIDE.md`。GhostRuleDefinition经独立Schema/DTO/领域校验加载，物品通过ghost_rule_id引用，运行通过ghost_rule_ids启用；RiskManager不认识JSON来源。当前只支持cover_before_close机制及每轮一件鬼货。

RunSession在所有耗时意图后捕获关门（含自动封铺）；结算后生成风险日结或可挽救待办。风险待办与dead状态阻止普通推进；对应选择通过独立risk_command提交。读取面板不触发状态变化，第一次未知规则只进入警告。

存档当前为v5/content v6，在原财务/事件重建后用RiskSaveCodec重建处理结果。run_token区分每次新游戏；risk_history保存处理过程，risk_pending保存未解决应对。death_archive与当前状态在同一文件原子提交，重开合并旧档历史。死亡不得重新解释为存活；写盘失败回滚处理历史、财务摘要、终止阶段和绝当录。

财神香与命灯呈现物品违规、铺中入侵和个人缠祟的文字后果，不是公开数值条。持续缠祟目前保留为跨夜叙事状态。没有实现完整索命夜、阴账清偿、49夜、复杂鬼货组合或正式美术。
