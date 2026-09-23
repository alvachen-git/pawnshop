# 旧当铺细修验收 · 2026-09-23

工作目录 `.artifacts/first-debt`，本地分支 `codex/first-debt-v28`。修改标题素材、当票笔迹与改期痕迹、原件返回交互；不改事件、时间、经济、存档或旧版数据。未推送、合并或打包。

## 修改前观察

[审查记录](AUDIT.md)与[鼠标返回日志](return-before.log)：本次未复现完全无响应；原“返回册页”第一次落在抄录页，第二次才进册页。改为真正一步返回，并为原件增加固定底部按钮。之前的测试偏重Esc逐层返回，这次补齐鼠标行为。

## 自动回归与真实窗口

- 1280×720：[104断言，0失败](window1280.log)。
- 1600×900：[104断言，0失败](window1600.log)。

两者均为非headless Godot真实图形窗口、真实viewport鼠标与键盘输入。验证原件滚轮后底部按钮、右上按钮、Esc均一次回册页；再次收起回柜台且焦点恢复。检查打开与分类不提前授予知识，首次细读写盘失败回滚及重试，已读复看不重复历史，原件返回不改变时间／现金／历史，背页观察入口继续可用。

日志无SCRIPT ERROR或运行时ERROR。`git diff --check`通过。本轮未重跑百夜、全剧情、Windows、发行包或外部CI；玩法未修改，不把前次回归冒称本轮结果。

## 代理目视阅读

- [新标题与手写当票 · 1280](1280-ticket-only.png)
- [新标题与手写当票 · 1600](1600-ticket-only.png)
- [原件残墨及固定返回](1280-original-clue.png)
- [资料齐全后的册页](1600-album.png)

标题由通用纸框换成布边贴签。手填内容有自然笔画与间距，五旁原有的加号移除；现只留五末横下的淡断墨。完整票面及放大图已逐字核对，事实与事件不变。残笔不再画成另一个完整字，清晰抄录仍可阅读。

此项为代理对实际运行截图的目视，不冒充真人整局试玩或用户审美确认。[设计检查](../../../design-qa.md)结论passed。

## 使用

原启动命令不变，账本或菜单进入「旧当铺」。展开原件后，点击右下「返回册页」、右上返回或Esc均直接回册页；再按Esc收起。

复现：
```sh
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-refine-1280.log -- refinement
/opt/homebrew/bin/godot --path . --script tests/old_shop_ui.gd --log-file /private/tmp/old-shop-refine-1600.log -- wide refinement
```
