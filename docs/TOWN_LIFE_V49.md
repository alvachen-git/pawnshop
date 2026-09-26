# 街巷百业 v49：柜台美术与日常货调价

> 当前启动器默认 v50（银耳坠替换算盘）。继续本文的 v49 进度请加 -Version 49；旧的 -Legacy 仍进入 v48。参见 [TOWN_LIFE_V50.md](TOWN_LIFE_V50.md)。

本轮仅本地试玩，未推送、未发布。完整内容沿用 v48，包含周怀安、特殊客、湿包货、陆掌眼卖货、活当和留声机。

## 画面修改

- 夹棉背心重新绘制为平铺软布，扩大到成年衣物的显示尺寸。
- 皮箱重新绘制为平放，前沿水平，两侧透视对称，底面接触柜台。
- 士兵重新绘制为平视、正常短颈、放松肩膀和自然躯干，保留背手站姿；不暗示货物隐藏来源。
- 六件货统一接入柜台接触阴影、明暗和饱和度处理；煤油灯、手炉使用底座阴影，平放物使用轮廓接触阴影。鉴定展示维持中性处理。
- 二胡适当放大，保留完整琴杆与琴弓；其余物品逐项检查。
- 图像由内置 image_gen 生成，原生透明 PNG，未程序抠图。最终提示词：assets/town_life/ENVIRONMENT_PROMPTS_V49.json。
- 替换前原图保留在 .godot/qa/town-life/before-v49/。

## 货值

| 商品 | 完好 | 修补 | 破损 |
| --- | ---: | ---: | ---: |
| 算盘 | 12 | 7 | 2 |
| 铜手炉 | 65 | 42 | 18 |

单位为银元。表中是实际货值；客人的开价仍按职业参数计算，买家报价仍按既有收货规则计算。算盘的品相议价幅度随较低货值缩小。

## 启动

完整新局：

~~~powershell
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd"
~~~

快速检查（预置进度不保存）：

~~~powershell
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd" -Stage goods -Item padded_vest
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd" -Stage goods -Item leather_suitcase
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd" -Stage soldier -Wide
~~~

其他货物：abacus、copper_handwarmer、kerosene_lamp、erhu。添加 -Wide 使用 1600×900；默认 1280×720。

## 旧进度

默认入口使用新内容版本 49、运行标识 town_life_v49，独立存档 user://town_life_v49/。旧 v48 数据和存档没有改价或迁移。继续旧进度使用：

~~~powershell
& "D:/CodexData/runs/pawnbroker-town-life/play-town-life.cmd" -Legacy
~~~

-Legacy 使用旧价格和旧存档，仍可看到本轮画面修正。旧的其他试玩入口不变。已打开的游戏需退出并重新启动才能看到更新。

## 验证

记录见 TOWN_LIFE_V49_QA.md。实际游戏截图放在试玩目录 preview/；物件原图位于 assets/town_life/items/，士兵原图位于 assets/town_life/customers/soldier.png。
