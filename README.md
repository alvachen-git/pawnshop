# 鬼市当铺

固定柜台式 2D 当铺经营与规则恐怖游戏。当前为 **V06-Room.1 三夜内部原型**，默认 `p0_room`：保留识货与识人、每日息费、铜镜窥探与两种终局，补齐寝屋和分段风险。当前尚未制作七夜 Demo 或第21/49夜还本系统。

当前计划见 [V0.6开发计划](docs/V06_NEXT_STEPS_PROPOSAL.md)，房间流程和验证见 [房间交付记录](docs/V06_ROOM_GUIDE.md)，独立成交页见 [交互验证](docs/trade_receipt/design-qa.md)。负责人已确认本地测试通过，并授权本次源码推送、合并到 main。后续默认不制作试玩包；正式美术保持待规划，公开发布另行确认。

## 启动与操作

技术基线为 Godot 4.6.1 Standard，Windows x86_64 / Compatibility。

```powershell
& ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64.exe --path .
```

或导入本目录的 project.godot 后按 F5。ZIP 完整解压后双击 Pawnshop.exe，同目录保留 Pawnshop.pck，无需安装 Godot。

查看面板和现实思考不耗时。正式动作推进18:00–03:00，顾客会等待和离店。点击左上铺面招牌打开营业，客人对应对话/交易，货物对应鉴定；左侧库存柜和桌上账本可直接打开对应功能。右下角菜单分本局/铺务。

夜末流程：**封铺→合账（当票到期、息费）→铺内应对→回房→床确认就寝→个人应对→天明日结**。无危机时直接继续相应步骤。回房后不能经营。寝屋左侧命灯、书桌可免费反复查看，中间床负责就寝；右侧镜面只是位置预留。寝屋为程序绘制的低保真背景，尚无新音效或最终资产。

## 三夜内容与经济边界

第一夜青花碗检查口供与接缝，铜烛台通过磁针/旧划痕判断材质；第二夜怀表分别判断品相与赶船处境。证据不能重复折价，可以提早成交和自由报价。同一运行保存品相、情境与反应，读档不重抽。

第三夜仍保留铜镜试验：初窥可提供故障怀表证据，继续追看旧当票会留下个人纠缠。覆镜处理铺内存放，覆镜或出售不会消除追看后果；铺内与个人危机分开应对。这是三夜测试路线，七夜 Demo 将遵循第6夜入镜、第7夜有限提示的慢热节奏，关闭这条致命追看分支。

初始现金100银元、借据本金300；现阶段每日利息3、铺费5，本金不变，不复利。先补旧息费短款，再付当夜费用；短款只宽限到次夜夜末。费用先入账，睡眠结束后判经营失败；若同夜危机死亡，只入《绝当录》，不再入《破铺录》。第三夜短款保留真实第四夜期限，不宣称债务结清。

当前有8种普通物品、1件铜镜、4类顾客、4名买家、2种当约、7个普通事件和1段铜镜遭遇。正式12图需求保留在 [美术交接](docs/M7_ART_HANDOFF.md)。完整鬼市、七笔阴账、49夜剧情、准备行动和行情链仍属后续范围。

## 存档

当前 **save_version=8 / content_version=9**，默认 `user://p0/autosave_v8.json`。

- Windows包：`%APPDATA%/GhostMarketPawnshop-M8A/p0/autosave_v8.json`
- 编辑器：`%APPDATA%/Godot/app_userdata/鬼市当铺/p0/autosave_v8.json`
- 包日志：`%APPDATA%/GhostMarketPawnshop-M8A/logs/godot.log`

包与编辑器目录独立，不自动复制。启动后从菜单读取。封铺结算、每次应对、回房、就寝、日结、进入下一夜与收尾均原子保存；营业中交易不即时保存。写盘失败回滚，重复提交不重复收费或归档；损坏的历史账册阻止覆盖。只支持单窗口写档。

同目录旧 autosave_v7.json 原样保留，只导入经过校验的绝当录/破铺录，不迁移旧局进度。不自动跨越v7导入更早进度。历史M7测试使用独立内容夹具和v7规则。

## Windows构建与验证

准备官方4.6.1编辑器 ZIP 和模板 TPZ 后：

```powershell
./tools/build_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe
./tools/smoke_windows_package.ps1 -ZipPath ./dist/<构建ID>/Pawnshop-V06-Room.1-windows-x86_64.zip
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

M0–M7回归保留历史夹具。房间测试直接使用当前生产Manifest；真实窗口测试通过视口鼠标事件完成三夜和危机操作，截图保留在 .godot/qa/。不同电脑、DPI、正式EXE完整玩法和七夜90–150分钟体验目标仍待后续实际验证。

## 开发资料

- 鬼市当铺_GDD_V0.6.docx：当前设计输入，以任务中最终确认的计划解决版本冲突。
- docs/V06_NEXT_STEPS_PROPOSAL.md、docs/V06_ROOM_GUIDE.md：已确认任务拆解、当前交付。
- docs/PLAYER_COPY_GUIDE.md：玩家文案规范。
- docs/M6_DEBT_MIRROR_GUIDE.md、docs/M7_JUDGEMENT_GUIDE.md：前阶段玩法实现。
- docs/TECH_ARCH.md、docs/DECISIONS.md、docs/P0_STATUS.md：架构和历史决策。
