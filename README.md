# 鬼市当铺

**珍珠试玩入口：`play-pearl-v38.cmd -Stage pearl -Wide`，正式新局可用 `play-unified.cmd` 或 Godot 项目入口。** 默认版本为 v39 `first_debt_unified`，加入第一账、龙镯追查与第十八夜后继续营业，并保留v38的珍珠逐粒查验、整串谈价，以及五位富客按权重携带十种高档货。实际货值在生成时固定，手记、对客说法与客人认识各自保存。详见 [v38试玩与验收](docs/PEARL_V38_LOCAL.md)。

本次第一账发布基于线上 main `0e2fb42` 隔离整合。v38与第一账旧v31存档保持原运行。v37与更早存档保留原规则；原v37独立场景为 `scenes/start_named_wealthy_v37.tscn`。历史折扇与铜镜入口继续保留。

线上原有命灯版及夜客规则保留独立内容与存档。需要新开命灯版时运行 `godot --path . res://scenes/life_lamp_start.tscn`；读取已有命灯存档仍按原规则继续。

当前规格与待确认分歧统一见 [当前开发规格](docs/CURRENT_SPEC.md)。默认v39保留线上v23已整合的职业赎回、生计背景与寝屋铜镜反馈；原v21夜客和阿七七夜版使用各自冻结规则。第七夜阿七收尾后不额外叠加墙镜异象。

新增商品与行家复核版作为独立七夜入口保留，包含银戒指、银锁、折扇、茶盏及验配出售；启动方式见 [商品与行家说明](docs/GOODS_EXPERTISE.md)。库存详情统一精简为已知品相要点。

旧版本内容与存档保留原规则，v19经营整合、v20职业赎回和v21商品复核成果继续包含在新局中。换物不改变原票本金、赎金、期限或原主赎回概率；两类阴客与通用辨生死在对应v22、v23及新默认v39中生效。

固定柜台式 2D 当铺经营与规则恐怖游戏。当前流程整合第一账、开放延续、开场、随机经营、铜镜遭遇与寝屋，每夜六位基础潜在来客，保留限时钢笔收货及三夜活当回访。原三夜、四夜和七夜经营版本继续作为旧存档入口。第21/49夜还本系统仍属后续范围。

批量卖货需先选买家、再勾选货物，一趟20分钟、不限量；店里有客须先接待。七夜新版从第一夜开放陆掌眼动态行情，与既有预约收货共同运作；旧版本继续按各自原规则，见 [卖货机制说明](docs/SELLING_MARKET_GUIDE.md)。

普通交易增加了议价说辞、完整证据反馈与一次性贬低试探，详见 [议价说明与测试入口](docs/BARGAINING_GUIDE.md)。

普通交易不再弹出限时交割提示，直接更新账目并继续接待；下方结果条目保留署名客户回复，区分满意成交、不甘心成交、拒绝成交离开、超时离开、被拒收离开，不按计时自动消失。首单手动盖章保留；最近结果可收起，详细凭据仍可主动复查。当前规格见 [客户回复](docs/CUSTOMER_REPLIES.md)。

当前规则、实现状态和规格冲突见 [当前开发规格](docs/CURRENT_SPEC.md)；[V0.6专项计划](docs/V06_NEXT_STEPS_PROPOSAL.md)保留已确认历史方案，不作为当前进度或自动开工清单。活当流程和验证见 [活当交付记录](docs/PAWN_RETURN_GUIDE.md)，房间阶段历史见 [房间交付记录](docs/V06_ROOM_GUIDE.md)。每阶段交付改动说明、必要截图和验证结果，负责人评审后进入下一阶段；仅在明确要求时制作试玩包。

四夜样板启动、六类取舍与兼容规则见 [四夜样板说明](docs/FOUR_NIGHT_SAMPLE.md)。仅交付本地源码与草图。

## 启动与操作

技术基线为 Godot 4.6.1 Standard，Windows x86_64 / Compatibility。

```powershell
.\play-unified.cmd
# v37怀表快速试玩（隔离测试预置，进度不保存）
.\play-unified.cmd -Stage watch -Wide
.\play-unified.cmd -Stage wealthy-basic -Item gold_watch
.\play-unified.cmd -Stage wealthy
.\play-unified.cmd -Stage wealthy-deep -Item porcelain_vase -Wide
# 历史v31宣传回归场景（生成并校验真实进度）
.\play-unified.cmd -Stage advertisement
# 保留的v30整合回归场景
.\play-unified.cmd -Stage introduction
.\play-unified.cmd -Stage fan -Wide
.\play-unified.cmd -Stage companion
.\play-unified.cmd -Stage reunion
```

macOS 在仓库目录运行 `godot --path .`；复现同一局用 `godot --path . -- --seed=42`。或导入本目录的 project.godot 后按 F5。ZIP 完整解压后双击 Pawnshop.exe，同目录保留 Pawnshop.pck，无需安装 Godot。

