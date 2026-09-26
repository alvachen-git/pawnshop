# 街巷百业 v50：以银耳坠替换算盘

新局的第六种日常货由算盘改为一对银耳坠，属于首饰。其余五件货、四种职业及既有故事维持原规则，铜手炉沿用 v49 的 65／42／18 银元。

## 物品规则

| 品相 | 实际货值 | 深入检查线索 |
| --- | ---: | --- |
| 成对完好 | 38 | 分量相称，银质细密，连接牢靠 |
| 耳钩补焊 | 25 | 耳钩根部有补焊，纹样磨平 |
| 低成色掺铜 | 9 | 磨损处透铜，两只坠头色泽不一 |

单位为银元。生成权重沿用 60%／30%／10%，开价按职业参数计算。支持现有卖断、活当、来源核验和买家出货；无需新鉴定台。新局所有原算盘货池引用改为银耳坠，包括普通客、周怀安以及毡帽/湿包特殊客。特殊客普通80%／高档20%的比例不变。

新图为内置 image_gen 生成的原生透明 PNG，接入柜台接触阴影与环境色调。文件 assets/town_life/items/silver_earrings.png；最终提示词 assets/town_life/SILVER_EARRINGS_PROMPT.txt。

## 启动

完整新局：

~~~powershell
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd"
~~~

直接查看银耳坠（预置不保存进度）：

~~~powershell
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd" -Stage goods -Item silver_earrings
~~~

- 添加 -Wide 使用1600×900；默认1280×720。
- -Condition mended 查看补焊品相，-Condition flawed 查看低成色品相；画面为同件物品通用外观，真实品相通过检查线索确认。
- 继续上一轮 v49 存档：加 -Version 49。
- 继续 v48 存档：加 -Legacy 或 -Version 48。
- 默认新局为 v50，独立存档 user://town_life_v50/。旧 v48/v49 仍保留算盘及各自价格，不改写旧交易历史。
- 已打开的游戏需退出后重新启动。

本轮仅更新本地试玩，未推送或发布。验证记录见 TOWN_LIFE_V50_QA.md。

## 银耳坠柜台比例修正

对照人物手掌，将柜台耳坠的宽高缩至此前约45%，中心位置保留；1280×720下可见高度约35像素。鉴定页继续放大展示细节，原有宽裕点击范围保留。没有改动货值、货池或存档。两种分辨率实机UI各24项通过，人工核对柜台与鉴定页。截图已更新，旧图备份在 .godot/qa/town-life/earrings-before-scale/。
