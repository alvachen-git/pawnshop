# 试玩反馈修订：五件物品的尺寸与材质

> 这是发布前本地试玩记录。当前远端基线和重新验证结果见 [发布验收](../item-art-release/README.md)。仓库保留文中链接的精选截图；完整过程图留在原本地试玩工作区。

2026-09-23，默认 `scenes/start.tscn` / v30 十夜。沿用 `.artifacts/item-art-grounding` 试玩工程；启动路径没有变化。此处保留当时的试玩记录。

## 实际修改

| 物品 | 柜台轮廓宽度，1280×720 | 修改 |
| --- | --- | --- |
| 黄铜烛台 | 约 98 → 67 px（缩小 32%） | 重绘暗哑黄铜，收敛连续亮金边与高光；下移到接触桌面的位置 |
| 青花小碗 | 约 148 → 111 px（缩小 25%） | 原画等比例缩小，圈足使用局部接触阴影 |
| 银簪 | 约 148 → 97 px（缩小 35%） | 保持细长比例，缩小但保留容易点击的区域 |
| 砚台 | 约 171 → 119 px（缩小 30%） | 保留石质厚度和斜视透视，校正桌面占地 |
| 怀表 | 新设计 | 重绘正反面，原画自带表壳侧壁、弧面表镜、边缝及细表链；取消原先的纵向压缩 |

像素数按 alpha > 220 的主体包围盒与实际贴图缩放估算，详见 `scale-review.json`；这些是屏幕尺寸比较，不是物理厘米测量。以柜台账本、手铃及其他小物件的相对比例复查。新图保持 RGBA，没有离线脚本改动图像像素；[原图与提示词来源](../../../assets/item_art_v30/SOURCE.md)。

鉴定放大图仍保留清楚可读的尺寸。烛台旧背面/细节图的显示材质同步收敛高光；新怀表背盖与正面造型一致。银簪原有未配图的背面入口不再显示空白页，有自定义背图时仍可查看。现有鉴定线索、价格与存档结构保持不变。

## 截图对照

| 物品 | 1600 修改前 | 1280 最终 | 1600 最终 |
| --- | --- | --- | --- |
| 烛台 | [之前](1600_item_brass_holder_before.png) | [现在](1280_item_brass_holder_counter.png) | [现在](1600_item_brass_holder_counter.png) |
| 小碗 | [之前](1600_item_blue_bowl_before.png) | [现在](1280_item_blue_bowl_counter.png) | [现在](1600_item_blue_bowl_counter.png) |
| 银簪 | [之前](1600_item_silver_hairpin_before.png) | [现在](1280_item_silver_hairpin_counter.png) | [现在](1600_item_silver_hairpin_counter.png) |
| 砚台 | [之前](1600_item_inkstone_before.png) | [现在](1280_item_inkstone_counter.png) | [现在](1600_item_inkstone_counter.png) |
| 怀表 | [之前](1600_item_pocket_watch_before.png) | [现在](1280_item_pocket_watch_counter.png) | [现在](1600_item_pocket_watch_counter.png) |

烛台、砚台、怀表的“之前”为上一轮真实窗口截图；小碗和银簪为当前同一来访中，用相同 PNG 重建此前尺寸、材质与位置的截图。二者区别明确保留，没有将重建图称为旧 main 原始截图。

怀表放大：[正面](1600_item_pocket_watch_appraisal.png)、[闭合背面](1600_item_pocket_watch_back.png)。完整本地过程图还包含九类物品的鉴定、取证后、库存及怀表三种灯光阶段截图。

## 验证

| 检查 | 最终结果 |
| --- | --- |
| 1280×720 macOS 实际图形窗口 | 1176 assertions / 0 failures |
| 1600×900 macOS 实际图形窗口 | 1176 assertions / 0 failures |
| 资源映射、自定义图路径、知识筛选、铜镜结局与银簪空白页契约 | 108 assertions / 0 failures |

日志 `validation-1280.txt`、`validation-1600.txt`、`validation-contracts.txt`。覆盖九类物品的自然排班、实际鉴定/免费翻图、正常收购/库存、v30 存档严格编解码回放。未运行 Windows 打包和全部历史版本存档迁移。两种分辨率五件目标物品已逐张进行视觉复查，自动化计数本身不代表美术观感认可。

## 启动

关闭旧游戏窗口后重新运行，以加载新贴图：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/item-art-grounding"
```

自动复查（会依次展示九类物品并退出，存档独立于玩家存档）：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/item-art-grounding" --script res://tests/item_art_grounding_ui.gd
```
