# 鬼市当铺


默认三夜版已接入 **v12批量卖货与陆掌眼行情**：库存中先选买家、再勾选货物，一趟20分钟、不限量；店里有客须先接待。陆掌眼只收当前口信所指品类，按真值140%报价。新开一局即可体验，旧进度继续原规则。操作与兼容说明见 [卖货机制说明](docs/SELLING_MARKET_GUIDE.md)。

固定柜台式 2D 当铺经营与规则恐怖游戏。当前整合版默认使用v12卖货内容，保留v11四夜样板：默认 `p0_variety` 保留三夜原型，新增独立 `ordinary_four` 四夜普通经营样板。支持八类随机人物、专属鉴定、来源核验、证据议价、一次性贬低、原主回访与寝屋流程。尚未制作七夜 Demo 或第21/49夜还本系统。

普通交易增加了议价说辞、完整证据反馈与一次性贬低试探，详见 [议价说明与测试入口](docs/BARGAINING_GUIDE.md)。

当前计划见 [V0.6开发计划](docs/V06_NEXT_STEPS_PROPOSAL.md)，当前活当流程和验证见 [活当交付记录](docs/PAWN_RETURN_GUIDE.md)，房间阶段历史见 [房间交付记录](docs/V06_ROOM_GUIDE.md)。每阶段交付改动说明、必要截图和验证结果，负责人评审后进入下一阶段；仅在明确要求时制作试玩包。

四夜样板启动、六类取舍与兼容规则见 [四夜样板说明](docs/FOUR_NIGHT_SAMPLE.md)。仅交付本地源码与草图。

## 启动与操作

技术基线为 Godot 4.6.1 Standard，Windows x86_64 / Compatibility。

```powershell
& ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64.exe --path .
```

或导入本目录的 project.godot 后按 F5。ZIP 完整解压后双击 Pawnshop.exe，同目录保留 Pawnshop.pck，无需安装 Godot。

源码启动先进入雨夜当铺主画面，可开启新游戏、读取进度或离开游戏。三枚木牌平时为暗木色，鼠标移入渐显暗红，移开后恢复；无存档时读取按钮不可用。接入与验证见 [主画面交付记录](docs/MAIN_MENU.md)。已有试玩包未随这次源码修改重新生成。

查看面板和现实思考不耗时。正式动作推进18:00–03:00，顾客会等待和离店。点击左上铺面招牌打开营业，客人对应对话/交易，货物对应鉴定；左侧库存柜和桌上账本可直接打开对应功能。右下角菜单分本局/铺务。

夜末流程：**封铺→合账（当票到期、息费）→铺内应对→回房→床确认就寝→个人应对→天明日结**。无危机时直接继续相应步骤。回房后不能经营。寝屋左侧命灯、书桌可免费反复查看，中间床负责就寝；右侧镜面只是位置预留。寝屋为程序绘制的低保真背景，尚无新音效或最终资产。

活当：到期原主在开铺时优先持票回访，柜台验票后收赎金、交还原物；回访办完再迎新客。到期无人来赎的当票，夜末逐张选“撕票留货”或“折价转给同行”，确认后统一合账。转当连同原物交出，按本金八折向下取整（最低1银元）；留货不进现金。详见 [活当交付记录](docs/PAWN_RETURN_GUIDE.md)。

## 三夜内容与经济边界

普通时段等权抽取8类人物，再从适配携物池抽物品与品相；允许同模板、同物品重复，当户姓名本局不重名。观察、两项专属检查、口供追问与来源核验各自记录；同一缺陷不能重复折价，可以少查、直接报价或拒收。读档与打开面板不重抽。钟表修理匠耐心为1，一次失败报价即可离场。

先询问来源，再在柜台免费核对凭据与原物，耗时5分钟。铺中自有现货可委托一次来源调查，费用2银元、耗时10分钟，可能查无实据。来源已证实且买家认可时，出售增加基础报价15%的溢价，向下取整；调查费单列经营费用，不改变入手成本或活当金额。实现、配置与验证详见 [普通交易交付记录](docs/ORDINARY_V10_GUIDE.md)。

第三夜仍保留铜镜试验：初窥可提供故障怀表证据，继续追看旧当票会留下个人纠缠。覆镜处理铺内存放，覆镜或出售不会消除追看后果；铺内与个人危机分开应对。这是三夜测试路线，七夜 Demo 将遵循第6夜入镜、第7夜有限提示的慢热节奏，关闭这条致命追看分支。

当前新版新开局现金300银元、借据本金500；现阶段每日利息5、铺费5，本金不变，不复利。先补旧息费短款，再付当夜费用；短款只宽限到次夜夜末。费用先入账，睡眠结束后判经营失败；若同夜危机死亡，只入《绝当录》，不再入《破铺录》。第三夜短款保留真实第四夜期限，不宣称债务结清。

当前有8种普通物品、8类顾客。三夜原型保留铜镜、原买家和短当约；四夜样板新增有限收货预约与三夜当约，不调度鬼货或主线事件。正式12图需求保留在 [美术交接](docs/M7_ART_HANDOFF.md)。完整鬼市、七笔阴账、49夜剧情、准备行动和更完整的行情链仍属后续范围。

## 存档

默认三夜新局使用 **save_version=12 / content_version=12**，保存于 `user://p0/autosave_v12.json`。独立四夜样板仍用v11，保存于 `user://ordinary_four/autosave_v11.json`。三夜入口可导入通过完整历史校验的旧v9/v10/v11局，原文件保留；旧局继续使用对应旧内容，重新开局才进入v12。旧v10分别保留实施前测试快照和已上线版本的配置，包含两种历史现金/债务组合。

- 源码/编辑器：`%APPDATA%/Godot/app_userdata/鬼市当铺/p0/autosave_v12.json`，四夜样板使用相邻的 `ordinary_four/autosave_v11.json`
- 已有旧Windows包仍使用其原版本存档；本次没有重新打包。
- 包日志：`%APPDATA%/GhostMarketPawnshop-M8A/logs/godot.log`

包与编辑器目录独立，不自动复制。启动后从菜单读取。封铺结算、每次应对、回房、就寝、日结、进入下一夜与收尾均原子保存；营业中交易不即时保存。写盘失败回滚，重复提交不重复收费或归档；损坏的历史账册阻止覆盖。只支持单窗口写档。

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

- 鬼市当铺_GDD_V0.6.docx：当前设计输入，以任务中最终确认的计划解决版本冲突。
- docs/V06_NEXT_STEPS_PROPOSAL.md、docs/V06_ROOM_GUIDE.md：已确认任务拆解、当前交付。
- docs/PLAYER_COPY_GUIDE.md：玩家文案规范。
- docs/M6_DEBT_MIRROR_GUIDE.md、docs/M7_JUDGEMENT_GUIDE.md：前阶段玩法实现。
- docs/TECH_ARCH.md、docs/DECISIONS.md、docs/P0_STATUS.md：架构和历史决策。
