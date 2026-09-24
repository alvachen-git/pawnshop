# 老凤祥花雕金镯 · v39 本地试玩

开发基线：线上 main `0e2fb42bee56d7e7819b7419396a3299d19fd4ce`。发布已整合至 `9da27b0`，保留 PR #59 首笔旧债、PR #60 普通物品图及 PR #61 店内音效。统一入口使用 v40，旧入口与存档继续保留。

## 启动

在 PowerShell 任意目录运行：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-bangle-v39.cmd" -Stage bangle -Wide
```

默认是“重量相符的镀金样本”，不是正式存档。先点击柜上物品 → 鉴定 → 器材鉴定。

- 放上金镯，加入20克和10克砝码，观察两盘平衡。
- 选戳记、内圈、镯身或接合处，转动、放大查看；隐蔽样本要换角度。
- 在内圈、镯身或接合处开始火试，等3秒自动收火；也可提前收火。
- 冷却后擦去烟污，直接看两张并排图比较；无需额外点比较按钮。图样是证据，不弹出真假答案。
- 随时记下判断并落笔，直接回柜台；商量价钱中可以另选说法。

## 情境参数

在同一启动指令后追加参数；未指定的保持默认值。

| 参数 | 值与用途 |
|---|---|
| `-BangleCase` | `matched` 重量30克的镀金样本（默认）；`good` 足色无修补；`lower` 成色不足；`plated` 镀金；`repaired` 足色有旧接焊；`partial` 谨慎只部分让价；`firm` 承认后不让价；`exposed` 不实说法被拒；`no-tools` 缺设备；`guide` 开铺前第三柜学习；`natural` 保留自然抽取结果 |
| `-Holder` | `silk` 周锦生、`factory` 李衡、`opera` 程玉笙、`antique` 沈季安、`comprador` Edward |
| `-Damage` | `intact` 完好（默认）、`minor` 轻损、`major` 重损 |
| `-Difficulty` | `ordinary` 普通（默认）、`hidden` 隐蔽 |
| `-Wide` | 1600×900；不加为1280×720 |

例如：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-bangle-v39.cmd" -Stage bangle -BangleCase repaired -Holder opera -Difficulty hidden -Wide
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\play-bangle-v39.cmd" -Stage bangle -BangleCase guide -Wide
```

除 `natural` 外，有货情境固定为买断且重置客人初始认识、性格与相信抽签，以便复现。`partial`、`firm` 携带已修补的足色金镯；谈“有接焊修补”观察让价。`exposed` 携带足色无修补金镯，提出不实指控观察处罚。所有预置显著显示“本次进度不保存”，独立于正式存档。

## 正式新局与旧版

`-Stage normal` 进入整合 v40 正式新局入口；存档 `user://bangle_unified/autosave_v40.json`。v39 金镯独立入口为 `scenes/start_bangle_v39.tscn`，线上首笔旧债 v39 入口为 `scenes/start_first_debt_v39.tscn`，两者原存档与规则均保留。已有v38及更早存档保留旧规则；`scenes/start_pearl_v38.tscn` 可单独打开旧版。旧主目录没有切换分支，根目录新增的启动脚本仅转发到隔离工作区。

## 已实现规则

足色440、成色不足330、镀金70；修补保留85%，外伤保留100/80/50%，最后一次四舍五入。重量是独立线索，不额外乘入价值。初始行情区间70—440，外观查验调整显示；私人判断与客人错误认识不改变货值。

二级鉴物台、放大镜、灯、金银衡验具与金银器知识解锁10分钟器材鉴定；5分钟外观查验不依赖设备。操作与复看免费，三级继承能力，无深入查验入口。

第三柜指南三页：称重对款、看戳与接缝、火试后看什么。首次学习1次准备，免费；第二柜名表、第五柜珍珠保持原用途。

火试是游戏化、无破坏观察，不提供真实实验操作参数或精确纯度判断。足色可以修补，仿品可以称重相符；界面仅展示观察与玩家手记。

谈价分金料、修补、外观，每类一次；允许改口与误导，沿用相信与让价分离的既有框架。五位持有人的底价、耐心、筹款线、赎回参数保留。货值、手记、对客说法、客人认识分开保存。

## 验证与截图

见 [validation.txt](qa/bangle-v39/validation.txt)。同目录提供两种分辨率的柜台、称重、火试、指南、手记与谈价截图。美术来源及生成提示见 [SOURCE.md](../assets/bangle_desk/SOURCE.md)。
