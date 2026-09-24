# v29 本地测试入口

开发目录为 `.artifacts/first-debt`，分支 `codex/first-debt-v28`；`.artifacts/main` 仍是未合入这批改动的主线。此次没有推送或合并。

## 直接从第十一夜试剧情

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt -- --first-debt-preview=seller
```

直接进入第十一夜18:00，周成业已带凤镯来到柜前。点击人物可问来路、展开随货旧包纸；鉴货、议价或拒收均照常。第十夜留下的旧票已在「旧当铺」册页里，但未替玩家细看。可以继续经营到后续陈家与陆掌眼来访；核对陈家原票后才可正式说明违约。

使用固定种子42、由正常经营动作生成的阶段档，现银195银元；每次执行命令重新从此处开始。测试自动位与手动槽隔离在 `user://tests/v29_preview/seller_library.json`，不覆盖正常游玩档案。此参数只用于源码调试，不改变普通新游戏入口。

## 直接测试陈小满交易与凤镯对话

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt -- --first-debt-preview=chen
```

从真实经营动作回放生成的第十二夜19:00开始，现银85银元，已收凤镯但尚未联系陈家。陈小满先售卖绣片：可鉴货、问来路、议价、成交或拒收。交易中桌上只有她的绣片。成功时先收好成交凭据，再进入凤镯短对白；拒收、议价失败同样能接上。阅读、翻页与Esc不耗时，询问原当票并约她次夜带来仍耗5分钟。没有凤镯时不凭空认物。

此入口每次重新开始，独立测试档案为 `user://tests/v29_preview/chen_library.json`，不覆盖正常游戏档。源码改动在隔离工作树，启动 `.artifacts/main` 不会看到本次修改。

本次验收见 [陈小满交易与对白报告](qa/chen-trade-dialogue/REPORT.md)。

## 从第一夜开始

