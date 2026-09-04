# M4 内容制作与验证

M4证明普通物品、顾客、简单事件可以仅修改数据加入游戏。正式入口是`data/content_manifest.json`，当前内容版本5、默认运行`p0_m4`。旧M3内容由`tests/fixtures/m3_manifest.json`显式加载，仅作为回归夹具。

## 已生效内容

- 8件普通货：青花小碗、黄铜烛台、银簪、怀表、端式砚台、紫砂小壶、花鸟绣片、赛璐珞钢笔；每件至少两种品相/真伪变体。
- 4种普通顾客：旧城住户、夜市货郎、旧书铺先生、富户管事；富户管事只卖断。
- 3名买家：杂货回收商、瓷器收藏客、通过事件介绍的商会旧货客。
- 7个事件定义：3个开铺前锚点、2个条件事件、2个随机闲谈。一次运行不会保证遇到全部事件。
- 三夜各4个独立来访槽，共12次来访。当前按配置指定变体，便于内部验证；可清空variant_id使用既有seed权重抽取。

## 新增普通物品

在`data/items/items_m4.json`增加唯一ID记录；可复制邻近品类，但必须重新编写描述、真值、证据及估值区间。

- `possible_variants`描述物品真实状态，包含真值和实际存在的线索ID。
- `clues`包含玩家可见证据、估值范围、判断类别和一次性议价筹码。
- `appraisal_actions`声明前置线索、所需工具、耗时和可揭示线索。
- 真值必须位于相关证据区间内，线索必须从无前置动作逐步可达。
- 商品加入顾客`item_pool`，并在运行来访槽引用；新工具要同时加入运行`tools`。
- 确认至少一个买家品类/渠道匹配，避免商品只能买不能卖。

`TradeController`与`AppraisalSystem`不应新增物品ID判断。

## 新增普通顾客和三夜编排

在`data/customers/customers_m4.json`新增记录，配置`counter_terms`、问答、耐心、报价轮次、货池和交易模式。需要活当时同时引用有效`pawn_terms_id`。

`data/runs/p0_m4.json`的`customer_slots`支持可选`night_min`、`night_max`。缺省覆盖所有夜晚，保持旧夹具行为；显式填写可安排不同夜的来访。`arrival`是从18:00起累计分钟，不是墙钟数值。夜内排队与接待共用等待期限。

`CustomerManager`不应新增顾客ID或具体第几夜的分支。

## 新增简单事件

在`data/events/events_m4.json`新增记录，并将ID加入运行`event_ids`。所有标记加入运行`flag_ids`。

| 字段 | M4语义 |
|---|---|
| id/title/speaker/body | 稳定ID与可见文字；对白直接由内容提供 |
| kind | anchor / conditional / random |
| phase | pre_open / open / closed_processing |
| night_min/night_max | 可出现的夜次范围，含端点 |
| window_start/window_end | 从18:00起累计分钟，左闭右开 |
| priority | 同一类型内越高越优先，确定性同分按ID排序 |
| weight | 同优先级random候选的正整数抽取权重 |
| max_count | 每周目最多完成次数；1等价于只出现一次 |
| cooldown | 完成后要跳过的整夜数；同一事件同夜不重复 |
| required_flags/excluded_flags | 全部满足/任一命中即排除 |
| required_items | 必须持有这些定义ID的现货或在当物；已售、已赎不算 |
| conflicts_with | 当夜互斥事件ID，双向检查 |
| choices | 稳定选项ID、label、result、minutes、grant_flags |

选择只支持声明过的`grant_flags`，标记只增加、不撤销；M4不接受任意脚本表达式、现金修改或鬼货效果。后续事件可依赖这些标记，买家`required_flags`可据此解锁，所有现金变化仍经过既有交易领域。

### 调度与范围

1. 所有符合条件的anchor优先，互不争用普通事件额度。为保证关键内容不被一次等待或提前关门跳过，M4锚点限于无条件开铺前事件；不允许物品/标记前置、互斥或营业窗口锚点。
2. conditional其次，未轮到时保留其数据条件，在后续可用阶段/夜次重新扫描；窗口结束后不补发。
3. random最后，同优先级按weight抽取。每夜最多完成1个非锚点事件，让经营保持主体。具体事件一旦成为待办就固定，不因界面刷新重抽。
4. 事件在运行初始化、新夜进入与命令完成后扫描；单次行动不拆成多个事件时间片。跨过普通事件整个窗口可能错过机会，这是普通事件的允许结果。
5. 有待办时必须先选择，再继续营业/交易/时间推进；查看资料、读档和新游戏仍可用。每个事件至少有一个当前可完成的选项才进入待办。
6. 开铺前叙事确认耗时0；营业/关门后的正式事件选择耗正整数步长分钟，必须在窗口结束前完成。只阅读不耗时。

这不是完整49夜调度器：尚无动态NPC状态、跨系统任意effects、复杂对白图、章节预算、超窗替代剧情或鬼货风险。

## 数据扩展验收夹具

`tests/fixtures/m4_extension.json`包含全新ID的物品、顾客、事件和两夜运行。M4测试仅将这份配置交给现有Schema、Mapper和内存Provider，即可完成事件触发、鉴定、报价、扣款和入库。新商品/顾客/事件均未加入核心业务分支。

运行：

```sh
godot --headless --editor --quit --path .
godot --headless --path . --script res://tests/run_all.gd
```

新增数据至少要验证：引用与证据可达性、真实来访、一次交易、事件选择、窗口边界、存档往返。正式美术仍为占位，数据中的asset标识不代表资源已制作。
