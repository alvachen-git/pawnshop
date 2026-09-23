# 高档货分级鉴定 · v32 本地试玩

新游戏使用 `precision_ten` 十夜局，接入基础外观、二级器材鉴定、三级深查。统一入口、五类富客、商誉客流、宣传、赎当、阿七和铜镜剧情继续保留。旧档按原内容版本读取，v31 不补抽破损、不追收器材费用、不改变当票。

## 直接启动

在任何 PowerShell 目录都可复制下面的完整路径。测试预置使用独立数据目录，窗口及画面上标明「鉴定测试预置」，不保存进度，不覆盖正式存档。

```powershell
# 无设备：先体验柜台检查外观
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-unified.cmd" -Stage wealthy-basic -Item gold_watch

# 二级：普通难度，证据足够；真货也可搭配破损
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-unified.cmd" -Stage wealthy -Item album -Condition sound -Damage minor -Difficulty ordinary -Wide

# 三级：先用二级检查，再追加深查隐蔽修配
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-unified.cmd" -Stage wealthy-deep -Item porcelain_vase -Wide

# 正式经营：从标题页新游戏开始
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-unified.cmd" -Wide
```

`wealthy` 是二级测试预置，`wealthy-deep` 配齐三级器材和知识。预置默认修配、轻损、隐蔽，现金 2,000；这是明确的测试条件，正式新局仍为 300 银元。历史 `wealthy-appraised` 与 `advertisement` 预览继续用于 v31 回归。

| 参数 | 可选值 |
| --- | --- |
| `-Condition` | `sound` 完整真品、`mended` 修配／旧临本／低成色、`flawed` 仿制冒名 |
| `-Damage` | `intact` 完好、`minor` 轻损、`major` 重损 |
| `-Difficulty` | `ordinary` 二级证据足够、`hidden` 二级暂难排除其他可能 |
| `-Wide` | 1600×900；不填则 1280×720 |

| `-Item` | 货物 | `-Item` | 货物 |
| --- | --- | --- | --- |
| `embroidery` | 精品绣屏 | `gold_bangle` | 赤金手镯 |
| `gold_watch` | 金壳怀表 | `mantel_clock` | 进口座钟 |
| `pearl_necklace` | 珍珠项链 | `jade_pendant` | 金镶玉坠 |
| `album` | 名家册页 | `porcelain_vase` | 古瓷小瓶 |
| `repeater` | 报时金怀表 | `silver_set` | 西洋银器套件 |

## 如何鉴定

点击柜台上的物品，进入「鉴定」。检查外观 5 分钟；器材鉴定 10 分钟；直接深入查验 20 分钟，已做二级时追加 10 分钟。开始时扣时间，复看、圈选、比对、草稿和落笔不再扣时。期限不足不会开始。

在两处细节之间切换，分别点击实物、图录中的对应位置，再选择「相符／存在差异／暂难判断」。点击「放大对照」或右键、向上滚轮可放大。分别选身份和修配判断后落笔；不自动公布答案。圈点即保存；修改圈点须重新记下比较。同一级落笔后不能改写；二级记录可复看，三级另存一份。

回柜台打开议价，用「拿新证据谈价」提交尚未用过的外观和鉴定证据，每次 5 分钟、1 轮。不重复折价。真实货值及出售按基础货况值 × 外观比例计算；商誉判价只使用谈价时已经证实的事实。厂主和大买办的筹款底线不会被鉴定降低。

## 建设与器材

第二夜起在开铺前的铺内鉴物台办理，每次购买用 1 次准备。一级 40 银元、当夜可用；二级 80 银元、两夜工期；二级完工后才能建三级，160 银元、两夜工期，施工期间旧台可用。

| 器材 | 价格 | 配合台体 |
| --- | ---: | --- |
| 展验工具（与已有扇画工具共用） | 30 | 二级 |
| 金银衡验具 | 40 | 二级 |
| 钟表开验具 | 50 | 二级 |
| 珠玉查验托具 | 30 | 二级 |
| 精细观察组件 | 60 | 三级 |
| 精密衡验组件 | 60 | 三级 |
| 钟表深验组件 | 80 | 三级 |

瓷器二级使用原有放大镜与灯。三级须同时配齐对应的普通套件及组件。知识在旧账柜学习，六组知识各用 1 次准备、免费，覆盖两个高级层级。扇画仍需要自己的知识，二级即能完成原有鉴定。

## 保存与验证边界

- 新局：内容／存档版本 32，自动槽 `auto/precision_ten`，独立旧式自动路径 `user://precision_ten/autosave_v32.json`。档案库仍为 `user://save_library/library_v1.json`。
- 外观与难度使用独立随机键，保存后不重抽；客流、交易方式和赎回原抽取不受影响。
- 十件货均已接入实物、图录及分级细节图片。原图与生成来源在 `assets/appraisal_v32/`，运行时只取当前允许看到的区域，文件名不包含本次货况。
- 180 组合测试覆盖证据、价值、快照及 JSON 稳定性；完整存档重放另由连续经营和实际写盘测试验证。测试预置本身明确不作为正式存档使用。
- 连续经营测试包含正式 300 银元开局，另用仅在测试中启用的 2,500 银元开局覆盖三级建设、多个大单、回赎及完整重放；该金额不写入正式配置。
- 本版保留批准的价格、概率和十夜限制。设施支出会占用放款本金，平衡后续依据实际试玩调整。

本地验收结果和实际截图见 [QA 记录](qa/precision-v32/REPORT.md)。
