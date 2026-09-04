# 鬼市当铺

Godot 4.7.2 Standard + GDScript。当前交付为 **M3：库存、买家出售、活当与账本**，尚非完整三夜经营P0。

## 启动

1. 使用 Godot 4.7.2 Standard 导入本目录的 `project.godot`。
2. 按 F5 运行项目，直接进入固定柜台2D场景。
3. 在「营业」页点击「开铺」，顾客出现后去「对话」「鉴定」「交易」页接待。单纯查看面板不耗时。
4. 正式询问、检查、报价、施压、拒客均耗时。营业页等待也会影响柜台及排队顾客。可随时关门，但本夜不能重开，顾客交易机会随之结束。
5. 「等到封铺」消耗全部剩余时间；03:00进入夜间结算。点击结算后生成日结并自动保存。
6. 日结后进入下一夜；第3夜结束本轮。新游戏/读取存档在「营业」页，均需确认。

## M3建议试玩路径

1. 开铺后先问第一位顾客“有没有修补过”，再依次观察器型、查看底足、侧光检查釉面。证据估值应收窄到18–25。
2. 记录自己的判断；到交易页用补釉接缝证据施压，把报价输入改为18后提交。现银应由100变成82，库存与账本各出现一条记录。
3. 去库存接受「杂货回收商」的12报价：现银变为94，已实现亏损6。另开一局按18收购同样物品，等到19:00后卖给「瓷器收藏客」可得24、盈利6。买家各有偏好、窗口和每夜1件额度；重复查看免费，正式交货耗时10分钟。
4. 另开新游戏，不鉴定就把第一件货判断为完好品并报价60：现金会真实扣除。随后卖给回收商只得12，最终已实现亏损48。收购占款不等于亏损，出售时才确认成本。
5. 连续提交过低报价，或拿无关线索施压，观察有限轮次和不耐烦反馈；已离场的顾客不能再成交。
6. 故意等待90分钟，观察排队客超时离场。关门后仍可做店内占位行动，但不能交易。
7. 夜末日结后进第二夜，再收一件后读取存档：应恢复到第二夜开铺前的现金、库存及流水。继续三夜可到本轮结束。

长面板可滚动，报价输入框可以修改。鉴定、询问和证据施压不可重复刷信息。精确底价、精确耐心和未揭露真实变体不显示给玩家。

### 活当、赎回与绝当测试

- 新游戏，开铺后到交易页，在第二个输入框填写活当放款27，点击「正式报价并活当」。现金73，当票本金27，赎金33，第2夜到期。在当物品不可出售；收购与活当共用议价轮次和耐心。
- 关门 → 等到封铺 → 结算 → 下一夜 → 开铺 → 账本。第2夜18:00–20:00内点击「收赎金33并交还原物」，现金106、利息利润6；到20:00才办完则错过窗口。
- 未赎绝当：新游戏拒绝第一客（5分钟），在营业页整理桌面10分钟，第二客出现后活当报价20。跨到第2夜夜末，未返店的当票自动转现货，现金不变；第3夜可到库存出售。
- 当票列表和流水可以滚动。这里的「绝当」是当票到期转现货，不是玩家死亡。到第3夜结束仍未到期的当票保留在当，不提前强制绝当。
- 一次续当接口有自动测试夹具；当前两类正式测试当约分别为返店赎回和未返店，不主动提供续当内容。

本阶段使用2件普通物品定义、2个普通顾客模板、2个买家、2种当约，每夜4个来访槽；三个夜晚复用同一测试编排。8件普通物品、4种顾客、正式三夜差异内容和EventDirector留至M4；鬼货与异常留至M5。尚不代表30–50分钟完整P0体验。

## 存档

夜末结算、进入下一夜及结束运行时保存检查点。不支持夜内即时保存；退出会丢失本夜未保存进度。
启动默认展示新运行，可主动点击「读取夜末存档」。新游戏不会立即删除旧档，但新运行首次日结将覆盖它。

默认路径：`user://p0/autosave.json`，Windows通常为 `%APPDATA%/Godot/app_userdata/鬼市当铺/p0/autosave.json`。
测试使用独立 `user://tests/` 文件，不读写玩家存档。
损坏或版本不匹配时保留旧文件并报错；写入失败不推进结算/夜次，修复磁盘问题后可以重试。
M3使用 `save_version=3` / `content_version=4`，不自动迁移M1/M2存档。升级后请先关闭旧试玩窗口，再重新启动并新游戏；旧文件在读取失败时保留，新运行首次夜末保存会覆盖旧检查点。仅支持单个试玩窗口写档。

## 自动验证

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --editor --quit --path .
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_all.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/checkpoint_process.gd -- write
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/checkpoint_process.gd -- read
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/ui_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/m2_checkpoint_process.gd -- write
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/m2_checkpoint_process.gd -- read
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/m2_ui_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/m3_ui_smoke.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/m3_checkpoint_process.gd -- write
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/m3_checkpoint_process.gd -- redeem
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/m3_checkpoint_process.gd -- read
```

UI脚本打开真实渲染窗口，以视口鼠标输入和报价控件输入执行三夜回归，截图输出到被忽略的 `.godot/qa/`。
还可用 `--headless` 跑UI输入回归（不输出截图）。首次拉取后先运行上面的编辑器导入，以生成全局类缓存。

M3验收后再进入M4，不自动推进。架构和验收记录见 `docs/TECH_ARCH.md`、`docs/P0_STATUS.md`。