源码启动先进入雨夜当铺主画面，可开启新游戏、读取进度或离开游戏。三枚木牌平时为暗木色，鼠标移入渐显暗红，移开后恢复；无存档时读取按钮不可用。接入与验证见 [主画面交付记录](docs/MAIN_MENU.md)。已有试玩包未随这次源码修改重新生成。

查看面板和现实思考不耗时。正式动作推进18:00–03:00，顾客会等待和离店。点击左上铺面招牌打开营业，客人对应对话/交易，货物对应鉴定；左侧库存柜和桌上账本可直接打开对应功能。右下角信封查看陆掌眼货单；右上角菜单图标分本局/铺务。

夜末流程：**封铺→合账（当票到期、息费）→铺内应对→第七夜阿七与阴账收尾→回房→床确认就寝→个人应对→天明日结**。回房后不能经营。无待办且未到末夜时，「放松入眠」完成后直接进入次日，末夜保留摘要。寝屋已采用紧凑衣柜版美术，命灯、旧信、照片、床和日常观察已接入；墙镜使用独立组件，保留线上版本的铜镜追看反馈与命灯联动，第七夜阿七收尾后的寝屋保持安静。见 [寝屋美术](docs/BEDROOM_ART.md)与[镜面边界](docs/BEDROOM_MIRROR.md)。

活当：到期原主在开铺时优先持票回访，柜台验票后收赎金、交还原物；回访办完再迎新客。到期无人来赎的当票，夜末逐张选“撕票留货”或“折价转给同行”，确认后统一合账。转当连同原物交出，按本金八折向下取整（最低1银元）；留货不进现金。详见 [活当交付记录](docs/PAWN_RETURN_GUIDE.md)。

## 当前经营与兼容边界

普通时段等权抽取8类人物，再从适配携物池抽物品与品相；允许同模板、同物品重复，当户姓名本局不重名。观察、两项专属检查、口供追问与来源核验各自记录；同一缺陷不能重复折价，可以少查、直接报价或拒收。读档与打开面板不重抽。钟表修理匠耐心为1，一次失败报价即可离场。

先询问来源，再在柜台免费核对凭据与原物，耗时5分钟。铺中自有现货可委托一次来源调查，费用2银元、耗时10分钟，可能查无实据。来源已证实且买家认可时，出售增加基础报价15%的溢价，向下取整；调查费单列经营费用，不改变入手成本或活当金额。实现、配置与验证详见 [普通交易交付记录](docs/ORDINARY_V10_GUIDE.md)。

新版铜镜每次5分钟辨认柜前客户生死，不限次数；照客与镜中旧事分开。现实证据齐备后可托人核查丈夫离家后的经历，回报读毕可约下夜20:00会面，再进入正式镜前对质。丈夫来访时为活人；四种结局已经实现：三种女子离去结局停用铜镜能力，报复结局使丈夫死亡、女子留镜，并获得铜镜怨气。重要情报奖励、怨气用途和换物补救仍待开发。

当前新版新开局现金300银元、借据本金500；现阶段每日利息5、铺费5，本金不变，不复利。先补旧息费短款，再付当夜费用；短款只宽限到次夜夜末。费用先入账，睡眠结束后判经营失败；若同夜危机死亡，只入《绝当录》，不再入《破铺录》。第三夜短款保留真实第四夜期限，不宣称债务结清。

当前基础普通职业模板为8类，v31新增4类有钱客人与1类超有钱客人，按商誉替换普通客位；统一局另有夜客、熟客、剧情与军方特殊来访，棉袄保留在普通货位。三夜原型保留铜镜、原买家和短当约；四夜样板新增有限收货预约与三夜当约，不调度鬼货或主线事件。正式12图需求保留在 [美术交接](docs/M7_ART_HANDOFF.md)。完整鬼市、七笔阴账、49夜剧情和更多行情链仍属后续范围。

## 存档

默认新局使用 **save_version=39 / content_version=39**，自动位置为 `auto/first_debt_unified`，位于既有档案库 `user://save_library/library_v1.json`；独立路径为 `user://first_debt_unified/autosave_v39.json`。旧v31 `wealthy_ten`、v30 `unified_ten` 和更早存档继续按各自规则运行，不补抽破损、不追收器材、不改写原当票。命灯受害仍自动保存，营业中不能手动随时保存。

旧三夜局使用v12，独立路径为 `user://p0/autosave_v12.json`。独立四夜样板仍用v11，保存于 `user://ordinary_four/autosave_v11.json`。三夜入口可导入通过完整历史校验的旧v9/v10/v11局，原文件保留；旧局继续使用对应旧内容，重新开局才进入v12。旧v10分别保留实施前测试快照和已上线版本的配置，包含两种历史现金/债务组合。

- 源码/编辑器：`%APPDATA%/Godot/app_userdata/鬼市当铺/p0/autosave_v12.json`，四夜样板使用相邻的 `ordinary_four/autosave_v11.json`
- 已有旧Windows包仍使用其原版本存档；本次没有重新打包。
- 包日志：`%APPDATA%/GhostMarketPawnshop-M8A/logs/godot.log`

