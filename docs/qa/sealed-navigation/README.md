# 封铺后的结算与回房入口

2026-09-14，基于 main `06f4749` 的封铺导航修复。

## 问题与行为

第二夜等到封铺后，打开保存菜单会收起原来的夜间结算面板；再打开营业面板，只能看到禁用的营业操作和不合时宜的准备提示。原有菜单中的“夜间结算”仍可继续，但营业入口没有指引。

- 未结账时，营业面板显示“查看夜间结算”，进入原有核票与息费流程。查看本身不结算、不耗时。
- 已结账、处于铺内收尾时，营业面板显示“回房”，执行原有进入寝屋操作。
- 存在未处理的物品危机或铺中事件时，显示相应查看入口；回房继续受原有行动校验限制。
- 保存或读取上述阶段后，入口仍可使用。没有修改保存格式、费用规则或剧情，不要求重开；没有读取或改写玩家存档。

## 验证

macOS / Godot 4.6.1，使用独立测试存档。

| 检查 | 通过 | 失败 |
| --- | ---: | ---: |
| 封铺导航专项（headless） | 116 | 0 |
| 封铺导航实际鼠标操作 1280×720 | 119 | 0 |
| 封铺导航实际鼠标操作 1600×900 | 119 | 0 |
| 原有房间核心回归 | 701 | 0 |
| 房间界面与未决危机导航 1280×720 | 292 | 0 |

修复前专项测试复现 76 项检查、1 项失败：保存后重新打开营业面板，没有可见的结算入口。修复后的专项包含第二夜封铺、实际菜单存档、结算、回房，以及分别读取结账前后存档再回房；核对现金和日结不会重复扣费。已人工查看两种尺寸截图，入口完整可见。

以上最终日志扫描无 `SCRIPT ERROR`、`Parse Error`、`Invalid call`、`ERROR:`、`FAIL`；`git diff --check` 通过。专项已纳入 Windows 测试脚本，但本次未执行 Windows、打包或完整游戏回归。

日志：`/private/tmp/pawn-sealed-after.log`、`/private/tmp/pawn-sealed-1280.log`、`/private/tmp/pawn-sealed-1600.log`、`/private/tmp/pawn-sealed-room-core.log`、`/private/tmp/pawn-sealed-room-ui.log`。

截图：[封铺后保存](sealed_1280_after_save.png) · [结账后回房](sealed_1600_return_room.png)。

## 本地继续游戏

关闭当前游戏窗口后执行，并读取已有存档：

```sh
godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/main
```

专项复测：

```sh
godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/main --script tests/sealed_navigation_ui.gd --log-file /private/tmp/pawn-sealed-recheck.log
```

末尾添加 `-- wide` 验证 1600×900。

## 独立发布复核

在 `codex/sealed-navigation-20260914` 独立工作树、main `06f4749` 基线上重新导入后，串行复验：封铺导航 1280×720 和 1600×900 各 119/0、房间核心 701/0、房间界面与危机入口 292/0，共 1,231 项检查、0 失败。发布日志以 `/private/tmp/pawn-sealed-release-` 为前缀，无脚本、解析或调用错误。未配置 GitHub Actions 工作流。
