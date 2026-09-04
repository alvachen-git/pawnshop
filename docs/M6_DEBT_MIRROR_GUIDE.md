# 每日息费与铜镜窥探

## 配置与结算

生产入口为 `data/runs/p0_debt_mirror.json`，内容版本7。RunDTO→只读RunDefinition新增可选 `fee_policy` 与 `mirror_encounters`；未配置的历史夹具不产生费用或遭遇。源Schema和领域层均校验取值、引用、固定物品变体与时间步长。

`fee_policy`：principal=300、interest_bps=100（1%）、overhead=5、grace_nights=1。每日利息按本金向上取整，不滚入本金。当前规则只允许一夜宽限，不支持还本或融资。

RunSession在夜末先处理当票到期，再由FeeService结息费，最后生成财务摘要。FeeService按夜次去重，追加当夜应计费用、按起欠夜次从旧到新付款，以单笔 `daily_fees` 流水通过EconomyManager扣钱。现金不透支，零付款也有结算记录。fee_history记录每夜利息、开支、实付、结余短款和逾期额；fee_arrears记录起欠夜、到期夜、余款。

FinancialSummary保留原realized_profit作为交易毛利，新增interest_expense、shop_expense、fees_paid、operating_profit。净收益=交易毛利−当夜利息−当夜开支；实际付款包含清旧欠，不作为第二次费用。库存和在当本金不能直接清偿现金欠款。

费用结算后先处理RiskManager。若有未决危机，保留day_summary，不开放交易；应对生还后FeeService.finish进入bankrupt，死亡则保留dead且不追加破铺记录。没有危机时到期欠款直接进入bankrupt。《破铺录》记录本金、总欠款、到期欠款、现金和资产成本；同run_token只能出现一个终局。

## 铜镜遭遇

MirrorEncounterDefinition绑定 `n3_visit4`，子时后、对应客人正在柜前、铜镜仍由店铺持有才提供机会。不使用普通EventDirector额度，不新增通用脚本效果解释器。

揭布使用原有动作；peek和pursue各5分钟，decline和stop免费。窥看完成时来客已超时则只记录耗时，效果作废。初窥后必须选择收回视线或继续追看，不能用交易/关门绕过该选择。再次查看面板不重抽、不耗时。

peek从镜中倒影指向怀表损伤，揭示已定义的flaw证据；估值区间20–26、一次议价施压均沿用既有逻辑，不显示真实价值22或隐藏底价。mirror_history独立记录遭遇ID、来访ID、铜镜实例、夜次、时刻、动作以及窥看前已完成的普通鉴定动作。不会把窥镜写入completed_action_ids。

pursue揭示旧掌柜当票线索并留下当夜纠缠。RiskManager将其与未覆镜风险合并为一个mirror_pending；出售铜镜不清除此来源。追看危机使用身后影子的文案，因此出售后也不会声称玩家仍持有镜子。生还保留既有跨夜缠祟表现，未扩展新的长期索命系统。

## 保存、校验与兼容

Save v6使用独立 `autosave_v6.json`。Bootstrap仅在默认生产存档路径时读取旧 `autosave.json` 的有效death_archive；自定义测试路径不会读取用户历史。旧进度不迁移，旧文件不写入。两本历史账册随当前状态同文件原子提交；读档和存档失败均不丢弃历史。

校验顺序：基础状态→柜台与交易→费用重建→事件→铜镜遭遇→鬼货结果→经营终局。FeeSaveCodec从已验证的外部交易推算各夜夜末可用现金，独立重算费用、先后付款、期限与短款；所有流水逐笔对账。夜末息费允许发生在关门后，外部交易仍受原关门时间限制。

CounterSaveCodec按普通动作顺序与窥镜插入位置重建证据。MirrorSaveCodec验证对应夜次/来访、持镜期间、红布状态、动作耗时、不重叠、离店时间与一次选择顺序，防止删除来源仍保留证据。RiskSaveCodec再验证追看导致的个人纠缠和最终应对；FeeSaveCodec最后核对bankrupt与《破铺录》。开铺前即使进入到期夜，也不视为已经过了夜末期限。

不支持夜内存档、多窗口并发写入、外部改档防作弊或旧进度自动迁移。

## 回归入口

`tests/m6_tests.gd` 随run_all执行；包含空店扣费、宽限边界、真实买卖脱困、库存不自动处置、第三夜欠款、证据来源、超时、卖镜纠缠、两终局同夜、写入失败回滚及旧档逐字节保留。

`tests/m6_ui_smoke.gd` 在两种分辨率通过实际输入验收；`tests/m6_checkpoint_process.gd` 用六个独立进程串联欠款与鬼货终局。完整命令与手动验收步骤见README。