包与编辑器目录独立，不自动复制。启动后从菜单读取。封铺结算、每次应对、回房、就寝、日结、进入下一夜与收尾均原子保存；统一局的成长、鉴定与人情变化也会即时原子保存；旧局维持各自保存边界。写盘失败回滚，重复提交不重复收费或归档；损坏的历史账册阻止覆盖。只支持单窗口写档。

同目录旧 autosave_v7.json 原样保留，只导入经过校验的绝当录/破铺录，不迁移旧局进度。不自动跨越v7导入更早进度。历史M7测试使用独立内容夹具；旧版本兼容保留原有账目校验。

## Windows构建与验证

准备官方4.6.1编辑器 ZIP 和模板 TPZ 后：

```powershell
./tools/build_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe
./tools/smoke_windows_package.ps1 -ZipPath ./dist/<构建ID>/Pawnshop-V06-Pawn.1-windows-x86_64.zip
```

产物在 dist/<构建ID>/，日志在 .artifacts/m8a/<构建ID>/。构建没有跳过测试开关：检查固定工具与许可哈希、全部源回归、干净暂存导出、PCK审计，然后生成ZIP/SHA256。原始OFL包含一处行尾空格，按官方字节保留，不应用通用去空格格式化。

正式包启动检查在非管理员身份、工程外中文与空格目录运行；它不能替代完整 EXE 试玩。具体步骤见 [Windows构建指南](docs/WINDOWS_BUILD.md)。

单独验证房间（测试使用隔离的user://tests路径；Windows完整门禁还隔离APPDATA）：

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_all.gd
godot --headless --path . --script res://tests/run_room.gd
godot --path . --script res://tests/room_ui_smoke.gd
godot --path . --script res://tests/room_ui_smoke.gd -- wide
foreach ($mode in @('write_room','sleep','summary','read_summary','write_shop','read_shop','write_pursuit','pursuit_sleep','death','read_death')) {
    godot --headless --path . --script res://tests/room_checkpoint_process.gd -- $mode
}
```

M0–M7及原房间回归保留历史夹具/v9内容；`tests/run_variety.gd` 检查当前生产Manifest。统一验证使用 `tools/test_windows.ps1`，包含新旧领域、跨进程和1280×720/1600×900真实窗口；只运行验证不会制作试玩包。截图保留在 .godot/qa/。不同电脑、DPI、正式EXE完整玩法和七夜90–150分钟体验目标仍待后续实际验证。

## 开发资料

- [当前开发规格](docs/CURRENT_SPEC.md)：当前默认版本的规则、实现边界、证据与待确认分歧。
- [GDD V0.9](鬼市当铺_GDD_V0.9.docx)：全局设计与正史；当前实现差异见上述规格，不按版本号推定所有规则已统一。
- docs/V06_NEXT_STEPS_PROPOSAL.md、docs/V06_ROOM_GUIDE.md：已确认历史计划及房间阶段记录。
- docs/PLAYER_COPY_GUIDE.md：玩家文案规范。
- docs/M6_DEBT_MIRROR_GUIDE.md、docs/M7_JUDGEMENT_GUIDE.md：前阶段玩法实现。
- docs/TECH_ARCH.md、docs/DECISIONS.md、docs/P0_STATUS.md：架构和历史决策。


## 七夜普通经营 v13

独立七夜入口、准备行动与限时钢笔收货链已加入本工作树。启动方式、随机种子及试玩重点见 [七夜说明](docs/SEVEN_NIGHT_BUSINESS.md)，本轮检查见 [验证记录](docs/SEVEN_NIGHT_VALIDATION.md)。

## 七夜整合与开铺准备

运行与验收说明见 [开铺准备](docs/OPENING_PREPARATION.md) 和 [七夜整合](docs/INTEGRATED_SEVEN.md)。

默认新版已整合陆掌眼七夜动态收货、熟客故事与提前赎当。右下角信封可直接查看陆掌眼货单，菜单位于右上角；版本17卖货测试局及原熟客版本定义保留。经营规则与验证见 [七夜销路整合](docs/MARKET_SEVEN.md)。


### 铜镜人物与告别演出（本地打磨）

统一夫妻水粉立绘、六种人物状态与四幅结局插画，保留现有规则和存档。隔离测试完整启动命令、四路线与操作说明见 [铜镜演出试玩](docs/MIRROR_PERFORMANCE.md)，检查及截图见 [验收记录](docs/qa/mirror-performance/REPORT.md)。本批未推送或合并。

## 第一账整合发布

整合第一账、龙镯追查、陈小满预约与归还收尾，同时保留v38富客、钟表与珍珠鉴定。默认新游戏使用v39；历史运行按原manifest恢复。第一账开发详情见`docs/FIRST_DEBT_V31.md`，整合验证见`docs/qa/first-debt-release/REPORT.md`。
