# 普通交易 v10 交付记录

实现范围：8件普通物品的三品相内容、4类新当户、随机普通来访、来源核验与溢价。沿用三夜、每日4个时段、原主回访与夜末核票、房间和危机。2026-09-06负责人确认保留新版开局现银300、借据本金500，每日息钱5、铺费5；v9旧局维持原经济配置。

## 内容配置

生产入口为 `data/content_manifest.json`，新运行 `data/runs/p0_variety.json`。旧运行、旧物品与旧人物文件不修改，通过 `data/legacy/content_v9.json` 读取。

| 普通物品 | 原有品相与隐藏价值 | 第三品相与隐藏价值 | 两项针对性检查 |
| --- | --- | --- | --- |
| 青花小碗 | 完好60、修补20 | 口沿小磕38 | 底足、侧光釉面 |
| 黄铜烛台 | 黄铜40、镀铜铁胎10 | 黄铜接合松动24 | 磁针、底部旧划痕 |
| 银簪 | 完好45、镀银12 | 焊修28 | 刻记磨损、簪脚接缝 |
| 怀表 | 完好80、机芯故障22 | 壳面磨损但走时正常48 | 机芯计时、表壳铰链 |
| 端式砚台 | 完好50、着色仿品15 | 天然石料边角磕损30 | 石纹、砚边断面 |
| 紫砂小壶 | 完好55、裂损胶修18 | 后配壶盖32 | 内壁、盖沿合口 |
| 花鸟绣片 | 完整65、受潮脆断20 | 褪色但经纬完整40 | 透光经纬、折边色差 |
| 赛璐珞钢笔 | 完好35、裂尖堵墨12 | 后换笔尖22 | 笔尖导墨、厂记比对 |

物品配置在 `data/items/items_v10.json`。观察给出宽区间；两个专属检查各有物证，任意合法顺序不会排除真实价值。原有品相ID、价值与证据折价额保留，第三品相按价值差设折价。问答在运行的 `trade_scenarios` 中，按物品绑定；来历、品相声明与证据追问分开，承认/解释/回避独立抽取。`benefit_groups` 阻断同一瑕疵在检查、追问与施压之间重复折价。

| 新人物 | 耐心 / 轮数 / 等候分钟 | 要价倍率 / 底价比例 | 携物池 |
| --- | --- | --- | --- |
| 绣坊女工 | 3 / 3 / 100 | 1.10 / 0.75 | 银簪、绣片、小壶 |
| 钟表修理匠 | 1 / 3 / 80 | 1.25 / 0.80 | 怀表、钢笔、烛台 |
| 茶馆掌柜 | 4 / 4 / 120 | 1.20 / 0.75 | 小壶、小碗、烛台、砚台 |
| 失业账房 | 3 / 3 / 60 | 1.15 / 0.70 | 钢笔、怀表、砚台 |

`data/customers/customers_v10.json` 配置人物参数、姓名池和回应覆盖。四类均支持卖断/活当；初始耐心、错误施压和报价规则在界面说明。急用钱处境影响让价，不改写职业等候时长。四幅新立绘位于 `assets/art02/customers/`，沿用360×430比例与原渲染层级，用服装、围裙、毛巾、眼镜等区分职业。

## 随机与身份

`VarietyService` 按局种子与稳定来访ID生成独立序列：人物、适配物品、三种品相、来源、姓名、处境、反应、当约。普通模板等权，品相等权；允许重复模板/物品，整局姓名去重。`ordinary_selections` 保存选取记录，人物实例含ID、姓名和外观引用，票据与原主回访复制同一身份。

普通时段保持0、90、210、360分钟。真实原主回访先办，普通排程整体顺延其所需分钟数。第三夜铜镜维持固定入场；最后一位的故障怀表和铜镜线索固定，卖家从适配职业池随机。

新局当约在独立序列中预选、出票时绑定：返当/不回访等权，与职业无关，读档不重抽；界面只给本金、期限、赎金和耗时，不显示回访结果。原测试用 `extend_once` 路径保留。

## 来源、现金与接口

每件物品的 `provenance` 包含虚构店号凭据、物上核对点、三种结论文案、权重及成本。默认权重为无可核验来源2、可证实1、矛盾1。隐藏真相固定；已知状态为 `unchecked`、`verified`、`unconfirmed`、`mismatch`，口供本身不改变状态。

- 柜台：`RunSession.counter_command("verify_source", visit_id)`；必须先问来源、仍接待对应人物，5分钟免费，重复调用不耗时。
- 库存：`RunSession.commerce_command("inquire", item_id)`；营业中的自有现货，确认2银元/10分钟及可能查无实据。每件最多一次；已证实/矛盾不提供付费入口。现金不足、时间不足、在当、售出、回访或危机未决时拒绝。
- 来源费：流水类型 `provenance_inquiry`，交易ID `inquiry/<item_id>`。调查费列 `provenance_expense`，不改变入手成本；经营净收益=交易已实现毛利−调查费−本夜息费。原夜内保存边界不变。
- 买家：`CommerceService.quote` 与存档重放共用 `ProvenanceService.premium`。收藏客认瓷器，商会旧货客认其收购品类并新增金属；其余不加价。已证实来源加 `floor(base * premium_bps / 10000)`，默认1500。库存报价和凭据分列基础价与溢价。
- 来源不改变活当本金、赎金或八折转当金额；绝当留货后下一夜可调查/出售；鬼货出售不抹去已发生的个人纠缠。

