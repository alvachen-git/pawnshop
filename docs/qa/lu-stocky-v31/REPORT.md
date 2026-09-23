# 陆掌眼矮胖版 · 2026-09-23

根据用户“可以再矮胖些”的反馈，使用内置 ImageGen 编辑上一张立绘，保留脸部身份、灰白鬓发、温和神态、棉布马甲和双手姿势，加厚肩腹、上臂和脸颊，缩短颈部与躯干。绘制框高度由柜台区域的0.50降到0.46（约低26像素/1280窗口）；保持纹理等比显示，未横向拉伸原图。柜沿位置与龙凤镯大小不变。

素材：[透明PNG](../../../assets/first_debt/lu_zhangyan_stocky.png) · [完整编辑提示词](../../../assets/first_debt/lu_zhangyan_stocky.prompt.txt) · [来源与校验值](../../../assets/first_debt/lu_zhangyan_stocky.source.json)。旧立绘保留，代码指向新版。

实际窗口用`tests/lu_bangle_art_ui.gd -- stocky`及`-- stocky wide`检查。对照图以相同存档/视口显示上版与新版，仅临时切换绘制属性；不影响玩法或存档。

[1280改前](1280-before.png) · [1280改后](1280-lu-counter.png) · [1600改前](1600-before.png) · [1600改后](1600-lu-counter.png)

1280×720、1600×900实际窗口各54断言通过、0失败，日志归档在`logs/`。助手目视对照确认头顶降低、肩腹更圆厚，手仍收在柜台后方，报价/回应/离场正常。此次为美术调整，未重跑无关的剧情与长局回归。
