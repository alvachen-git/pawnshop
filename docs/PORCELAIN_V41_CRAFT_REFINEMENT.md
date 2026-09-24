# v41 青花瓷工艺表现补全

## 本轮修改

- 为四年代、两套样本、普通与仿古干扰分别接入三档工艺图样，共 16 张透明图集、48 组工艺表现、336 个显示区域。
- 整器正面、左右侧面、背面、绘纹、底足及柜台俯视图均按固定实物的工艺取图，不再仅局部图片区分粗工、常品、精工。
- 粗工用填色越界、线条参差和收边不齐表达；常品布局规整、细部简洁；精工强调收笔、细线层次、留白及足边处理。避免用整张模糊作为工艺判断。
- 《青花断代图录》工艺页可切换整器、绘纹、底足，三个等级并排比较。图录使用固定教学样本，不读取当前货物答案。
- 图集按透明轮廓裁切，修正邻格残片及阴影截断；柜台使用带接触阴影的俯视图。

本轮未改生成概率、实际价值、谈价、时间成本或存档语义。图样为游戏教学样本，不代表某个年代的全部器物特征；工艺、年代与外伤仍分别判断。

## 验证

Godot 4.6.1，Windows；界面在 1280×720、1600×900 验证。

| 检查 | 结果 |
|---|---|
| porcelain_craft_ui | 1,408 项通过：16 组图集、三工艺、四朝向、各局部和柜台取图，区域边界及固定事实不变 |
| porcelain_refined_ui | 321 项通过：实际柜台与图样路由 |
| porcelain_ui | 两个分辨率各 85 项通过：图录分组、免费复看、落笔返回、谈价与缺设备 |
| porcelain_appraisal | 9,777 项通过：固定货值、判断、谈价与回滚 |
| porcelain_economy | 35 项通过：收售经济闭环 |

各项均为 0 失败。Windows 根证书读取警告不影响这些离线检查。原始记录见 `qa/porcelain-v41/verification/craft-*.txt`。此前完整玩法回归记录保留在 [验收记录](PORCELAIN_V41_ACCEPTANCE.md)，本轮没有重跑其中全部旧玩法测试。

人工检查了明代普通、元代普通、清代干扰及民国干扰对照图和两种尺寸的实际图录画面；完整 16 组对照截图保存在 `qa/porcelain-v41/craft/`。

## 本地试玩

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.artifacts\porcelain-appraisal-v41\play-porcelain-v41.cmd" -Stage porcelain -Era ming -Craft rough -Wide
```

`-Craft` 可替换为 `standard` 或 `fine`，`-Era` 可用 `yuan`、`ming`、`qing`、`republic`。`-Sample 2` 切换另一套样本，`-Difficulty hidden` 选择仿古干扰。测试预置不占正式进度。

## 预览与来源

- [实际工艺图录](qa/porcelain-v41/porcelain_1600_craft_painting.png)
- [明代三档对照](qa/porcelain-v41/craft/ming_1_ordinary.png)
- [民国仿古三档对照](qa/porcelain-v41/craft/republic_2_hidden.png)
- [新素材与生成说明](../assets/porcelain_desk/craft/SOURCES.md)

本轮仅交付本地版本，未推送或合并。
