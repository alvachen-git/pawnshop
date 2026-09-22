# 铜镜人物与结局演出验收

日期：2026-09-17。基线：本次取得的 `origin/main`，`38a5e3ce0fc8f0af823f728b058f12cc3d07eff3`。本地分支：`codex/mirror-presentation`。未推送、未合并。

## 交付内容

- 丈夫六态（常态复用既有水粉货郎，新增五态）、女子六态、四张结局专属插画。柜台、第三夜货郎、预约会面和对质共用丈夫身份入口。
- 稳定对白页标识关联表情、动作、插画与轻音效。表情约0.2秒，主要动作0.9秒，离去1.5秒。玩家自行推进；动作中先完成动作，再次操作才翻页。
- 原谅、劝解、讨债原话保留；告别拆页，增加沉默和松手。失望路线不补写原谅。报复没有血腥、遗体或孩子现身。
- 一个收起按钮、右下紧凑继续按钮，无改日再谈。收起后库存提醒恢复原页，声音不重播。最终保存失败保留重试，成功后才显示能力和资源结果。
- 保留默认v27及阿七、当铺成长；不新增内容版本、存档字段或迁移。v26测试入口显式进入自己的场景，避免默认版本变化后误读测试资料。
- 两条原谅路线的重要情报奖励继续待办；本批没有奖励内容、命灯恢复或查访费返还。

原始PNG与逐张ImageGen提示、实际参考图路径见 [素材目录](../../../assets/mirror_reunion/README.md) 和 [生成记录](../../../assets/mirror_reunion/provenance/prompts.json)。原图未裁切或重编码，游戏沿用已有去底着色器。

## 人物与四结局预览

全部人物状态和插画：[美术浏览页](../../../assets/mirror_reunion/gallery.html)。以下为实际Godot窗口截图，不是界面效果图。

| 检查画面 | 1280×720 | 1600×900 |
| --- | --- | --- |
| 柜前丈夫身份 | [查看](1280-husband-counter.png) | [查看](1600-husband-counter.png) |
| 夫妻重逢 | [查看](1280-acknowledged-reunion.png) | [查看](1600-acknowledged-reunion.png) |
| 迟来的道歉 | [查看](1280-acknowledged-illustration.png) | [查看](1600-acknowledged-illustration.png) |
| 放下旧怨 | [查看](1280-released-illustration.png) | [查看](1600-released-illustration.png) |
| 以怨相留 | [查看](1280-resentment-illustration.png) | [查看](1600-resentment-illustration.png) |
| 失望离去 | [查看](1280-disappointed-illustration.png) | [查看](1600-disappointed-illustration.png) |
| 危险预警与两个选择 | [查看](1280-released-response.png) | [查看](1600-released-response.png) |
| 告别后柜前 | [查看](1280-disappointed-last-line.png) | [查看](1600-disappointed-last-line.png) |
| 结局成功后的结果 | [查看](1280-resentment-result.png) | [查看](1600-resentment-result.png) |

已目视检查人物身份、画面比例、对白区、按钮及危险预警。纸页和插画没有拉伸；两种分辨率下危险提示与选项均可见。四条路线另有隐藏、库存和记事截图，保存在本目录。

## 检查结果

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| 默认v27真实窗口操作，1280×720，四结局 | 355项，0失败 | [UI 1280](ui-1280.txt) |
| 默认v27真实窗口操作，1600×900，四结局 | 355项，0失败 | [UI 1600](ui-1600.txt) |
| v26铜镜完整规则 | 2512项，0失败 | [v26](domain-v26.txt) |
| v27铜镜与阿七结局 | 2425项，0失败 | [v27](domain-v27.txt) |
| 旧v25结局 | 426项，0失败 | [v25](domain-v25.txt) |
| 辨生死与换物边界 | 93项，0失败 | [铜镜边界](mirror-edges.txt) |
| 阿七共存回归 | 951项，0失败 | [阿七](aqi-coexist.txt) |
| 标题与加载入口 | 23项，0失败 | [入口](title-entry.txt) |
| Windows CMD试玩启动 | ready、apology、angry、evasive均成功 | [试玩说明](../../MIRROR_PERFORMANCE.md) |

UI测试通过实际鼠标和确认键输入覆盖：一次现身、三段扣时、固定反应、动画中推进与收起、库存提醒返回原页、无重复音效、危险选项同屏、四路线最终保存失败与重试、失败时阻止营业、成功后正常关铺、结果只显示一次、结局读取不重播。每条结局都注入一次保存失败，检查完整状态回滚及重试不重播袭击；成功存档再经原校验器读取。新版同时验证旧泛光和声音未重复播放。

旧版本领域规则、概率、费用、死亡、能力和资源实现未改变；历史文字快照未改写。`git diff --check`通过。Godot启动有系统根证书读取警告，未出现脚本解析错误或测试失败。

## 性能与范围

环境：Godot4.6.1，Windows，OpenGL Compatibility，NVIDIA RTX3060 Laptop GPU，驱动546.30。素材在界面构建时预载，翻页不读取大图；材质、声音和动画节点复用。

最后一次窗口测试记录：

| 指标 | 1280×720 | 1600×900 |
| --- | --- | --- |
| 单页演出指令应用最高耗时 | 0.331毫秒 | 0.136毫秒 |
| 插画播放期间最高帧间隔 | 6.25毫秒 | 7.04毫秒 |
| 现身入口最高帧间隔（含同帧业务动作和界面刷新） | 140.99毫秒 | 134.80毫秒 |
| 全流程动画期间最高帧间隔 | 140.99毫秒 | 145.00毫秒 |

插画切换与持续动画没有出现大图同步读取；但进入对质的整个操作仍测到约0.14秒的单帧停顿，不能据此宣称所有操作都达到流畅帧率。以上入口指标包含业务动作与其他面板刷新，尚未单独归因；本批未改动领域校验或原子保存流程。这是需要保留的性能观察项，不掩盖为零卡顿。

本地部分克隆中，一张main已有的阿七旧验收图 `docs/qa/aqi-release-20260917/1600-topics.png` 因网络对象下载失败暂未检出；使用仅针对该文件的工作树稀疏标记。源代码、运行素材和本批截图均已检出并通过上述测试，未删除远程历史文件。

## 本地启动

在PowerShell粘贴：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v26.cmd" -Stage ready
```

`-Stage apology`直接查看道歉告别；`-Stage angry`可选劝解或讨债；`-Stage evasive`查看失望离去。加`-Wide`切换1600×900。均使用隔离测试存档，不覆盖玩家正常存档。完整说明见 [本地试玩](../../MIRROR_PERFORMANCE.md)。
