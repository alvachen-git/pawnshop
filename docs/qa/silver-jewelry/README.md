# 银戒指、银锁美术接入

> 这是发布前本地试玩记录。当前远端基线和重新验证结果见 [发布验收](../item-art-release/README.md)。仓库保留文中链接的精选截图；完整过程图留在原本地试玩工作区。

2026-09-23，独立试玩工作区 `.artifacts/item-art-grounding`。两张新正面原画使用内置 imagegen，沿用 ART04 半写实水粉方向。原图、完整提示词和生成来源见 [素材说明](../../../assets/item_art_v30/SOURCE.md)。

## 比例与范围

银戒指按普通约 2 cm 素圈、小银锁按约 4 cm 锁坠的相对体量设计；柜台画面没有厘米标尺，这些数值是设计参照。1280×720 下主体可见宽度约为 28 px 和 51 px，1600×900 按同一比例缩放。点击区域维持约 128 px 以上宽度，鉴定图独立放大，避免为方便点击而把实物画大。

两者平放，保留原画厚度、真实透明通道及近距离接触阴影。只替换它们已发布的 `goods_v21/*_front.svg` 路径；自定义图优先，既有背面、细节和线索门槛不变。柜台、鉴定、库存、成交回执共用新的正面资源。未改物品、价格、存档结构或排班。

**场景边界**：这两件物品属于现有 `goods_expertise` 货品扩展内容；默认 v30 十夜清单尚不包含它们。已在对应的真实七夜场景自然来访中验收，没有为了展示美术修改默认排班。

## 实机截图

| 物品 | 1280 柜台 | 1600 柜台 | 1600 鉴定 |
| --- | --- | --- | --- |
| 银戒指 | [截图](1280_item_silver_ring_counter.png) | [截图](1600_item_silver_ring_counter.png) | [放大图](1600_item_silver_ring_appraisal.png) |
| 银锁 | [截图](1280_item_silver_lock_counter.png) | [截图](1600_item_silver_lock_counter.png) | [放大图](1600_item_silver_lock_appraisal.png) |

`*_before.png` 是同一来访中用旧 SVG 和旧尺寸重建的对照；其余截图为新资源实际运行结果。

## 验证

- macOS 真实图形窗口 1280×720：198 assertions，0 failures。
- macOS 真实图形窗口 1600×900：198 assertions，0 failures。
- 图片映射、自定义路径及线索资源契约：120 assertions，0 failures。
- 真实来访：银戒指 seed 3、银锁 seed 1，均第一夜第二位来客。
- 免费看图不改变游戏状态，正常鉴定、收购与库存均验证；在 v21 支持的收铺节点进行 JSON 编解码和状态恢复。没有把 v30 营业中回放格式套用到旧场景。
- 原图 SHA-256 与 alpha 校验、资源导入、`git diff --check` 通过。未做 Windows 打包或全部旧版本迁移验收。

日志见本目录 `validation-1280.txt`、`validation-1600.txt`、`validation-contracts.txt`。

## 直接查看

这些指令使用独立测试存档，自动走到对应自然来访，然后保留游戏窗口供手动检查和继续交易：

银戒指：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/item-art-grounding" --script res://tests/silver_jewelry_art_ui.gd -- review-ring
```

银锁：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/item-art-grounding" --script res://tests/silver_jewelry_art_ui.gd -- review-lock
```

追加 `wide` 可用 1600×900 查看。要从头玩对应扩展场景：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/item-art-grounding" --scene res://scenes/goods_expertise_start.tscn
```
