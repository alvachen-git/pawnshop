# 工艺素材来源与制作约束

使用内置 imagegen，最终文件位于本目录，每张 RGBA 原图直接复制接入，没有做程序像素加工。regions.json 仅指定 Godot 从哪一区域取图；tools/porcelain_craft_regions.py 只分析 alpha 连通区域，排除邻格残片并保留接触阴影，不修改 PNG 像素。

16 套图集 × 3 工艺 × 7 视图 = 336 个展示区域。列从左至右为粗工、常品、精工；行依次为正面、右侧、背面、左侧、绘纹、底足、柜台。粗工不使用额外模糊着色器，常品不再与精工共享整器图。保持外伤单独判断，不增加修补玩法。

## 首批普通样本

原图目录：C:/Users/alvachen/.codex/generated_images/01a0c8e1-5d71-7373-a439-546928f9c776/

|最终文件|原始文件|
|---|---|
|ming_a_ordinary.png|exec-3162f926-bdea-4865-906d-6688390c5e62.png|
|ming_b_ordinary.png|exec-29fc4ea9-1c2b-4507-b3e3-288ffb4f39b4.png|
|yuan_a_ordinary.png|exec-be493950-0f06-4c00-a5e0-a5fd8e495982.png|
|yuan_b_ordinary.png|exec-2f878e22-0e6b-44e7-a5ed-ebd8bdca29cc.png|
|republic_a_ordinary.png|exec-8bf6a4f5-29e2-4fd9-8c5f-44bc9f6000ab.png|

其余 11 张的独立提示词与原始路径在相邻 *.prompt.md。废弃的模糊、错器形或截断版本没有接入。

## 提示词约束（首批与后续统一的最终设计规格）

Generate an actual transparent game sprite atlas, NOT poster/UI. EXACTLY 3 COLUMNS x 7 ROWS, 21 sprites, tall 3:7 aspect, largest available resolution (1536x3584 desired). True transparent alpha outside porcelain. Each equal cell has 6% empty margin. No text/labels/borders. Chinese antique blue-white porcelain, realistic painterly glazed material, equal sharp focus everywhere. ALL columns depict the SAME vessel design, SAME motif and era, three workmanship levels visibly different in the ENTIRE vessel as well as closeup.
LEFT ROUGH: clearly lopsided motif elements, thick wobbly SHARP contours, blue pigment patches visibly overshoot distinct drawn outlines, uneven band spacing; foot has obvious uneven tool facets and uneven glaze boundary, NOT chips/cracks/dirt. Show actual badly executed drawing not blur.
CENTER STANDARD: competent balanced forms, simple smooth outlines, FLAT single-tone fill neatly in bounds, just ONE simple inner detail stroke per leaf/petal/feather, ordinary trimmed foot with slight tooling.
RIGHT FINE: masterful tapered contours, 4-5 individually visible fine parallel INNER VEINS/FEATHER STROKES or tiny architectural strokes, narrow intentional white channels, sophisticated light-dark wash within precise edges, beautiful rhythmic spacing and neatly finished foot. Same motif, not gold/extra luxury ornaments.
Differences should be easy to see without labels; standard much SIMPLER than fine. Rough macro must be just as sharp as fine: absolutely no camera blur/mottled wear/artificial blur effect. Match each full vase's workmanship to its own macro and foot.
ROWS exactly: 1 front whole vase; 2 right-quarter rotated whole vase; 3 rear whole vase; 4 left-quarter rotated whole vase; 5 large circular enlarged macro of that SAME motif section per column; 6 circular underside foot view, retain coherent matching foot shape; 7 full vase mildly viewed from above, visible inside mouth, with attached soft floor contact shadow toward right. Each column stays same piece across all rows. No cracks/repairs. No clipping last row. 7 rows ONLY, not 8.
All whole vases are real pear-shaped YUHUCHUN, NOT jars/meiping: long visibly narrow neck, outflared mouth, broad rounded low belly, taper to small foot. Neck length at least one third of vase height. Width maximum around two thirds down from lip. Height approx 2x belly width. Painterly realistic 3D ceramic sprites, blue-white glaze, warm neutral lighting.

## 各样本图案要求

- 元 A：广撇口、低垂腹、低圈足、云龙；龙鳞排列与填色控制分三档；元困难版仅弱化年代线索，不仿后世。
- 元 B：广撇口、低垂腹、缠枝牡丹；粗工不规则花瓣、常品简洁平填、精工细密花瓣内纹。
- 明 A：早期长颈垂腹，颈肩足部分层，缠枝莲；粗工画歪填色越界、常品单线平填、精工四五条细线与留白。底足收边独立体现三档。
- 明 B：竹石，分层边饰；放大同一竹叶接干处，粗工粗糙不匀、常品单叶脉、精工细线与白隙。
- 清 A：芭蕉竹石；同一叶片从不匀轮廓到单中脉、细密平行叶脉；较饱满腹部、方框款示意。
- 清 B：小莲缠枝，颈腹比例与方框款；精工叶脉、收笔与填色明显精细。途中罐形误差版已弃用。
- 民国 A 普通：疏枝花鸟、素净颈部；三档羽毛和花瓣执行差异，底足较平。困难版仿明莲纹但保留现代样本足底观察依据。
- 民国 B 普通：留白山水、柳亭、素净长颈；三档屋檐、柳叶笔线差异。困难版仿明竹石，与普通版分开固定生成。

不把花纹复杂度、旧色、画面清晰度单独当作年代或工艺结论。这是教学游戏样本，非馆藏复刻或真实鉴定标准；价值仍读取生成时保存的事实。

