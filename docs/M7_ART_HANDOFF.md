# 三笔交易 · 12张图交接清单

状态：待专职美术交付。2026-09-04接手继续开发时，没有生成新图，没有将对话中的生成样图导入项目。当前已有ART02低保真图仅用于功能验证，不算本清单的正式交付。

遵循 `设计/鬼市当铺_美术设计规范_V0.2.docx` 与 `设计/鬼市当铺_UI线框规范_V0.1.docx`：民国上海旧物、低饱和、旧木／纸／铜料质感，物体轮廓清楚；恐怖不靠血腥或鬼脸，本组三笔均为普通交易。不要把UI文字画进图片。

## 交付约定

建议工程交付为PNG，源图至少1024×768，主体置于中央安全区域，正面图使用透明背景，背面／细节可使用同一中性深底。它是本轮建议的接口规格，并非原美术规范指定尺寸；保留美术源文件。渲染采用等比完整显示，无像素热点、拖拽或额外侦探板。

建议路径：`res://assets/trade_samples/`。将下表文件落到目录后，在 `data/runs/p0_judgement.json` 对应情境的 `images` 条目填写 `path`。不要改ID、物证或解锁条件；图片无需写进存档。

| 文件名 | 情境 / 图ID | 应画内容 | 解锁条件 |
| --- | --- | --- | --- |
| bowl_front.png | bowl_testimony / front | 青花小碗正面，器型、纹样和釉色；无可辨接缝 | 初见即有，两种品相共用 |
| bowl_back.png | bowl_testimony / back | 同一碗翻转背面，底足整体；不作可辨补釉或磨损特写 | 初见即有，两种品相共用 |
| bowl_sound_detail.png | bowl_testimony / sound | 同一侧光角度，釉面连续、纹样连贯 | 侧光检查获得 intact |
| bowl_repaired_detail.png | bowl_testimony / repaired | 同位置细接缝、补釉与缝边青花轻微错位，不画成新鲜大裂口 | 侧光检查获得 repair |
| holder_front.png | holder_material / front | 黄铜色烛台，轮廓完整；不暴露铁芯 | 初见即有，两种材质共用 |
| holder_back.png | holder_material / back | 同一烛台背面／底部整体，旧划痕不可细辨内部颜色 | 初见即有，两种材质共用 |
| holder_brass_detail.png | holder_material / brass | 底部旧划痕内部仍为黄色铜料 | 划痕检查获得 brass_core |
| holder_plated_detail.png | holder_material / plated | 相同划痕位置，薄铜皮下灰色铁芯清楚可辨 | 划痕检查获得 iron_core |
| watch_front.png | watch_circumstance / front | 同一只怀表表盘、表壳与表链；不给走时或急售答案 | 初见即有，四种组合共用 |
| watch_back.png | watch_circumstance / back | 闭合表背，不提前展示机芯 | 初见即有，四种组合共用 |
| watch_sound_detail.png | watch_circumstance / sound | 开盖后的同一机芯，轴孔无明显磨损 | 机芯检查获得 sound |
| watch_flawed_detail.png | watch_circumstance / flawed | 相同机芯与角度，轴孔磨损可辨 | 机芯检查获得 flaw |

## 不泄露与图文配合

- 每件正背面共用文件；不要为完好、修补、普通或急售暗换光线、颜色、摆放、表链、标记。
- 碗底足可免费翻看整体，但辨自然磨损与款式仍是正式放大镜检查；背面图不能用大特写替玩家完成取证。
- 磁针只提供磁性相关文字证据，不解锁划痕图。本轮12张没有磁针专图；看到磁针吸附并不表示已经看过划痕。
- 怀表静态图只能画磨损等可见细节。“时走时停”仍由检查文字说明，不以静帧假装证明动态走时。
- 正式图完成后需在1280×720与1600×900实际检查缩小后的可辨性。保留三笔全部品相、怀表四种组合截图；确认新旧细节没有重复视图。
- 交付前的文字证据测试已可进行；12图一致性与最终视觉验收必须在真实素材到位后补做，当前不标完成。
