# 真实窗口验收：物品接入与比例修正

> 这是发布前本地试玩记录。当前远端基线和重新验证结果见 [发布验收](../item-art-release/README.md)。仓库保留文中链接的精选截图；完整过程图留在原本地试玩工作区。

2026-09-22，Godot 4.6.1，macOS / OpenGL Compatibility，默认 v30 十夜入口。最终两种分辨率各 899 项检查、0 失败；独立资源契约 106 项、0 失败。日志存于本目录 `validation-*.txt`。

## 茶壶、钢笔缩小反馈

| 物品 | 修改前 | 最终 1280×720 | 最终 1600×900 |
| --- | --- | --- | --- |
| 紫砂小壶 | [原尺寸](1600_item_clay_teapot_before_scale_feedback.png) | [小壶](1280_item_clay_teapot_counter.png) | [小壶](1600_item_clay_teapot_counter.png) |
| 钢笔 | [原尺寸](1600_item_fountain_pen_before_scale_feedback.png) | [钢笔](1280_item_fountain_pen_counter.png) | [钢笔](1600_item_fountain_pen_counter.png) |

茶壶、钢笔宽高分别缩小约 28%、29%；相同自然来访和场景下复查，尺寸参照桌上的账本与手铃。小钢笔的点击区域继续可用。自动化断言不能证明美术比例真实，已另行查看最终两种分辨率截图。

## 其余物品

| 物品 | 柜台 1280 | 柜台 1600 |
| --- | --- | --- |
| 砚台 | [截图](1280_item_inkstone_counter.png) | [截图](1600_item_inkstone_counter.png) |
| 绣片 | [截图](1280_item_silk_panel_counter.png) | [截图](1600_item_silk_panel_counter.png) |
| 烛台 | [截图](1280_item_brass_holder_counter.png) | [截图](1600_item_brass_holder_counter.png) |
| 铜镜 | [截图](1280_item_weeping_mirror_counter.png) | [截图](1600_item_weeping_mirror_counter.png) |
| 怀表 | [截图](1280_item_pocket_watch_counter.png) | [截图](1600_item_pocket_watch_counter.png) |

完整本地过程图还包含实际鉴定、背面、线索操作后、库存画面和怀表三个光照阶段。文件名带 `previous_layout` 的图是在当前场景用同一 PNG 重建旧 ART09 显示尺寸与未校正高光，仅用于比较，不是历史 main 的原始截图。

每类物品由真实内容与自然排班 seed 进入，执行实际鉴定和收购。v30 存档严格编解码回放后核对资源，费用及已知线索按真实游戏流程验证。测试数据与存档隔离在 `.godot/qa/item-art/runtime/`。
