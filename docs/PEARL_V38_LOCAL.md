# v38 灯下验珠：本地试玩与验收

本版从已发布 main `f4e996b3513c4e893e479fd580e5b05dac3c45da` 建立隔离工作目录，分支 `codex/pearl-appraisal-v38`；发布前同步 main 的物品鉴定图与结局美术更新。v37及更早存档保留原规则。

## 启动

从任意 PowerShell 目录启动珍珠环节：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-pearl-v38.cmd" -Stage pearl -Wide
```

开发机根目录的快捷脚本转到 `.artifacts/pearl-appraisal-v38`；从 main 获取的项目直接运行项目内同名脚本，使用本地 Godot（也可通过 `-GodotPath` 指定）。试玩写入隔离的 APPDATA；预置进度不保存、不覆盖正式存档。屏幕上标明测试预置。默认是程玉笙持有的少量混仿、外观完好、普通难度；不是正式客流抽样。

工作目录内也可运行 `./play-unified.cmd -Stage pearl -Wide`。去掉 `-Wide` 使用1280×720；加上后为1600×900。`-Verify` 验证启动并自动退出。

### 选择情境

| 参数 | 可用值 |
|---|---|
| `-Holder` | `silk` 周锦生、`factory` 李衡、`opera` 程玉笙、`antique` 沈季安、`comprador` Edward |
| `-PearlCase` | `good` 好货、`lower` 低档换配、`few` 少量混仿、`many` 多量混仿、`imitation` 全仿 |
| `-PearlCase` | `partial` 部分让价、`firm` 强硬不让、`exposed` 识破虚假说法、`no-tools` 缺设备、`guide` 第五柜学习、`natural` 保留生成结果 |
| `-Damage` | `intact` 完好、`minor` 扣环变形、`major` 断线但珠子齐全 |
| `-Difficulty` | `ordinary` 普通、`hidden` 细节要转到对应角度 |

例如：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-pearl-v38.cmd" -Stage pearl -Holder comprador -PearlCase partial -Wide
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-pearl-v38.cmd" -Stage pearl -PearlCase guide -Wide
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-pearl-v38.cmd" -Stage watch -Holder silk -WatchCase natural -Wide
```

`partial`、`firm`、`exposed`是可重复对比的谈价预置，货物为好珠。试着提出“整串仿珠”，分别观察部分让价、坚持原价与拒绝说法。`few`、`many`等预置固定测试人格与反应，正式新局仍按规定概率独立生成。

正式v38新局：同一脚本 `-Stage normal`。独立存档位置为 Godot用户目录下 `pearl_market_ten/autosave_v38.json`；读入旧存档仍由原版本规则处理。原工程目录的旧代码与未提交内容没有被覆盖。

## 试玩顺序

1. 第五柜打开《珍珠鉴定指南》，学习占一次准备、免费；第二柜仍为《名表鉴定指南》。
2. 柜台点物品→鉴定。外观检查5分钟；器材鉴定10分钟，需要二级以上台、灯、放大镜、珠玉托具与珠玉知识。
3. 选珠，左右转动或拖动，移灯；“放大孔口”与“返回表层”切换。当前珠子有细圈提示，异常珠不会自动标出。
4. 点“并排比较”留住第一颗，再选另一颗后再点一次。重复同一珠对不会累计依据。

5. 可随时记下材质、换配判断；暂难判断允许落笔。确认后直接回柜台，手记不可改写。
6. 商量价钱按整串提出材质、换配、已查外伤；默认引用手记，也可改口。每类问题只谈一次，合并提交5分钟、1轮。
7. 客人可以相信而让全部价差、部分让价，或承认而坚持原价。错误说法可能被信，也可能被识破；实际货值不变。

换珠时沿用当前转动角度、灯光、孔口／表层视图和放大状态。可以先调好一套观察方式，连续点选整串，再换角度或灯光查看下一轮。孔口模式下点选的新珠子会计入查验记录，重复点选不重复累计；只看表层不会算作查看孔口。换珠依旧免费。

此交互调整已验证：规则23,030项、经营及冷重放799项通过；1280×720与1600×900界面各101项通过，均0失败。角度继承与孔口记录一次提交，写盘失败整体回滚；旧的选珠动作保持原语义。

## 实现范围

