# 青花瓷与金怀表柜台融景验收

2026-09-25，camera-appraisal-v43 本地隔离工作区，未推送或合并。

## 结果

- Godot 4.6.1 资源导入通过。
- 1600×900 与 1280×720 实际柜台各 82 项检查，均 0 失败。覆盖怀表三种外观、瓷器四年代柜台截图、全部 48 个瓷器图集区域、鉴定入口和物品事实不变。
- `tests/porcelain_craft_ui.gd`：1408 项，0 失败。粗工、常品、精工及各观察方向保留独立图片，柜台使用新图。
- `tests/porcelain_refined_ui.gd`：321 项，0 失败。实际柜台各年代、样本、难度均使用专用绘制图，鉴定继续使用原图集。
- 19 个原鉴定资源 SHA-256 与调整前一致（16 张瓷器工艺图集、怀表原图集和两张机芯局部图）。
- `git diff --check` 通过。
- 图像检查：柜台物品完整可见，投影与底足／表壳接触；表壳尺寸缩小至展开怀表的尺度；瓷器四年代、各工艺纹样仍可区分。未改游戏规则或存档。

环境仍有 Windows 根证书读取警告，未阻止导入、渲染或本轮离线验证。

## 复核素材

本目录保存两分辨率实机截图、导入日志、验证日志和原图哈希。美术来源、指令与资源范围见 `docs/art/COUNTER_PORCELAIN_WATCH.md`。

## 本地试玩

PowerShell：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.artifacts\camera-appraisal-v43\play-unified.cmd" -Stage porcelain -Wide
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.artifacts\camera-appraisal-v43\play-unified.cmd" -Stage watch -Damage intact -Wide
```

这是隔离试玩入口，不占用正式进度。
