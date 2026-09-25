# v43 发布前复核 · 2026-09-25

用户已明确授权 push 并在线合并到 main。本次发布包含相机鉴定闭环、四款冒牌铭文、CC0 实录快门音、相机与瓷瓶及怀表柜台美术，以及怀表缩放至此前尺寸的 65%。

本次重新运行：camera_feedback 2068/0、camera_economy 35/0、camera_durability 131/0、camera_process 22/0、appraisal_release_entries 34 项通过。所有进程退出码为 0。

已有当前美术验收：camera_ui 两分辨率各 69/0，柜台素材两分辨率各 82/0，怀表最终尺寸两分辨率各 10/0；瓷器工艺 1408/0、精细界面 321/0。详见本目录 ACCEPTANCE.md、../counter-props/ACCEPTANCE.md 与 watch-scale/NOTES.md。

环境及测试清理提示：Windows 根证书库读取警告仍存在；camera_feedback 结束时出现 ObjectDB/resource 清理警告，断言无失败。截图和旧入口兼容检查已完成。

提交排除本机 Godot 导入缓存及其他旧版 QA 截图的自动改写。旧内容入口、其他开发工作树保留。
