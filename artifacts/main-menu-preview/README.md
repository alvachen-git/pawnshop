# 鬼市当铺主画面动效预览

采用用户最终贴图确认的雨夜铺门：左侧标题与三枚按钮，右侧店门和灯笼。`references/selected-doorway.png` 是确认来源，`references/refined-menu.png` 是木牌细化目标。

## 预览范围

这是一份独立的主菜单视觉与动效预览。三个按钮提供真实的悬停、键盘焦点和按压反馈，并发出 `pawnbroker:menu-action` 事件（`new`、`load`、`exit`），网页本身不会改动游戏进度。相同主画面已通过原生控件接入 Godot 的 `scenes/start.tscn`，实际游玩请从工程根目录启动游戏，详见 `docs/MAIN_MENU.md`。

最新确认：包括“开启新游戏”在内，三枚按钮平时都为暗木色，仅悬停或键盘选中时显出暗红；鼠标移开恢复，不保留主按钮常驻红色。

鼠标移上按钮：木牌轻抬 2px，旧红漆和印记缓慢显露，文字留下轻微延迟重影；门内灯光迟 340ms 稍暗。移开后恢复。支持 Tab、方向键、Home/End、Enter/Space 和 Escape；遵循系统减少动态效果设置。

## 本地运行

已构建版本运行于 `http://127.0.0.1:4173/`。

```powershell
npm run build
npm run preview -- --configLoader native --host 127.0.0.1 --port 4173 --strictPort
```

在当前受限 Windows 环境中，开发服务器的依赖扫描会触及不可读的父目录；采用原生配置加载的生产构建与 preview 已通过验证。

## 验证

`design-qa.md` 记录视觉比对。`verification/results.json` 记录鼠标、键盘、三个分辨率、减少动态效果以及浏览器错误检查。`scripts/verify-menu.cjs` 接收可用的运行时 node_modules 路径作为参数，需要其中的 Playwright 与 sharp。截图来自全新本地 Chrome 测试上下文。

## 美术来源

使用内置 ImageGen，未使用 CLI 图像生成。场景与牌匾保存在 `public/assets/`；生成提示保存为 `asset-prompts.md`。背景素材含标题，按钮文字由真实界面控件显示。木牌资源是 1846×852 的不透明画布，展示区域按 x23/y229/w1800/h337 精确取景，避免拉伸。没有用代码绘制美术图案。
