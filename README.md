# 鬼市当铺

固定柜台式2D经营与规则恐怖游戏。当前玩法为 M7 **识货与识人**，默认运行 `p0_judgement`：青花碗、铜烛台与怀表采用不同检查、追问和议价路径，保留每日息费、《破铺录》及铜镜窥探。M7 三夜试玩于2026-09-04通过负责人测试；当前 M8-A 仅做本地 Windows 内测包，不代表获得上传、Release 或新一轮推送授权。

## Windows 内测包与构建（M8-A）

统一技术基线为 **Godot 4.6.1 Standard**，Windows x86_64 / Compatibility。ZIP 完整解压后双击 `Pawnshop.exe`，同目录保留 `Pawnshop.pck`，无需安装 Godot。包内 `PLAYTEST_WINDOWS.txt` 为中文试玩说明，`BUILD_INFO.json` 记录构建状态，`licenses` 包含原始第三方许可；包旁 `.sha256` 用于校验。

Windows 本地构建入口（先从官方归档准备同版本编辑器 ZIP 和模板 TPZ）：

```powershell
./tools/build_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe
```

可用 `-EditorArchive`、`-TemplatesArchive` 指定归档位置。默认缓存为 `.tools/downloads/`，产物为 `dist/<独立构建ID>/Pawnshop-M8A.1-windows-x86_64.zip`，完整日志位于 `.artifacts/m8a/<构建ID>/`。构建命令默认执行全部源工程回归、干净暂存工程导出和 PCK 资源审计，失败即停止。分段下载辅助脚本需要 PowerShell 7。

实际包启动检查：

```powershell
./tools/smoke_windows_package.ps1 -ZipPath ./dist/<构建ID>/Pawnshop-M8A.1-windows-x86_64.zip
```

它将 ZIP 解压到工程之外、含中文与空格的临时目录，用非管理员身份启动 EXE；不等同于完整三夜人工验收。完整步骤、限制与验收状态见 [Windows 构建指南](docs/WINDOWS_BUILD.md) 和 [M8-A 验证报告](docs/RELEASE_M8A_VALIDATION.md)。

## 启动

```powershell
& ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64.exe --path .
```

也可在Godot导入本目录的 `project.godot`，按F5。关闭旧试玩窗口后启动新版，并选择新游戏。当前引擎统一为 **4.6.1 Standard**；M0–M3 的 4.7.2 和 M7 的 macOS 验证是历史记录，保留在阶段文档中。

查看面板和现实思考不耗时。正式动作推进18:00–03:00的时间，顾客会继续等待和离店。点击左上铺面招牌打开营业，点击客人后选择「对话/交易」，点击柜台货物后选择「鉴定」；左侧库存柜和桌上账本可直接打开对应功能。右下角「菜单」按「本局/铺务」分组，新游戏与读档在本局，夜间结算、铺中记事和鬼货与绝当录在铺务。

## 三笔交易试玩

第一夜青花碗核对修补口供与侧光接缝；铜烛台可选磁针或旧划痕判断材质。第二夜怀表分别判断机芯品相和卖家是否赶船；核实处境后可争取一次5银元让价，消耗一轮议价，普通客被催价则损失耐心。急售客等待60分钟，普通怀表客等待140分钟。

新开局随机生成品相及处境，同一运行读档保持真相。无需问完、查完即可自由报价。物证和针对同一瑕疵的追问不能重复折价。第三夜铜镜关联的故障怀表保持原设定。

本轮美术由专职人员负责，12图需求见 `docs/M7_ART_HANDOFF.md`；目前沿用已有低保真图与文字证据。详细实现、验收命令和试玩观察问题见 `docs/M7_JUDGEMENT_GUIDE.md`。

## 每日息费

初始现金100银元、借据本金300银元。每夜夜末收3银元利息和5银元铺面开支；本金不变、不计复利。本轮没有七夜还本、提前还款或融资。

短款只宽限到次夜夜末，先还旧欠再付当夜费用。昨日欠5、今晚现金10，结账后只留下当夜新欠3，次夜再到期。到期旧欠仍未付清则经营失败，即使有库存也不会自动变卖。第三夜新欠保留第四夜期限，试玩结束不视为债务结清。

「账本」显示本金、息费、短款和期限；日结区分交易毛利、当夜费用、经营净收益与实际付款。清偿旧欠不重复计入费用。《破铺录》与《绝当录》分别保留经营失败和死亡历史。

## 手动验收路线

以下为开发验收步骤，包含后果说明。

