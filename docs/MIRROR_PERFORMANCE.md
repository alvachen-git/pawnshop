# 铜镜演出打磨 · 本地试玩

本批只更新人物美术、对白分页与演出，不新增内容版本、不迁移存档、不要求重开。基于 2026-09-17 取得的 main `38a5e3c`，保留同期当铺成长和阿七陪伴内容。四种结局、固定交涉结果、三段各5分钟、能力与资源规则沿用现有实现。

## 直接试玩

在 PowerShell 粘贴完整指令：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v26.cmd" -Stage ready
```

直接测试告别或报复：

```powershell
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v26.cmd" -Stage apology
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v26.cmd" -Stage angry
& "C:\Users\alvachen\Documents\ChatGPT\pawnbroker\.tools\v25-playable\tools\play_v26.cmd" -Stage evasive -Wide
```

`apology` 对应迟来的道歉；`angry` 的两个选择分别进入放下旧怨和以怨相留；`evasive` 对应失望离去。默认1280×720，`-Wide`为1600×900。测试存档与玩家正常存档隔离；阶段名称是测试入口，不显示在剧情里。

## 观察重点

- 现身、会面与柜台中的丈夫使用同一个货郎身份。夫妻各六种状态；四张结局插画在上方演出区显示，下方始终沿用原对白框。
- 道歉后先沉默、松手，再说原谅；孩子相关的话独立一页，最后才告别。劝解保留原话。失望路线不添加原谅或感谢。
- 点击或确认键逐页阅读。动作尚未结束时，第一次继续完成动作，下一次继续才翻页。没有自动翻页或配音。
- 只有一个“收起 · Esc”。收起后通过库存惊叹号返回同一页，不重播音效；对质中没有“改日再谈”。当前对质仍需说完才能继续经营。
- 最后一页确认后才结算。保存失败会显示“重试保存”，保留当前画面；重试不重播袭击。能力和怨气消息只在成功后出现一次。
- 两条原谅路线的重要情报奖励仍为待办，本批不增加奖励，不恢复命灯，不返还查访费。

## 实现与素材

对白演出使用稳定页ID；表情、动作、插画和轻声音由独立演出层处理。原领域对白和历史见闻不改写，存档没有新增演出字段。已结局存档和见闻不会自动重播。

素材在 [人物与插画目录](../assets/mirror_reunion/README.md)，逐张生成提示及源图路径在 [生成记录](../assets/mirror_reunion/provenance/prompts.json)。全部使用内置 ImageGen，以既有水粉货郎、当铺和铜镜原画为实际参考；原始生成PNG原样保留，渲染时沿用既有去底着色器。

检查与截图见 [本批验收记录](qa/mirror-performance/REPORT.md)。本批仅本地交付，未推送或合并。
