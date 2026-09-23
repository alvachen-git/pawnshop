# v28 本地测试入口

开发目录为 `.artifacts/first-debt`，分支 `codex/first-debt-v28`；`.artifacts/main` 仍是未合入这批改动的主线。此次没有推送或合并。

## 直接从第十一夜试剧情

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt -- --first-debt-preview=seller
```

直接进入第十一夜18:00，周成业已带凤镯来到柜前。点击人物可问来路、展开随货旧包纸；鉴货、议价或拒收均照常。第十夜留下的旧票已在「旧当铺」册页里，但未替玩家细看。可以继续经营到后续陈家与陆掌眼来访。

使用固定种子42、由正常经营动作生成的阶段档，现银368银元；每次执行命令重新从此处开始。测试自动位与手动槽隔离在 `user://tests/v28_preview/seller_library.json`，不覆盖正常游玩档案。此参数只用于源码调试，不改变普通新游戏入口。

## 从第一夜开始

正常启动：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt
```

固定种子：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt -- --seed=42
```

请选择新游戏进入v28。旧存档继续使用原内容，不会在旧v27中插入金镯案件。新自动位为 `auto/first_debt_open`；原六个手动槽共用，测试代码使用 `.godot/qa/v28/` 下的隔离档案。

建议依次看：第十夜只留下旧票 → 第十一夜先把凤镯当货看，展开旧包纸后也可以拒收 → 旧当铺翻纸或托陈家口信 → 库存卖货页问陆掌眼 → 次夜与陈小满核实、看龙镯 → 归还或赔偿 → 第十八夜日结选择继续营业。可故意提前关铺，第二十五夜再补案。

开发回归在该目录执行（所有测试最后都应输出零失败；还需检查是否出现SCRIPT ERROR）：

```sh
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_routes.gd --log-file /private/tmp/fd-routes.log
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_durability.gd --log-file /private/tmp/fd-durable.log
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_process.gd --log-file /private/tmp/fd-process.log
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_edges.gd --log-file /private/tmp/fd-edges.log
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_coexist.gd --log-file /private/tmp/fd-coexist.log
/opt/homebrew/bin/godot --headless --path . --script tests/first_debt_long.gd --log-file /private/tmp/fd-long.log
/opt/homebrew/bin/godot --path . --script tests/first_debt_ui.gd --log-file /private/tmp/fd-ui.log
/opt/homebrew/bin/godot --path . --script tests/first_debt_ui.gd --log-file /private/tmp/fd-ui-wide.log -- wide
```

先跑routes产生真实动作生成的测试档，再跑durability与process；UI也使用routes的档案。分支与长局测试含明确标注的资金夹具；另有默认300银元起步、正常收购出货筹钱的归还和赔偿路线。夹具不改发布数据。

百夜、10534动作冷启动完整回放约22秒，界面测试不等同于从第一夜起真人完整游玩。自动结果、真实窗口与目视结论分列在 [验收报告](qa/first-debt-v28/REPORT.md)。

## 旧当铺册页（第3版设计）

上面的第十一夜命令仍然适用。进入柜台后，点「账本 → 旧当铺」，或从右上菜单直接进入「旧当铺」。这一阶段只夹有已留下的旧票，不会凭空展示陈家旧记或卖家的包纸。

- 「旧当票／旧凭据／铺中旧物」按实物分类；多张旧当票用上一档、下一档翻阅。
- 点票面或「放大细看」读资料；「展开原件」可用滚轮放大查看票面细节。原件右下「返回册页」、右上按钮或Esc均一次返回册页；在册页再按Esc回柜台。
- 实际看过随货旧包纸、取得陈家旧记后，两者会夹在旧票右页；「并排查看」只列已读资料。
- 「翻查与托话」保留翻旧账背页、托陈家口信及约卖家等当下可办事项；托话仍按按钮所示耗5分钟。
- 打开册页、切换分类、复看和并排阅读免费；首次细读仍原子保存，写盘失败不记发现，提示重试。

册页回归：
```sh
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-ui.log
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-wide.log -- wide
```

截图与单独验收见 [册页报告](qa/old-shop-album/REPORT.md)。已有v28进度可以继续使用；v27及更早仍保留原「旧事」。
