# 铺内设施场景 · 本地验收

日期：2026-09-16。运行 `shop_growth_ten`，内容／存档 v25，显示版本 `V25-ShopGrowth.2-Facilities`。

## 交付范围

- 柜台左侧停留350毫秒进入铺内，默认180毫秒淡入淡出；右侧返回，另有小箭头、铺务菜单和Esc。已移除简化切换按钮。
- 固定底部经营状态栏；场景中的鉴物台、陈列柜、旧账柜可直接操作。转场期间阻止重复点击，弹窗或报价页展开时不自动滑走。
- 真实一级整修40／60银元，共用原准备额度；两项独立变更外观。现金、设施与外观随保存失败一起恢复。
- 空柜／真实库存陈列物／撤下；柜前来客提示返回原接待流程，成交仍在柜台完成。
- 三步查柜只显示已取得资料；发现后才显示柜格，免费复看。
- 独立场景提供初始、一、二、三级外观预览，中央旧账柜也逐级更新。该场景没有 RunSession、Bootstrap 或保存入口。

**高级规则边界：** 二三级经营功能、工具取得、中央旧账柜的修缮费用与条件待另行确定。正式经营中的旧账柜仍是原外观，调查免费。预览不赠送货物、工具或线索。没有设施互斥、自动卖货或新增经济参数。

## 隔离与来源

继续在 `.artifacts/shop-growth` 原独立副本实现，沿用此前从本地v23冻结的十夜内容。来源见 [SHOP_GROWTH_SOURCE.json](SHOP_GROWTH_SOURCE.json)。此次不是同步根目录最新铜镜／人物资产。

开发前核实：铜镜任务仍活跃，人物图像任务当时空闲；这些只是当时状态。未修改根目录任务文件。原柜台、寝屋背景与开发前哈希一致，记录在 [art-integrity.json](qa/facilities/art-integrity.json)。新资源与校验值见 [asset-manifest.json](qa/facilities/asset-manifest.json)，制作来源见 [PRODUCTION_ASSETS.md](design/facilities-room/PRODUCTION_ASSETS.md)。

UI改动集中于 `FacilitiesRoomView`、`FacilitiesNavigation`、独立预览场景及现有柜台入口；所有经营写入仍调用现有 `growth_command`。本轮未改变交易服务、存档结构或重放规则。改动清单见 [implementation-diff.json](qa/facilities/implementation-diff.json)。

## 验证结果

Godot 4.6.1；Windows；实际图形渲染已验证。界面测试向真实视口注入鼠标与键盘输入并保存截图，不以设计图代替实机。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 新设施界面1280×720 | 106项通过，0失败 | [ui1280.log](qa/facilities/ui1280.log) |
| 新设施界面1600×900 | 106项通过，0失败 | [ui1600.log](qa/facilities/ui1600.log) |
| 原成长界面与买家操作 | 66项通过，0失败 | [legacy-ui.log](qa/facilities/legacy-ui.log) |
| 成长规则 | 1358项通过，0失败 | [rules.log](qa/facilities/rules.log) |
| 边界／稳定随机／探索／期限 | 1055项通过，0失败 | [edges.log](qa/facilities/edges.log) |
| 原子写盘及失败回滚 | 25项通过，0失败 | [storage.log](qa/facilities/storage.log) |
| 跨进程恢复 | 5项通过，0失败 | [storage-read.log](qa/facilities/storage-read.log) |
| 铜镜与成长共存 | 2373项通过，0失败 | [mirror.log](qa/facilities/mirror.log) |
| 保存与读模型性能回归 | 25项通过，0失败 | [performance.log](qa/facilities/performance.log) |
| 正常及四种快速启动 | 5个入口均启动并退出成功 | [launch-verification.log](qa/facilities/launch-verification.log) |

界面覆盖：快速掠过不切页、两侧悬停、窗口失焦／离开取消、转场中调整窗口、默认淡入淡出、Esc与菜单、纸页阻断、报价输入保留、四种整修组合、陈列撤下、探索三阶段、资料复看、强制待办、资金不足、真实写盘失败与重试、来客返回成交一次及四阶段独立预览。

测试过程中修正了锚点残留导致的布局偏移、鼠标位置采集、纸页滚动复位、窗口缩放中转场落点与接缝跟随时序。最终日志无脚本／解析错误和测试失败。环境输出一条系统证书仓库读取警告；本地渲染、规则、文件保存与启动不依赖该证书仓库，均通过。

性能用例中保存温启动约31—68毫秒，读模型对平均约4.7—5.3毫秒；这是既有用例测量，不是新场景的帧率基准。隐藏设施页不重复构建内容，纹理缓存复用。

## 实机截图

| 状态 | 1280×720 | 1600×900 |
| --- | --- | --- |
| 初始破旧 | [图](qa/facilities/facilities_1280_01_initial.png) | [图](qa/facilities/facilities_1600_01_initial.png) |
| 鉴物台操作纸页 | [图](qa/facilities/facilities_1280_02_bench_paper.png) | [图](qa/facilities/facilities_1600_02_bench_paper.png) |
| 仅鉴物台整修 | [图](qa/facilities/facilities_1280_03_bench_only.png) | [图](qa/facilities/facilities_1600_03_bench_only.png) |
| 仅陈列柜整修 | [图](qa/facilities/facilities_1280_08_display_only.png) | [图](qa/facilities/facilities_1600_08_display_only.png) |
| 两项整修与真实货物 | [图](qa/facilities/facilities_1280_04_displayed.png) | [图](qa/facilities/facilities_1600_04_displayed.png) |
| 调查后柜格 | [图](qa/facilities/facilities_1280_06_compartment.png) | [图](qa/facilities/facilities_1600_06_compartment.png) |
| 三级独立预览 | [图](qa/facilities/facilities_1280_preview_3.png) | [图](qa/facilities/facilities_1600_preview_3.png) |

完整视觉复核见 [design-qa.md](../design-qa.md)。

## 试玩与后续

完整可复制启动指令见 [试玩说明](SHOP_GROWTH_PLAYTEST.md)。正常、整修、查柜、买家入口保留各自存档目录；外观预览只读取资源。

本轮没有改变经济数值，因此没有重新把旧种子收益试验冒充新结果；之前的固定种子经济对比见 [首批验收](SHOP_GROWTH_ACCEPTANCE.md)。后续应先试玩本场景，再确定高级工具、二三级费用和旧账柜修缮方式。专门施工动画与新增声音未纳入本批。尚未在其他显卡、超宽比例、触屏或发行包验证。

以上为首次本地验收快照；2026-09-17追加主分支整合验证，见[整合记录](SHOP_GROWTH_INTEGRATION.md)。未制作发行包。