1. **基础扣费**：三夜均不交易，处理记事、开铺、等到封铺、合账。现金依次为92、84、76，本金始终300。
2. **欠款与失败**：新游戏第一客直接报价95收购，刻意让库存占款。首夜夜末现金0、短款3；进入第二夜，账本应写明今夜到期。不出售，第二夜夜末进入《破铺录》。
3. **卖货脱困**：重复上一条，但第二夜开铺后通过库存把青花碗卖给杂货回收商。夜末支付旧欠3和当夜费用8，可继续经营。
4. **铜镜初窥**：新游戏前两夜不交易，第三夜现金84。鉴定铜镜两次后报价54收购，余银30；先覆镜，保持营业到00:00。最后一位怀表来客出现窥镜邀请。揭布5分钟、窥看5分钟，获得怀表损伤证据与旧当票线索。
5. **收手与交易**：选择「收回视线」，在交易页用该证据压价一次，再报价20收表。关门前覆镜，夜末可平安收尾。重复窥看或使用同一证据不会再次获利。
6. **继续追查**：另一轮窥看后选择「看清那张旧当票」，再花5分钟追看。即使后来覆镜或卖给夜半收镜客，当夜仍有来客。危机可选择垂眼护灯退出，也可继续回头；选择前已有异常和禁忌提示。
7. **存档**：分别在欠款、夜间危机和两种终局后读取，期限与结果应保持一致；新游戏保留两本历史账册。

当前仍是三夜内部试玩：8件普通物品、1件鬼货、4类顾客、4名买家、2种当约、7个普通事件和1段独立铜镜遭遇。在当物不可出售；完整鬼市、49夜内容、正式美术音效和30–50分钟整体体验验收尚未完成。

## 存档

新版为 **save_version=7 / content_version=8**，默认 `user://p0/autosave_v7.json`。Mac通常位于：

```text
~/Library/Application Support/Godot/app_userdata/鬼市当铺/p0/autosave_v7.json
```

Windows 内测包通过 `m8a_windows` 导出 feature 隔离到 `%APPDATA%/GhostMarketPawnshop-M8A/p0/autosave_v7.json`；普通编辑器运行仍在 `%APPDATA%/Godot/app_userdata/鬼市当铺/p0/autosave_v7.json`。不自动复制开发版进度或旧账册。内测包日志在 `%APPDATA%/GhostMarketPawnshop-M8A/logs/godot.log`。

旧 `autosave.json` 与 `autosave_v6.json` 保留，不迁移旧进度、不补扣费用；只导入通过校验的《绝当录》《破铺录》。日结、夜间应对、进入下一夜与收尾时原子保存，夜内不即时保存。写入失败回滚本次变化并保留旧文件；损坏的历史记录会阻止覆盖。只支持单窗口写档。

## 自动验证

在项目目录运行：

```sh
godot --headless --editor --quit --path .
godot --headless --path . --script res://tests/run_all.gd
godot --path . --script res://tests/m7_ui_smoke.gd
godot --path . --script res://tests/m7_ui_smoke.gd -- wide
godot --path . --script res://tests/m6_ui_smoke.gd -- production
godot --path . --script res://tests/m6_ui_smoke.gd -- production wide
for mode in write resume read; do
  godot --headless --path . --script res://tests/m7_checkpoint_process.gd -- "$mode"
done
```

M1–M6保留独立测试夹具，M7使用当前生产内容。M6界面脚本传 `production` 可验证生产版本的息费和铜镜。实际UI脚本通过视口鼠标输入操作，默认1280×720，`wide`为1600×900；截图位于忽略目录 `.godot/qa/`。测试存档使用独立 `user://tests/` 路径。

## 开发资料

- `01_鬼市当铺_GDD_V0.4.docx`、`02_鬼市当铺_Codex启动包_V1.0.docx`：原始设计。
- `docs/M6_DEBT_MIRROR_GUIDE.md`：息费、遭遇与存档接入规则。
- `docs/M7_JUDGEMENT_GUIDE.md`、`docs/M7_ART_HANDOFF.md`：三笔交易实现与12图交接清单。
- `docs/PLAYER_COPY_GUIDE.md`：玩家文案规范。
- `docs/M4_CONTENT_GUIDE.md`、`docs/M5_GHOST_GUIDE.md`：此前阶段的内容制作说明。
- `docs/TECH_ARCH.md`、`docs/DECISIONS.md`、`docs/P0_STATUS.md`：架构、决策和验收记录。