- 五位富客×十种物品全部可生成，携货权重按批准表；富客人数与商誉概率不变。独立随机键保留原交易方式、货况与赎回抽取。
- 32颗珠子保存位置、大小权重、品质、纹理、孔口角度与色调。按逐颗组成计算固定实际价值，外伤只乘一次。
- 手记、已查看孔口/珠对、客人认识、对客说法、已承认真实情况、唯一机会与固定随机结果分开存储。
- 私人判断和被信的谎话不缩窄柜台估值；初始60—440，查出外伤后才调整。高价奖励只用真实且已承认的情况。
- 怀表改用实际持有人的开价、底价与筹款线，旧版本公式不变。其余八件货保留现有鉴定路线。
- 实物用生成的珠子细节图集、三个角度、孔口图、侧光与固定纹理组合呈现；指南使用固定范例，不读取当前货物。
- 这是游戏插画与观察练习，表面线索不提供天然/养殖来源保证；无维修系统。

## 验证记录

发布前同步 main `5673b92` 后已重新执行珍珠、经济、经营冷重放、铜镜、阿七、v37、怀表、折扇、入口兼容与物品美术检查；两种分辨率的珍珠UI和整合图录检查全部通过。最终发布检查结果见 [release.txt](qa/pearl-v38/release.txt)，以下保留开发过程记录。

验证于2026-09-23，Godot 4.6.1，Windows，本地NVIDIA兼容渲染。

| 检查 | 结果 |
|---|---|
| `tests/pearl_appraisal.gd` | 23,016通过，0失败；5×10携货、5万种子携货统计、组成/外观/难度、查验、手记、机会、回滚、指南学习 |
| `tests/pearl_economy.gd` | 593通过，0失败；相信概率、合并/分开、价格重算、资金不足、收购/放当/赎回/绝当、库存及批量出售、陈列估价、旧存档 |
| `tests/pearl_journey.gd` | 795通过，0失败；自然经营客流、真实查验与谈价日志、保存失败回滚、冷重放、赎回；另含明确增资的测试定义以覆盖资金密集操作 |
| `tests/pearl_story.gd` | 3,491通过，0失败；铜镜十夜剧情 |
| `tests/pearl_companion.gd` | 3,282通过，0失败；阿七 |
| `tests/named_wealthy.gd` | 1,211通过，0失败；v37固定姓名、旧配货与价格语义 |
| `tests/watch_negotiation.gd` | 1,070通过，0失败；怀表及旧版其他九货 |
| `tests/fan_condition.gd` | 2,078通过，0失败；折扇 |
| `tests/pearl_ui.gd` | 1280×720、1600×900各66项通过、0失败；实际鼠标操作，指南翻页、两珠比较、转动/侧光、落笔回柜台、改口、第五柜学习、无设备外观检查 |
| 统一启动器 | `-Stage pearl -Wide -Verify` 与显式指定持有人均已成功启动并退出 |

日志中的 `Failed to read the root certificate store` 是本机Godot证书库警告；上述离线规则与UI测试均可完成。首次导入曾遇到默认APPDATA编辑器设置写权限问题，后续验证与试玩使用工作目录下隔离APPDATA。

截图在 [qa/pearl-v38](qa/pearl-v38)，资产来源在 [assets/pearl_desk/SOURCE.md](../assets/pearl_desk/SOURCE.md)。最终本地检查含 `git diff --check`。价格与概率采用本轮批准的首版数值，后续按试玩反馈调整。

## 珍珠观察清晰度与桌面精简 · 2026-09-23

- 鉴定桌移除“检查外观”和“器材鉴定／复看”，保留指南与记下判断；外观5分钟、器材10分钟仍在柜台选择。库存／设施的未查验物品先显示耗时和缺项，成功开始后进入同一桌面；已查验直接免费复看。
- 指南第一页明确两幅均为正常参考；第二页放大正常与涂层异常孔口，标注孔壁、翘层及底色；第三页明确优质真珠与低档真珠的比较。
- 仿珠三角度孔口重绘为更清楚的翘层和露底；隐蔽样本仍需转到固定角度，材质事实、货值、谈价和保存格式不变。实际查验不自动标出异常珠、不显示真假答案。
- 本次重新运行 `tests/pearl_appraisal.gd`：23,016通过、0失败；`tests/pearl_ui.gd`：1280×720和1600×900各77项通过、0失败。覆盖扣时一次、桌面按钮、指南、两种难度角度、库存入口门槛、免费复看、落笔回柜台。上表其他规则测试为本版此前验证，本次未重复执行。
- 实际画面：[1280孔口](qa/pearl-v38/pearl_1280_hole.png)、[指南放大标注](qa/pearl-v38/pearl_1280_guide_1.png)、[1600隐蔽孔口](qa/pearl-v38/pearl_1600_hidden_hole.png)。
