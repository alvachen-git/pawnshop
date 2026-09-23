# 统一试玩接入安排 · v29

> 入口更新：完整新局现使用 v30 `play-unified.cmd`，见 [整合说明](UNIFIED_V30.md)。下文保留本专项历史规则与验证；其中折扇v29入口已更名为 `play-fan-condition.cmd`。

日期：2026-09-22（2026-09-21开始实施）。已本地验证，尚未推送或合并。

**发布接入补充**：以下保留开发记录。本次已获推送合并授权，合并最新main时将鉴物台场景改为带运行名称的独立入口；`play-fan-condition.cmd`仍启动本批，Godot原默认铜镜入口保留。当前入口与验证以[合并说明](SHOP_APPRAISAL_RELEASE.md)为准。

## 当前接入

2026-09-22升级与知识补充：v29的二级鉴物台与扇画工具取消工具册前置。顾砚生知识改在旧账柜第一柜直接学习，花1次准备，无需先探索；知识独立记录，旧局已研习者直接认作掌握，不重复收费。已有v29存档直接生效，不改版本号和保存入口；v27/v28规则保留。`upgrade`测试升级，`fan`测试鉴物台，新增`knowledge`测试柜中学习，独立保存于`unified-v29-knowledge`。费用与流程见[试玩说明](FAN_CONDITION_PLAYTEST.md#升级与知识2026-09-22补充)。

工作目录 `.artifacts/shop-appraisal`，分支 `codex/shop-appraisal`。在已有v28工作上增量接入品相规则；复查根目录与各隔离工程清单后使用未占用的版本29，没有覆盖其他开发目录。

| 运行 | 启动与保存 |
| --- | --- |
| v29 `fan_condition_ten` | 鉴物台试玩默认，`play-fan-condition.cmd` / `scenes/start_fan_condition_v29.tscn`；自动位 `auto/fan_condition_ten`，`user://fan_condition_ten/autosave_v29.json` |
| v28 `fan_bargaining_ten` | `play-v28.cmd` / `scenes/start_fan_bargaining_v28.tscn`，原名声和判假议价，不补品相 |
| v27 `shop_appraisal_ten` | `play-v27.cmd` / `scenes/start_shop_appraisal_v27.tscn`，保留原规则 |
| v26及更早 | 清单、规则、历史存档入口继续保留 |

根目录启动器继续转入同一隔离工程。v29正常与专项数据各自在 `.godot/play-data/unified-v29-场景名`；v28仍为 `unified-v28-场景名`，v27仍为 `unified-场景名`。三个版本不互相覆盖自动存档。直接用Godot启动场景时，共用项目档案库的不同运行自动位。

新规则仅新开v29启用；不迁移旧局品相、不重算价格或票款。正常经营仍为十夜，设施、陈列、第十七柜、铜镜、命灯和寝屋沿用既有接入。商誉只记录已有隐藏事件，不接入其他任务的关系或客流机制。

完整启动、固定试玩样本见[当前试玩](FAN_CONDITION_PLAYTEST.md)，检查结果、截图与经济对照见[验收](FAN_CONDITION_ACCEPTANCE.md)。下面的“当前”等表述仅指各自历史日期。

---

# v28接入历史（2026-09-18）

日期：2026-09-18。状态：本地实施与验证，尚未发布。

## 当前接入

延续隔离工作目录 `.artifacts/shop-appraisal`（分支 `codex/shop-appraisal`）已有v27成果，新运行 `fan_bargaining_ten` 使用版本28。实施前复查根目录及各隔离工程清单，28未占用。统一启动 `play-fan-condition.cmd`、`scenes/start_fan_condition_v29.tscn` 默认v28；`play-v27.cmd`、`scenes/start_shop_appraisal_v27.tscn` 保留v27。

| 运行 | 状态与保存 |
| --- | --- |
| v28 `fan_bargaining_ten` | 当前默认十夜；折扇判假压价、新鉴定名声、隐藏商誉事件；`auto/fan_bargaining_ten` |
| v27 `shop_appraisal_ten` | 原鉴定名声与议价行为；已有落笔不迁移，历史交易不补商誉 |
| v26/v25及更早 | 保留各自清单、规则、场景与存档读取 |

新版正常/专项启动分别隔离在 `.godot/play-data/unified-v28-场景名`；v27仍使用原 `unified-场景名`。正常十夜、改造、案上对证、三类压价场景均共享同一份源码。没有新增第十一夜。

## 与其他任务的边界

实施检查时其他关系任务目录已有v27清单；以下旧文的“仍在v26开发”等描述仅为当时快照，不能作为最新进度。本批没有编辑 `.artifacts/social-relations*`，没有复制其可见关系条或客流/军方系统。

隐藏事件随本局保存，使用所属运行与稳定交易标识去重。以后统一商誉时再接入这些事件，不在复核时二次扣减；鉴定名声仍独立。接入安排、版本分配和新旧存档边界已在本批落实，尚未对线上main执行合并。

操作与完整启动见[当前试玩](FAN_BARGAINING_PLAYTEST.md)，验证与经济比较见[验收记录](FAN_BARGAINING_ACCEPTANCE.md)。

---

# v27接入历史（2026-09-17）

日期：2026-09-17。状态：本地实施与验证，不代表已发布。

## 共同基线

基于线上 main `026b0579270400ce5a9a48f40c7010ce8b11ff41`，在独立工作目录 `.artifacts/shop-appraisal`、分支 `codex/shop-appraisal` 开发。原主目录、旧试玩副本和其他任务工作保留。

本批统一入口为 `scenes/start_fan_condition_v29.tscn`，新运行 `shop_appraisal_ten`，内容与存档版本 **27**。复制 v26 镜中重逢的十夜数据，在新运行配置中启用 `shop_growth_version=1` 与 `fan_appraisal_version=1`；包含阿七、铜镜夫妻重逢与四种收尾、命灯、寝屋、原有经营、一级设施、陈列买家、第十七柜，以及本批二级鉴物台和扇画自鉴。

正式启动使用 `play-fan-condition.cmd`。专项只是同一份游戏代码的隔离场景，不再维护另一份玩法实现。尚未增加第十一夜。

## 版本与存档边界

| 运行 | 本批处理 |
| --- | --- |
| v27 `shop_appraisal_ten` | 新局统一入口；自动存档 `user://shop_appraisal_ten/autosave_v27.json`，档案库登记独立运行 |
| v26 `mirror_reunion_ten` | 原内容与存档保持；场景 `scenes/start_v26.tscn`，原 v26 启动脚本明确指向该场景 |
| v25 `shop_growth_ten` | 一级设施旧局保持；原成长入口可继续启动 |
| 其他历史运行 | 继续按原清单、运行 ID 与版本读取，不把新知识、设施、名声追算进旧档 |

新功能由运行配置开启，数据只在新局初始化；普通工具减时、开铺准备与报价继续共用原有服务。存档沿用外层动作记录、快照、冷重放校验、缓存与原子回滚，没有额外存档文件拼接。

## 其他任务与接入顺序

“名声和阵营关系”任务仍在 `.artifacts/social-relations` 开发军方、普通商誉与实体往来簿。该任务的当前 v26 是独立运行，不能只看数字误认为已包含 main 的全部 v26 内容。本批不复制它仍在变化的源码，也不修改其名声、客流、采购或停业规则。

关系任务交付稳定版本后：以本统一基线为目标核对差异，再共同整合准备次数、额外来客、停业约束、存档命令白名单与往来簿。若新规则会改变已经交付的 v27 局，分配新的内容版本并保留 v27，不能直接给旧局补算关系。

本批“鉴定名声”只属于扇画专业判断，经行家复核积累；不借用普通商誉或军方关系，不调整散客数量或陈列来客概率。后续如接到往来簿或更广的鉴定体系，保留独立来源与稳定规则。

## 本批范围之外

二级陈列柜、器物验配自鉴、三级设施、旧账柜收费翻新、后续阴账、49夜及债务改革继续留待后续。旧账柜整理与工具册查找都是免费探索，修缮不是查账的收费门槛。

具体玩法与启动见 [扇画自鉴试玩说明](SHOP_APPRAISAL_PLAYTEST.md)，检查记录见 [验收](SHOP_APPRAISAL_ACCEPTANCE.md)。
