# 开场美术：入巷见铺

2026-09-24，负责人选择三张独立概念图中的第1张。基于 main `9da27b0` 制作，沿用 ART04 半写实不透明水粉、民国上海生活质感与克制的诡异。用户随后要求工头更凶猛、与客人区别明显，最终使用 `factory-v2.png`。

## 画面与呈现

短段落：整幅场景、底部暗色阅读区、右下纸面动作。标题和正文由 Godot 实时绘制；不把按钮与叙述烘焙进图片。保留原文含义，把短段落的空行收为单换行；喜帖及正文引用姓名统一为「姚曼卿、陸紹廷」。顾叔长信保留独立可滚动阅读区；接手旧铺和寝屋按真实可用选择排列。

| 现有 presentation.scene | 实际资源 |
| --- | --- |
| factory | opening_art/factory-v2.png：短寸头、厚颈宽脸、强硬目光的工头 |
| photo | opening_art/photo.png：双人旧照片与劳作过的双手 |
| wedding | opening_art/photo.png + invitation-source.png 喜帖区域：同一底图、繁体姓名 |
| key / letter | opening_art/letter.png：遗信与普通铁钥匙 |
| memory | opening_art/memory.png：顾敬堂指看旧银元 |
| stamp | opening_art/stamp.png：顾叔按住少年握章的手 |
| exterior | opening_art/exterior.png：选定方案的旧街与铺门 |
| inspection | opening_art/inspection.png：冷香灰、熄灯、明账与红黑旧册 |
| customer | 复用 ART04 柜台、现有街坊妇人与银簪 |
| room / sleep | 复用现有寝屋；照片随真实旗标显示，沿用夜间曝光规范 |

8张最终原画均由内置 image_gen 生成，1672×941。确切提示、来源路径见 `assets/opening_art/*-prompt.md`；尺寸与 SHA-256 见 `assets/opening_art/manifest.json`。工头首稿移到本地忽略目录 `.artifacts/opening-art-drafts/`，运行时只引用修订版。

## 边界

仅修改叙事呈现、增加素材和测试。未修改事件ID、选择ID、条件、结果、资金、知识门槛、音频调度、存档格式或主入口默认存档。已开始的存档继续处于原剧情进度；本身不会自动重播开场。读到现有开场节点时会使用新美术。

## 试玩

独立测试存档，直接进入纱厂：

```sh
godot --path "/Users/alvachen/Documents/ChatGPT/pawn/.artifacts/opening-art-release" res://scenes/opening_art_review.tscn
```

常规入口：同一路径运行 `godot --path`，选择「新游戏」。发布分支为 `codex/opening-art-release-20260924`；发布结果以对应PR为准。

## 验证

- `tests/run_opening.gd`：100 assertions, 0 failures。
- `tests/opening_art_ui.gd`：当前正式 v39 内容，固定 seed 42；1280×720、1600×900，各143 assertions, 0 failures。
- 真实渲染与输入覆盖12段序章、长信滚动、检查明账和旧册、首笔交易、寝屋摆照/存信/命灯、就寝、重看跳过。
- 中途保存读档状态完全一致；独立测试存档。
- 截图、日志：`docs/qa/opening-art/`；视觉对照：根目录 `design-qa.md`。
- 未执行 Windows 打包、全游戏随机种子回归；未宣称玩家已验收。

## 2026-09-24 试玩修订

两处旧照片共用同一纹理，实机截图的人脸区域逐像素一致。喜帖只叠加纸面与贴地阴影，采用「姚曼卿、陸紹廷」，旧婚帖整景不再引用。

`evt_intro_gu_value`、`evt_intro_gu_people`、`evt_intro_gu_flashbacks`统一低饱和、低亮度、轻微灰褐色回忆氛围；只影响原画，文字与按钮保持清晰。根据事件ID区分回忆，避免真实首笔成交（也使用stamp场景）被误判。现实中翻看照片与喜帖保持正常场景色彩；旧照片自身仍是褪色影像。

## 推门动作音效

「推门进铺」成功执行时播放独立的1.77秒真实开门素材。已替换先前合成声，来源为Rudmer_Rotteveel的Creaky Door Slow 01（Freesound 590947，CC0）；来源、许可、转换和校验值见`assets/opening/WOODEN_DOOR_SOURCE.md`。铺外不提前播放；独立播放器让声音延续到铺内，纸张切换声不覆盖门声。

1280×720真实窗口复验146断言/0失败，新增提前静音、点击后持续播放、切换声不覆盖三个检查；日志`docs/qa/opening-art/door-ui.log`。本次未重跑1600×900。

## 周婶首次登场与操作引导

固定角色：周秀英，称呼周婶，沿用`intro_neighbor`和既有人像。她住隔壁，与顾敬堂熟识，常来聊天；耐心、爽直，愿意陪新掌柜练手，但不替玩家判定价值。后续编写她的来访时沿用这个姓名、邻居关系和口吻；本次不新增夜次或来访调度。

首客事件拆为五页显示：认识邻居、主角说明受托接铺、鉴定银簪、对话与正式报价、铃铛招客/长按谢客。页面末尾用主角回应推进，最终才提交既有`continue`选择。事件ID、成本、旗标和存档结构保持不变。旧存档未完成该事件时会看到新文案；已经完成的不会重播。分页位置不持久化，重新启动后从该事件第一段读起；已有历史文字快照不重写。

按钮用语对应实机：点银簪→鉴定；点客人→对话/交易；交易内正式报价并收购。铃铛在空柜时轻点等待来客，正在接待时长按1秒送客，提前松开取消。

本轮1280×720、1600×900各187断言/0失败；开场核心100断言/0失败。检查五页全文可见、逐页不改经营状态、首客完成旗标及后续交易/首夜。正式入口使用`data/integrated/events.json`，与独立开场的`data/opening/events.json`同步页面配置。截图`neighbor_page_1`至`neighbor_page_5`，日志`neighbor-ui-1280.log`、`neighbor-ui-1600.log`、`neighbor-core.log`。

## 发布前整合复验

基于最新main `c5980cf`（v41，保留金镯、首债回收和评弹收音机），正式入口`first_debt_recovery_release`；1280×720、1600×900各187断言/0失败，核心100断言/0失败。真实CC0门声已在这轮参与检查。日志`release-v41-1280.log`、`release-v41-1600.log`、`release-v41-core.log`。未执行Windows打包及全游戏长流程验收。
