# 寝屋私人物件 · 本地验收

2026-09-12，基于 main `e819363`，Godot 4.6.1 / Windows / OpenGL Compatibility，NVIDIA RTX 3060 Laptop。已完成本地验收；用户确认推送及线上合并，发布前核对 main 未发生变化。

## 检查结果

| 检查 | 结果 |
|---|---|
| `tests/run_room_keepsakes.gd` | 333 通过，0 失败 |
| 同脚本 `-- process-read` | 独立进程恢复 8 份快照，9 通过，0 失败 |
| `tests/room_keepsakes_ui.gd` 1280×720 | 162 通过，0 失败 |
| 同脚本 `-- wide` 1600×900 | 162 通过，0 失败 |
| `tests/run_personal_risk.gd` | 2364 通过，0 失败 |
| `tests/run_all.gd` | M0–M7：1800 通过 |
| `tests/run_room.gd` | 701 通过，0 失败 |
| `tests/life_lamp_ui.gd -- wide` | 85 通过，0 失败，包含五档灯态和寝屋操作 |

实机脚本中打印的 134 条私人互动检查已计入最终 162 条；灯态脚本中的 57 条已计入 85 条，不重复相加。

测试使用隔离 APPDATA、测试存档文件及存档库。引擎仍有 Windows 根证书库读取警告，不影响这些离线检查；最终日志没有脚本错误或断言失败。

## 覆盖

- 首夜摆过和未摆过照片，以及首夜尚未安顿完的旧 v22 档；旧单文件、旧自动和旧手动位置均可读取，读取不重写原文件。
- 照片状态跨夜、回房、自动和手动恢复；独立进程恢复旧档及新增照片操作的存档。
- 重复点击不增加操作记录、不发布存档；故障注入验证完整回滚、磁盘原文件保留，重试成功。
- 新状态字段缺失但已有照片命令、伪造位置、错误数据类型均被拒绝；旧运行与新运行切换继续通过。
- 信件仅按获得条件展示，全文内容保持原文；反复阅读不修改状态或存档。
- 真正鼠标点击、Tab 焦点限制、Esc 分层返回、正文滚动、固定底部按钮、遮罩阻止点击床；存档库读取及单文件读取均关闭面板。
- 暗室下文字可读、照片素材和热点同步；照片操作不改变命灯、时间、资产、剧情历史。回归观察、菜单、取消就寝和“放松入眠”直接进入次日。

旧寝屋实机脚本同步适配 main 新的统一凭据：首笔交易一次“收好凭据”完成，不再点击已删除的第二步。

## 实机截图

[1280 照片观察](1280_photo_on_desk.png) · [1280 收起后房间](1280_photo_stored.png) · [1280 保存失败](1280_save_error.png)

[1600 私人信件列表](1600_letters.png) · [1600 信件上部](1600_letter_top.png) · [1600 信件末尾](1600_letter_end.png) · [1600 抽屉中的照片](1600_photo_in_drawer.png) · [1600 未获得信件](1600_empty_drawer.png)

原始日志位于本工作树 `.artifacts/`：`run_room_keepsakes.log`、`keepsakes-process.log`、`keepsakes-ui-1280.log`、`keepsakes-ui-1600.log`、`run_personal_risk.log`、`run_all.log`、`run_room.log`、`lamp-ui.log`。独立进程快照位于 `.artifacts/keepsakes-transfer/`。

[功能和试玩说明](../../ROOM_KEEPSAKES.md)
