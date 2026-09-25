# 相机 v43 本地验收记录

基线：已发布 main 80c3282。工作区：`.artifacts/camera-appraisal-v43`。本轮未推送、未建立 PR、未合并。

## 自动验证

| 检查 | 结果 |
|---|---|
| camera_appraisal：81 种实物组合、设备与时间门槛、手记、说法、固定价值、回滚 | 3,958 通过，0 失败 |
| camera_economy：收售、批量出售、赎回、绝当、陈列与现金限制 | 35 通过，0 失败 |
| camera_journey：自然客流、实际相机来访、操作与冷回放 | 1,119 通过，0 失败；覆盖 1 次自然相机来访 |
| camera_routes：当前剧情路线 | 889 通过，0 失败 |
| camera_durability：保存与恢复 | 131 通过，0 失败 |
| camera_process：进程重启恢复 | 22 通过，0 失败 |
| camera_ui：1280×720 | 61 项，0 失败 |
| camera_ui：1600×900 | 61 项，0 失败 |
| appraisal_release_entries：新旧入口及存档路由 | 34 项通过 |
| porcelain_release_appraisal：上一版本鉴定规则回归 | 9,800 通过，0 失败 |
| run_all：基础 M0–M7 | 1,801 项通过 |
| 统一启动器 camera / Wide / Verify | 导入与窗口启动通过，自动退出 |
| git diff --check | 通过 |

界面检查实际点击了分组、灯光、光圈、上弦及快门，检查保存失败不播放、部分落笔返回柜台、手记默认带入说法、柜中学习只扣一次准备。补查了库存和出售的相机图像路由，以及旧绣屏图像保留。

过程中的两项失败已处理并重跑：先生成剧情夹具再运行持久化检查；M7 的青瓷碗断言仍期待旧 SVG，而既有生产代码已经升级为 PNG，本次仅修正该过时断言。

Windows Godot 输出 `Failed to read the root certificate store` 环境警告；以上离线检查均完成并返回成功。未做历史器物精密复原验证，画面是游戏化参考，快门观察不是曝光精度测量。本轮没有声称所有旧版 UI 测试均已重跑。

## 截图

- [柜台，1280×720](camera_1280_counter.png)
- [铭文与镜座，1600×900](camera_1600_identity.png)
- [镜片侧光](camera_1600_lens.png)
- [光圈开大](camera_1600_aperture_open.png) / [收小](camera_1600_aperture_narrow.png)
- [快门查验](camera_1600_shutter.png)
- [手记](camera_1600_notes.png)
- [对客说法](camera_1600_claims.png) / [客人回应](camera_1600_reply.png)
- [第四柜学习](camera_1600_learned.png)

完整启动方式、情境参数和首版平衡见 [本地试玩说明](../../CAMERA_V43.md)。

## 铭文与真实快门音效修订

新增三款冒牌铭文，总共四款；独立随机键固定保存，已有无字段相机保留旧图。根据用户听感反馈，撤下全部合成音，接入 animationIsaac 的 CC0 Contax 1935 真实快门录音。来源及剪辑范围在 assets/camera_desk/audio/SOURCE.md；异常音为同源剪辑，不宣称是实际故障录音。

- camera_feedback：2,068 项通过，0 失败。覆盖四图分布、相同种子稳定、保存复制、旧图回退、实物价值不变、试玩选款，以及上弦、正常、迟滞、卡住与画面时序；真实 WAV 均已加载。
- camera_appraisal：3,958 通过，0 失败。
- camera_journey：1,119 通过，0 失败，包含真实来访与冷回放。
- camera_ui：1280×720、1600×900 各 69 项通过，0 失败；包含新铭文实际截图、保存失败不播放及落笔回柜台。
- imitation-city 统一入口验证通过；最终 git diff --check 通过。
- 保留 Windows 根证书环境警告，最终检查未出现脚本错误。自动检查不能代替玩家对声音质感的试听评价。

新增截图：camera_1280_imitation_legacy.png、camera_1280_imitation_letter_swap.png、camera_1280_imitation_extra_letter.png、camera_1280_imitation_city_swap.png；1600 系列同名。

## 柜台相机手绘融合修订

2026-09-25，按用户确认方向，以现有柜台截图及 ART04 水粉规范为参考重绘柜台相机。最终资产 camera_counter_painted.png 为真实透明 RGBA；柜台、库存和出售正面图使用新资源。原位置、显示框和点击区域保留。

检查两轮实际柜台截图后，最终进一步简化皮革颗粒、降低金属高光与黑白反差。采用灰绿暖褐笔触和底部透明阴影。原 camera.png 与 inspection.png、iris.png、三张新增冒牌细节图均保留；五张细节图 SHA-256 与修改前一致。

- 最终资源导入通过。
- camera_ui：1280×720 和 1600×900 各 69 项通过，0 失败；包含物品点击、鉴定、落笔返回、谈价和指南。
- 实际截图检查：原大小下物体完整、没有矩形底色，按钮及文字未受影响。
- git diff --check 通过。Windows 根证书提示仍存在，没有脚本错误。
- 纯美术接入改动，本轮未额外重跑经济及剧情全套测试，未推送或合并。

对照：[修改前 1600](counter-before-painterly-1600.png) / [修改后 1600](camera_1600_counter.png)；[修改前 1280](counter-before-painterly-1280.png) / [修改后 1280](camera_1280_counter.png)。生成方式与完整指令见 docs/art/CAMERA_V43_PAINTERLY.md。
