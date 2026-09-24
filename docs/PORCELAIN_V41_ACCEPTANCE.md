# 青花玉壶春瓶 v41 本地验收

基线：main `a2c4d2030a65b723bf33029964b984bf242546c3`。开发分支 `codex/porcelain-appraisal-v41`；本轮未推送、未合并。

## 启动

在本版本目录运行：

```powershell
.\play-porcelain-v41.cmd -Stage porcelain -Wide
```

测试预置不写入正式进度。完整新局使用 `-Stage normal`，独立 v41 存档为 `user://porcelain_unified/autosave_v41.json`。原 v40 入口保留在 `scenes/start_bangle_v40.tscn`，旧版本继续使用原内容与存档语义。

可组合参数：

| 参数 | 选项 |
|---|---|
| `-Holder` | silk 周锦生 / factory 李衡 / opera 程玉笙 / antique 沈季安 / comprador Edward |
| `-Era` | yuan 元 / ming 明 / qing 清 / republic 民国 |
| `-Craft` | rough 粗工 / standard 常品 / fine 精工 |
| `-Sample` | 1 / 2 |
| `-Damage` | intact 完好 / minor 轻损 / major 重损 |
| `-Difficulty` | ordinary / hidden 仿古干扰 |
| `-PorcelainCase` | natural / guide / bargain / overpriced / partial / firm / exposed / no-tools |

`natural` 使用指定实物及正常随机来客认识。其余交易情境是确定性测试预置，强制买断以便试谈价：bargain 为被低估的元代精工，overpriced 为被高估的民国常品；这两项覆盖传入的年代与工艺。partial 为部分让价，firm 为承认但不让，exposed 用于检查不实贬价被拒，no-tools 缺鉴物台。guide 从开铺前进入，前往藏瓷图录柜学习。

示例：

```powershell
.\play-porcelain-v41.cmd -Stage porcelain -Holder opera -Era republic -Craft fine -Sample 2 -Difficulty hidden -Wide
.\play-porcelain-v41.cmd -Stage porcelain -PorcelainCase bargain -Wide
.\play-porcelain-v41.cmd -Stage porcelain -PorcelainCase guide -Wide
```

## 已接入

- 四年代、三工艺、独立外伤和难度；每年代两套图样，同套提供四向整器、绘纹与底足。新瓷器没有隐藏修补。
- 真实价值生成后固定；柜台保守估值只随已查外伤调整。出售、陈列、批量及绝当读取固定价值。
- 器材查验收取一次 10 分钟；观察、放大、图录与复看免费。转瓶返回整器；换参考保留放大。美术修订后移除三个灯光按钮，采用固定观察光。
- 五页图录、独立年代与工艺手记；部分查验可落笔，保存成功返回柜台。
- 手记、对客说法、客人认识与真实事实独立；各类说法只谈一次，沿用相信概率、议价性格和一次性商誉处罚。
- 活当资金需求李衡 293、Edward 338；买断无该限制。旧版怀表、珍珠、金镯和瓷器规则保留。

## 验证记录

最新谈价文案补充：瓷器认同货况而不降价时，按已计入货况、坚持要价、此前让价、最低筹款额、未形成降价理由和不足一银元的差额分别回应。不改相信概率、价格公式、实际货值或历史对白快照。新增七种交易情境验证（含全部说法被拒）；`porcelain_appraisal` 本轮 9,800 项通过、0 失败。输出见 `qa/porcelain-v41/verification/no-concession-replies.txt`。本轮仅修改瓷器流程，未推送或合并。

Godot 4.6.1，Windows，1280×720 与 1600×900。使用本版本目录内隔离 APPDATA。

| 检查 | 结果 |
|---|---|
| porcelain_appraisal | 9,777 通过、0 失败：72 组合 × 2 样本，价值固定、概率、证据强度、合并/分开说法、资金线与回滚 |
| porcelain_journey | 514 通过、0 失败：自然来客、保存失败、冷重放一致 |
| porcelain_economy | 35 通过、0 失败：收购、放当、赎当、绝当、三种出售及现金不足原子性 |
| porcelain_ui | 美术修订后两个分辨率各 76 断言、0 失败：移除灯光按钮、保留年代对照、放大、图录、落笔、改口、学习和缺设备 |
| porcelain_routes | 4,044 通过、0 失败：统一剧情路线 |
| bangle_appraisal | 11,736 通过、0 失败 |
| pearl_appraisal | 23,030 通过、0 失败 |
| watch_negotiation | 1,070 通过、0 失败 |
| fan_condition | 2,078 通过、0 失败 |
| unified_aqi | 3,299 通过、0 失败 |
| run_mirror_endings | 2,944 通过、0 失败 |
| unified_facilities / unified_saves | 130 / 27 通过、0 失败；先生成旧流程存档再冷读 |
| appraisal_release_entries | 28 项通过，新默认入口与旧入口/存档兼容 |
| item_study_atlas_ui | 13 断言、0 失败：旧版普通鉴定及物品展示 |
| 启动脚本 | `-Stage porcelain -Era republic -Craft fine -Sample 2 -Difficulty hidden -Verify` 通过 |

初次旧存档检查因缺少 `fan-bought.json` 测试夹具而未完成；运行 unified_facilities 生成后，unified_saves 全部通过。Windows 根证书读取提示不影响本地离线运行。原始输出保存在 `docs/qa/porcelain-v41/verification/`。`git diff --check` 通过。

截图见 [鉴定桌](qa/porcelain-v41/porcelain_1600_desk.png)、[底足](qa/porcelain-v41/porcelain_1600_foot.png)、[工艺图录](qa/porcelain-v41/porcelain_1600_guide_4.png)、[谈价](qa/porcelain-v41/porcelain_1600_claims.png)，同目录保存两个分辨率的完整操作截图。

原版图样记录见 [美术来源](../assets/porcelain_desk/SOURCE.md)；前次素材修订见 [美术修订记录](PORCELAIN_V41_ART_REFINEMENT.md)。最新的整器、旋转、绘纹、底足与柜台三档工艺补全见 [工艺表现补全](PORCELAIN_V41_CRAFT_REFINEMENT.md)，该轮界面验证更新为两个分辨率各 85 项通过，并补充 1,408 项图集验证及 321 项柜台验证。图样是受馆藏启发的游戏样本，图录明确提示合看多处特征；不是用于现实古董断代的检测依据。
