# 鬼市当铺 · v27 棉袄采购与军阀照应牌

此目录是独立 Godot 4.6.1 游戏。原版与 `.artifacts/social-relations`（v26）保持独立，不转换旧存档。

在项目根目录运行：

```powershell
.\play-social-v27.cmd
.\play-social-v27.cmd -Stage introduction -Wide
.\play-social-v27.cmd -Stage delivery -Wide
.\play-social-v27.cmd -Stage near_plaque -Wide
.\play-social-v27.cmd -Stage intimidation -Wide
```

- `normal`：正常第一夜开局，首次启动需点击新游戏。
- `introduction`：第二日开铺前孙大元登门；点击人物→交谈，三段对话结束后才解锁《往来簿》中的军阀。此时无货物、鉴定或议价，不占普通来客名额。
- `delivery`：第二夜，真实收购过三件棉袄，已接任务；点击柜台《往来簿》，勾选三件后交货。这次交货也会获赠牌子。
- `near_plaque`：第二夜，接近赠牌条件；在《往来簿》打点页送礼可获牌。
- `plaque`：已获牌，尚未开铺；点击柜台上方木牌可查看作用。
- `intimidation`：已获牌且正在接待普通客人；点击客人→交易→商量价钱→借军方牌子压价。
- `cotton`：普通客人正在出售棉袄，可鉴定、议价和收购。
- `closure`／`supply`／`claim`：停业令、特殊货源和旧主追索的回归场景。

专项场景每次启动都会重新生成并校验，进入时从该场景起点开始。正常开局使用独立的 normal 存档目录。`-Verify` 会打开真实窗口并自动关闭，用于启动检查；正常试玩不要添加这个参数。

完整规则、测试与经济对比见 [验证报告](docs/v27/VALIDATION.md)。

2026-09-18：结识流程已改为柜台接待。新局及 introduction 场景使用新流程，中途保存可继续交谈；更早的 v27 存档沿用原结识规则，已认识孙大元的旧局不会重复登门。营业页不再显示首次结识的长篇对白。
