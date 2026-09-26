# 周怀安筹药费 · 独立试玩 v47

> 本页记录独立试玩的开发验收。2026-09-26基于最新main的发布整合及回归结果见 [SPECIAL_GUESTS_RELEASE.md](SPECIAL_GUESTS_RELEASE.md)。
2026-09-26，本地开发与验收；尚未发布。基于现有特殊客v46工作目录，保留原有未提交修改、旧入口与存档。

## 玩家体验

- 药费客固定名为周怀安，是活人；使用独立药单立绘。第3、9、18、19夜到访。第3夜19:30，后续在19:30—21:30之间安排独立预约位置，避免已排来客；赎当造成的普通客延迟仍适用。
- 每次按本局种子，从普通客当前货池抽取普通货与其品相。没有预设四件货的总价值；不会放入剧情鬼货或富客专属高档货。允许普通鉴定与议价，只做卖断。
- 四次实际成交付款累计为药费，目标200银元。拒收、未接待、议价未成交均不增加药费，也不取消后续固定到访。普通停业或错过当次接待不补一笔虚构收入。
- 第19夜未筹齐时，首次开价等于剩余缺口，人物明确恳求帮助，愿来世做牛做马报恩。仍可压价；底价沿用该客开价70%的规则，正常证据、议价可继续作用。支付金额按实际累计。
- 提前筹齐：余下约定到访改为报平安，不再卖货求钱。第20夜开铺前由周怀安本人登门道谢，说明母亲用药后病情转稳。
- 至第19夜结束不足200：第20夜开铺前由周婶串门聊家常，提起他母亲去世。周怀安本人不来报丧，柜前无交易货物。
- 介绍、恳求与结局使用原有立绘、柜台和底部RPG分页对话；累计已得与缺口也写入成交回应。听完对话才继续操作，已听过的段落读档不重复提交。

## 存档与版本

新内容版本47、运行ID `medicine_huaian_v47`；存档库 `user://medicine_huaian_v47/library.json`，回退档 `user://medicine_huaian_v47/autosave_v47.json`。药费直接从已提交的收购账目计算，物品出售、转出不撤回给他的药钱。预约使用已有经营扩展结构、已听与结局使用叙事标记，全部纳入操作回放校验。

沿用主线的续夜机制，原18夜基础配置后可继续至第19、20夜；此入口的“结束试玩”需第20夜结算后才可使用。旧v44/v45/v46入口、内容定义及存档保持原规则，不迁移旧药费客历史。

## 启动与快速预览

完整新局：

```powershell
& "D:\CodexData\runs\pawnbroker-special-guests\play-medicine-huaian.cmd"
```

第19夜最后恳求（预置此前已得160，开价40）：

```powershell
& "D:\CodexData\runs\pawnbroker-special-guests\play-medicine-huaian.cmd" -Stage final -Wide
```

周婶带来坏消息：

```powershell
& "D:\CodexData\runs\pawnbroker-special-guests\play-medicine-huaian.cmd" -Stage bereaved -Wide
```

其他预置：`first`首次见面、`report`提前筹齐后报平安、`saved`第20夜好结局。预置独立运行，不保存，不用作可回放正式存档。默认1280×720，`-Wide`为1600×900。

## 本次验收

- `tests/medicine_huaian_v47.gd`：1870项通过。32组种子、普通货池、四次预约保护与读取稳定；五条完整20夜分支（提前筹齐、200临界值、199、全部拒收、分次付清）；阶段及结局冷回放、写盘失败回滚、存档库真实读回、伪造已听结局被拒绝。
- `tests/medicine_huaian_ui.gd`：实际1280×720、1600×900各42项通过。已人工查看首次见面、末夜恳求及周婶结局截图，人物淡入完成后取图，文字与继续按钮不重叠，最后开价正确且可进入普通交易。
- 旧入口回归：v46特殊客1252项通过，v45湿包持货364项通过。
- Godot资源导入、脚本检查与`git diff --check`通过。Windows PowerShell实际预览启动器另有启动日志。
- 规则与UI日志：`.godot/qa/special-guests/v47-*.log`；截图：`.godot/qa/medicine-huaian/{1280,1600}_{first,final,plea,final_trade,report,saved,bereaved}.png`。

## 新立绘来源

使用内置image_gen，参考项目现有 `assets/art04/customers/special/mirror_medicine.png`，保留人物面貌，替换为攥药单的动作。新资源 `assets/art04/customers/special/zhou_huaian_v47.png`，保留生成的原生透明通道，旧立绘未覆盖。生成原件：`C:/Users/alvachen/.codex/generated_images/01a0d7a3-193f-7402-a3a8-a8c8843fe94d/exec-d266f96f-7ba3-4bf7-bd89-7cd89733dd2c.png`。

最终生成提示词：

> Edit this referenced game character into his definitive named portrait Zhou Huaian, an impoverished young adult Chinese man caring for his sick mother, 1930s Shanghai pawnshop. Preserve recognizable face, credible anatomy and coarse muted brown-grey patched jacket; improve identity: tired worried eyes with earnest dignity, slightly hunched shoulders. Replace cloth bundle with a crumpled folded traditional pharmacy prescription held visibly against lower chest in one hand, other hand slightly extended pleading. No legible text required on paper. Hand painted semi-realistic opaque gouache, restrained irregular brush texture, matte old-print realism, subdued brown grey palette, no glossy cinematic or anime style. One isolated standing character from head to upper thighs with full hands, centered in portrait canvas, margins above hair and either side. Warm gentle front-left light consistent with pawnshop counter. TRUE TRANSPARENT ALPHA BACKGROUND, no magenta, no scene, no props except medicine prescription, no lettering. Production game sprite, preserve edge transparency. His expression anxious but not melodramatic. Do not add any other person.
