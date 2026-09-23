# v30 新物品原画来源

按《鬼市当铺》V0.2 美术规范与 ART04 半写实水粉方向，通过 imagegen 生成及修订。仅文件重命名，未通过脚本修改图像像素。完整提示词见 `prompts.json`。

| 接入文件 | 原验收候选文件 |
| --- | --- |
| inkstone_front.png | inkstone_front_v1.png |
| clay_teapot_front.png | clay_teapot_front_v2.png |
| silk_panel_front.png | silk_panel_front_v3.png |

三个文件均为 1536×1024 RGBA，具有真实透明通道；SHA-256 及生成来源见 `asset-check.json`。旧文件名和概念阶段记录保留在原工作区 `artifacts/item-art-audit-20260922/`。

接入时仅调整运行时尺寸、光照与接触阴影；没有新增鉴定结论或背面细节。其余四类复用 ART06、ART07、ART09 画稿，来源文档与原图保留在对应目录。

## 2026-09-23 试玩反馈修订

内置 imagegen 重绘并接入以下原图，均保留原始 RGBA 像素（1536×1024）；旧画稿仍保留，没有覆盖：

- [holder_front_v2.png](holder_front_v2.png)：沿用烛台轮廓，降低亮金色轮廓与全身高光，转为暗哑旧黄铜。
- [pocket_watch_front_v2.png](pocket_watch_front_v2.png)：原画自带斜视角、可见表壳侧壁与表镜弧度，细表链沿桌面放松摆放。
- [pocket_watch_back_v2.png](pocket_watch_back_v2.png)：同一表壳的闭合背盖、边缝及铰链，不显示机芯或隐藏缺陷。

完整生成及定向修订提示词见 [refinement-prompts.json](refinement-prompts.json)，来源路径、透明通道与 SHA-256 见 [refinement-assets.json](refinement-assets.json)。生成始于 9 月 22 日，运行验收完成于 9 月 23 日。

新怀表在柜台保持原画宽高比，不再纵向压扁；烛台背面与线索图保留原有知识门槛，并在显示时协调高光和饱和度。小碗、银簪和砚台使用既有原图，只调整柜台比例与接触阴影。没有离线修图脚本。

## 银戒指与银锁

2026-09-23 使用内置 imagegen 生成并接入两张正面图：

- [silver_ring_front.png](silver_ring_front.png)：参考 `.artifacts/main/assets/art10/items/silver_ring_front.png` 的器型，重新生成更细、磨痕更轻的素银圈；光线协调至柜台右上方。未修改 main 工作区的原图或代码。
- [silver_lock_front.png](silver_lock_front.png)：小型长命锁坠，刻“長命”传统字形，保留断绳头和银壳厚度。不是门锁。

两图均为 1536×1024 RGBA，戒圈孔洞也有真实透明通道。原始像素不变；[完整提示词](silver-jewelry-prompts.json)、[生成来源与校验](silver-jewelry-assets.json)。背面与鉴定线索仍使用现有资源，不从中性正面图提前泄露隐藏状态。

柜台使用原画比例、短接触阴影及 mipmaps；1280×720 下戒指主体约 28 px 宽、锁坠约 51 px 宽，鉴定页单独放大。实际运行截图和对应场景入口见 [银饰验收](../../docs/qa/silver-jewelry/README.md)。
