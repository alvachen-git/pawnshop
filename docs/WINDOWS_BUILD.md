# Windows 构建与验收指南

## 工具准备

使用 [Godot 4.6.1 官方归档](https://godotengine.org/download/archive/4.6.1-stable/) 中的 Standard Windows x86_64 编辑器与 Standard 导出模板，不使用 .NET 版本。保存以下原始文件到忽略目录 `.tools/downloads/`：

- `Godot_v4.6.1-stable_win64.exe.zip`
- `Godot_v4.6.1-stable_export_templates.tpz`
- `SHA512-SUMS.txt`（官方发布页同目录，用于人工复核；构建脚本固定了本版官方预期值，不信任临时改写的清单）

解压编辑器 ZIP 到 `.tools/godot-4.6.1/`，保留两个 EXE 的原文件名。构建时检查引擎完整版本、归档 SHA-512、编辑器 EXE 字节与归档对应关系，再从已验证 TPZ 提取 Windows 模板到当次构建目录。无需安装到全局模板目录。

大文件网络较慢时可选用 PowerShell 7：

```powershell
./tools/fetch_windows_templates.ps1
# 只有确实需要本机代理时才显式传参，例如 -Proxy http://127.0.0.1:7897
```

该工具只请求官方地址，分段下载后重新校验完整 SHA-512。不修改全局 PATH、Git 代理或证书/安全设置。失败分段和缓存保留在 `.tools`，不得将未校验文件当成正式模板。

## 构建命令

```powershell
./tools/build_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe
```

可选 `-EditorArchive <ZIP>` 与 `-TemplatesArchive <TPZ>`。从其他目录调用时建议使用绝对路径。首次签出需确保字体、原始许可和生产资源均完整。

流程为：检查输入 → 导入源工程 → 隔离存档自动回归 → 生成生产暂存工程 → 干净导入 → Release 导出 → 空工程挂载最终 PCK 审计 → 复制说明/许可/构建信息 → ZIP/SHA-256。没有跳过测试选项；任何脚本异常、失败断言、缺少成功摘要或非零退出码均停止。每个子进程有超时，日志完整保留。

`dist/<构建ID>/` 存放成功内测 ZIP 与 SHA-256、资源审计、源测试摘要；`.artifacts/m8a/<构建ID>/` 保留日志、测试数据和截图。失败构建不打印成功包路径，不覆盖以往通过的 ZIP。

只检查源码时：

```powershell
./tools/test_windows.ps1 -GodotPath ./.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe -OutputDir ./.artifacts/<新的验证目录>
```

## 打包边界

JSON 清单来自 `data/content_manifest.json` 的 `sources`，当前精确为 Manifest 加运行、物品、顾客、买家、当约、事件和鬼货规则，共 8 份 JSON。不是把整个 `data` 目录打包。构建中记录每份源内容和实际 PCK 内 JSON 的 SHA-256 并逐一比较。

生产 `core/`、`ui/` 和主场景显式复制；当前 ART02 的 16 张动态 SVG 及 Noto Sans SC 字体显式纳入。测试脚本、夹具、历史内容、审阅场景、文档、工具和玩家存档不复制。`.godot` 导入缓存在暂存工程重新生成，不能混入源工程的测试类缓存。

字体为未裁剪原件，原始 OFL 随包保留。不能为了体积删除中文字体或改回系统字体依赖。引擎原始 MIT 和第三方版权/许可清单同样保留。

依据：[Godot 非资源文件导出规则](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html)、[自定义 feature 与项目设置覆盖](https://docs.godotengine.org/en/4.6/tutorials/export/feature_tags.html)。修改生产 Manifest 后必须重跑构建入口生成新的清单，不能只用旧的编辑器导出过滤器。

## 正式 EXE 的独立检查

```powershell
./tools/smoke_windows_package.ps1 -ZipPath ./dist/<构建ID>/Pawnshop-V06-Room.1-windows-x86_64.zip
```

必须在非管理员会话运行。脚本校验 ZIP 和解压后的二进制哈希，解压到 `%TEMP%/鬼市当铺 M8A Test <唯一ID>/game/`，将 APPDATA 临时指向该次检查目录并恢复环境变量。正式 EXE 不接受源码目录或外部测试脚本参数。检查普通/图形启动、默认日志落点及开发存档哈希不变；截图若生成则来自 EXE 的引擎录帧能力。

PCK 审计用编辑器在空工程挂载包，仅证明包内资源，不证明 EXE 的完整交互。源 UI 测试用真实视口鼠标事件，但同样不能替代 EXE 完整试玩。

注意：EXE 启动脚本请求 1280×720 和 1600×900 窗口，但 MovieWriter 在当前项目下始终录制 1280×720 基准视口。不能把命令行尺寸参数或录帧文件名当作已确认的原生窗口尺寸；1600×900 原生布局与 DPI 仍须人工验收。录帧低磁盘空间警告独立保留在报告，不是已发生的脚本错误。

## 人工验收单（只在实际 EXE 中勾选）

- [ ] 解压后双击启动，无 Godot、源码路径、管理员权限依赖；无美术预览入口。
- [ ] 1280×720、1600×900 下中文无方框，弹窗、长按钮、金额与标点可读，固定操作栏不被遮挡。
- [ ] 当前 Windows 缩放、125%/150%（若设备允许）下，鼠标焦点、键盘输入、滚动及窗口缩放可用；记录实际值，不改变系统设置来冒充已覆盖。
- [ ] 首次开铺 → 青花碗取证/议价 → 收购；错误判断仍可能亏损。
- [ ] 库存出售、不同买家、活当、当票/续当/赎回与账本联动。
- [ ] 夜末保存后退出并重开 EXE，点击读取，恢复正确夜次与财务；未修改开发版目录。
- [ ] 连续三夜收尾；铜镜取证、覆镜、窥探、警告、生还及死亡；资金占款后进入破铺路径。
- [ ] 使用自动测试生成的有效 v7 **副本**恢复（不使用玩家唯一原件）；损坏副本读取报错，内容不被静默重置/覆盖；两本有效历史账册保留。

正常玩家存档是 `%APPDATA%/GhostMarketPawnshop-M8A/p0/autosave_v7.json`，日志是同根目录 `logs/godot.log`；编辑器仍使用旧目录。测试兼容旧 v7 时应新建临时 APPDATA 并仅复制测试档，结束后恢复环境，不自动搬移任何开发版进度。

未签名版本可能遇到 Windows SmartScreen 提示；只建议核对可信来源和 SHA-256、反馈具体提示，不要求关闭安全防护。未测的系统、硬件、架构和 DPI 不标为已支持。只有负责人完成实际 EXE 验收后，才能将 M8-A 状态改为完成；不会自动进入 M8-B。