正常启动：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt
```

固定种子：

```sh
/opt/homebrew/bin/godot --path /Users/alvachen/Documents/ChatGPT/pawn/.artifacts/first-debt -- --seed=42
```

请选择新游戏进入v29。旧存档继续使用原内容，不会把旧v28及更早局的情节改成新版案情。新自动位为 `auto/first_debt_reckoning`；原六个手动槽共用，测试代码使用 `.godot/qa/v29/` 下的隔离档案。

建议依次看：第十夜只留下旧票 → 第十一夜先把凤镯当货看，展开旧包纸后也可以拒收 → 旧当铺翻纸或托陈家口信 → 库存卖货页问陆掌眼 → 次夜与陈小满核实、看龙镯 → 归还或赔偿 → 第十八夜日结选择继续营业。可故意提前关铺，第二十五夜再补案。

开发回归在该目录执行（所有测试最后都应输出零失败；还需检查是否出现SCRIPT ERROR）：

```sh
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_routes.gd --log-file /private/tmp/fd-routes.log
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_durability.gd --log-file /private/tmp/fd-durable.log
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_story.gd --log-file /private/tmp/fd-story.log
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_process.gd --log-file /private/tmp/fd-process.log
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_edges.gd --log-file /private/tmp/fd-edges.log
/opt/homebrew/bin/godot --headless --path . --script tests/reckoning_coexist.gd --log-file /private/tmp/fd-coexist.log
/opt/homebrew/bin/godot --path . --script tests/reckoning_ui.gd --log-file /private/tmp/fd-ui.log
/opt/homebrew/bin/godot --path . --script tests/reckoning_ui.gd --log-file /private/tmp/fd-ui-wide.log -- wide
```

先跑routes产生真实动作生成的测试档，再跑durability与process；UI也使用routes的档案。分支与长局测试含明确标注的资金夹具；另有默认300银元起步、正常收购出货筹钱的归还和赔偿路线。夹具不改发布数据。

百夜与过去客流稳定性本轮验证；超过4096动作的22秒冷启动数据属于历史v28报告，本轮不沿用为v29测量结果。界面测试不等同于从第一夜起真人完整游玩。自动结果、真实窗口与目视结论分列在 [验收报告](qa/first-debt-v29/REPORT.md)。

## 旧当铺册页（第3版设计）

上面的第十一夜命令仍然适用。进入柜台后，点「账本 → 旧当铺」，或从右上菜单直接进入「旧当铺」。这一阶段只夹有已留下的旧票，不会凭空展示陈家旧记或卖家的包纸。

- 「旧当票／旧凭据／铺中旧物」按实物分类；多张旧当票用上一档、下一档翻阅。
- 直接点击票面读资料；「展开原件」可用滚轮放大查看票面细节。原件右下「返回册页」、右上按钮或Esc均一次返回册页；在册页再按Esc回柜台。
- 随货旧包纸、陈家旧记各自在「旧凭据」中翻阅，不再重复夹在旧票右页；底部「放大细看」「并排查看」入口已移除。
- 「翻查与托话」保留翻旧账背页、托陈家口信及约卖家等当下可办事项；托话仍按按钮所示耗5分钟。
- 打开册页、切换分类、复看和并排阅读免费；首次细读仍原子保存，写盘失败不记发现，提示重试。

册页回归：
```sh
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-ui.log
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-wide.log -- wide
```

截图与单独验收见 [册页报告](qa/old-shop-album/REPORT.md)。已有v29进度可以继续使用；v27及更早仍保留原「旧事」。

## 本轮重点

从第十一夜入口接待卖家，看旧包纸；在旧当铺读铺内存根，托陈家口信。次夜听祖父遗愿、读陈家原票，确认两联均为七夜。可归还或先商量赔偿再交钱。旧凭据页「翻查与托话」可看背页及驻军夹页；看过背页后，到「铺中旧物」主动翻旧《阴账》。结案后再次翻阅才出现清／和。先结案再查背页也能补看。

票据阅读、商量和解不耗时间；核实旧记、采购、归还与付款沿用原5分钟。就算结案，费用和危险仍继续结算。

旧v28资料、测试与报告保持历史身份，不能用旧阶段档载入v29。无任何推送、合并或试玩包。

## 复测排队客人插入问题

用 `--first-debt-preview=chen` 进入第十二夜后，可多做几次鉴货、询问或经营操作，让时刻达到19:20以后再成交或拒收。此时新客已在等候，但必须先看陈小满凤镯对白；成功成交先收好凭据。对白说完再接待下一位，送走新客后陈小满不应再次出现。Esc只收起对白，点击陈小满可重新展开；未作出选择前铃铛不会误送走隐藏的新客。

自动真实窗口复测：`godot --path . --script res://tests/chen_trade_ui.gd -- queued`；大窗口追加 `wide`。

## 陈小满送来原当票之后

交票会谈结束后她回去赶活，次夜再来；当天可继续查资料。抄录在“账本 → 旧当铺 → 旧当票 → 陈家原票 · 瑞字四十七”，需主动展开细读。铺内存根和随货出货凭据也要各读过，可逐档翻阅，核对七夜约定与初五出货日期。只打开册页总览不会自动记录看过。

若之前漏看包纸且仍持凤镯，可在库存中展开旧包纸；看内圈与凤尾后，到库存卖货页找陆掌眼“请他带来看看”，次夜该页可付180银元买龙镯。她离场不妨碍这些经营与阅读。

次夜柜前空闲时与陈小满继续交谈，说明日期和出货记录；持有双镯可归还，也可先谈300银元赔偿、再付款。钱不够可以继续营业，不要求当夜结案。

可另从旧当铺“翻查与托话”看背页支出，再去“铺中旧物”翻旧《阴账》，了解本案与阴账的联系；这不是归还或赔偿的强制条件。

补修验收：`qa/chen-trade-dialogue/DELIVERY_DEPARTURE.md`。