## 保存与兼容

新保存版本10，文件 `user://p0/autosave_v10.json`。无新文件时优先读v9，缺v9时读v8；旧局使用v9目录继续，后续写到新文件并保留旧文件。新游戏切回v10。v7历史档/旧财务校验保持原路径，旧局不重算来源或经营结果。

`VarietySaveCodec` 对照种子校验人物、物品、姓名、来源和当约，规范JSON数值类型，再对照实际柜台行动和所有权重放来源调查；与出售、回访、剧情、窥镜及存放时间交叉校验。`CommerceSaveCodec` 重建调查费和来源出售报价，逐条对账。夜末合账沿用临时文件校验、原子替换与状态回滚。

## 验证与截图

统一命令：

```powershell
./tools/test_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe -OutputDir ./.artifacts/variety-final
```

本次不制作试玩包、不推送、不合并。测试使用隔离APPDATA。最终结果文件和截图位于 `.artifacts/variety-final/`。

2026-09-06最终统一验证：**61组全部通过，0失败**。Godot 4.6.1 Standard / Compatibility，实际窗口由 NVIDIA RTX 3060 Laptop GPU 渲染；日志未发现脚本错误。结果清单为 [results.json](../.artifacts/variety-final/results.json)，新版截图共28张。

可直接打开：[耐心1与人物](../.artifacts/variety-final/screenshots/variety_1280_01_watchmaker_rules.png)、[调查前确认](../.artifacts/variety-final/screenshots/variety_1280_06_inquiry_confirmation.png)、[来源溢价凭据](../.artifacts/variety-final/screenshots/variety_1600_05_premium_receipt.png)、[连续来客下的凭据](../.artifacts/variety-final/screenshots/variety_1280_09_next_customer_receipt.png)。

新增领域套件 `tests/run_variety.gd`：17,079项断言。覆盖24品相、三种来源、两个检查顺序、三种口供、重复优惠、512个种子、姓名与携物一致、耐心1、来源舍入/费用/库存、损坏记录、v9导入、同模板多人回访、续当及铜镜路线。跨进程 `variety_checkpoint_process.gd` 的 write/settle/read 覆盖来源调查、身份、真实赎回、转当、重复操作与真实写盘失败回滚。新版真实窗口 `variety_ui_smoke.gd` 在1280×720与1600×900各105项断言。

固定种子三夜批次：每局5–10笔普通成交，终局现金213–278银元；每天交易相关动作105–160分钟，另外保留等待、剧情和收铺时间。测试策略只看已知估值下沿，凭已见瑕疵议价，一次报价后选择可用买家；不读取隐藏底价作为策略输入。它验证可执行路径，不代表玩家收益保证或最终平衡结论。

代表截图（统一验证完成后在输出目录的 `screenshots/`）：

- `variety_1280_portrait_seamstress.png`、`portrait_watchmaker.png`、`portrait_teahouse.png`、`portrait_bookkeeper.png`：四类轮廓。
- `variety_1280_01_watchmaker_rules.png`：耐心1和失败规则。
- `variety_1280_02_testimony.png`、`03_verified.png`：口供与来源证据分开。
- `variety_1280_04_premium_quote.png`、`05_premium_receipt.png`：来源报价与成交凭据。
- `variety_1280_06_inquiry_confirmation.png`、`07_inquiry_receipt.png`：调查确认、费用和结果。
- `variety_1280_09_next_customer_receipt.png`：连续来客时的凭据遮挡与点击隔离。
- 同名 `variety_1600_` 截图覆盖1600×900窗口。

四类立绘仍为SVG低保真；其他既有物品图与房间资源沿用。未扩展维修、成套出售、同行议价、声望或七夜内容。

## 合入 main 前联合验证 · 2026-09-06

在 main 的 `5d22fee` 基线上整合本次普通交易内容，保留已发布的标题菜单、原四类当户的一次性试探和物证议价反馈。旧议价回归使用独立 v9 内容；新随机交易继续使用 v10。原四类当户的既有议价配置带入 v10，不给新四类额外增加试探机制。

- 完整 Windows 源码验证70组全部通过，0失败；包括旧议价、活当、房间、来源、财务、旧档与跨进程恢复。
- 新增联合测试 `tests/bargaining_variety_tests.gd`：69项断言、0失败，覆盖原四类随机当户的来源核验、试探、重复阻断、成交、身份、日结恢复及篡改拒读。已加入统一测试入口。
- 1280×720及1600×900真实窗口通过；已目视检查修理匠耐心说明、来源溢价凭据与连续来客弹窗。
- 统一日志与截图在原工作区 `.artifacts/v10-merge-validation-01/`；补充联合测试日志在独立合并目录 `.artifacts/integration-check/result.log`。
- 保留现银300、债务本金500；没有制作试玩包。用户本地试玩通过后明确授权推送并在线合并。
