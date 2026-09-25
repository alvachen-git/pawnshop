# 开场「入巷见铺」视觉验收

final result: passed

## Visual truth and capture

- Selected source: `/Users/alvachen/.codex/generated_images/01a0c923-8e99-7c61-a112-29ab760aa9df/exec-ef130714-57cd-48f7-83fd-781340819032.png` (1672×941).
- Source copy is an ideation mock; actual runtime keeps the full authored arrival narration, including its middle paragraph.
- Implementation: `docs/qa/opening-art/1600_shop_arrival.png` (1600×900) and `1280_shop_arrival.png` (1280×720).
- Native Godot OpenGL game screenshots; browser/CSS/devicePixelRatio do not apply. Both viewport and captured pixels are exactly the named dimensions. Near-identical 16:9 image ratios are rendered with aspect preserved. The source and 1600 screenshot were opened together in the same comparison tool input, judged at equivalent full-frame scale.
- States inspected: factory paycut, photograph, wedding, letter, memories, stamp, arrival, inspection, accounts, first customer, room before/after photo and sleep. All screenshots in the same directory; no browser mock substitutes.

## Required fidelity surfaces

- Fonts/typography: shared Songti/STSong/SimSun/Noto Serif system display font with bundled Noto Sans SC fallback. Body22 at720h and28 at900h, warm paper foreground; complete words retained. Chinese smart wrapping and clipping explicitly set. Long letter visibly scrolls, including its end. Cross-platform font substitution remains a known minor visual difference.
- Spacing/layout: original street/counter composition preserved; live UI uses full-frame illustration, bottom reading field and paper action. Authored extra arrival paragraph makes the reading field moderately taller than the two-line concept. No clipping or off-screen actions at either resolution. Multi-choice scenes reserve a separate action column.
- Colors/tokens: dark wood/soot/olive image palette, muted ivory text, existing paper button texture. Readability scrim remains separate from art. No gold trim or new decorative UI system.
- Image quality: eight1672×941 built-in imagegen paintings. Foreman was revised at user's request to distinguish him from merchant faces. Skin/hands/material and purse scale reviewed in `1600_factory_paycut.png` and the source `assets/opening_art/factory-v2.png` together; full-size character and button/text details are readable without a separate crop. Background aspect preserved. Night room uses existing lamp-exposure convention and dark exterior panes.
- Copy/content: all dialogue, action labels and outcomes come from existing event model. Only empty-line spacing changes in compact captions. No invented mechanics, tooltips or outcome labels. Account figures still present and scrollable when longer than caption field.

## Findings and fixes

1. [P2 resolved] Initial factory composition placed purse under reading area. Painting shifted upward by8.5% of viewport height without stretching; final purse/hand are fully visible, head remains in frame. A solid base prevents underlying counter status leaking through the shifted background. Evidence: `1280_factory_paycut.png`, `1600_factory_paycut.png`.
2. [P2 resolved] Large blank paragraph gaps made short scenes occupy too much of the painting and caused first-customer instructions to scroll. Compact paragraphs now use single newlines, explicit Chinese wrapping and clipped text bounds. Evidence: both `shop_arrival`, `first_customer`, `room` captures.
3. [P2 resolved] Foreman looked too similar to ordinary guests. Replaced original image with user-directed `factory-v2.png`: broader jaw and shoulders, short hair, hard brow and pressed lips. Original preserved in ignored draft directory, not used by runtime.
4. [P2 resolved] Reused room source showed daylight at03:00. Applied existing bedroom exposure and window masking, keeping ordinary mirror and lamp unchanged. Evidence: `1280_room.png`, `1600_room.png`.

The final full-view comparisons contain no remaining actionable P0/P1/P2 findings. Residual P3: OS font fallback can change stroke style; Windows appearance has not been accepted.

## Interaction evidence and limits

- Core opening tests:100 assertions/0 failures.
- Current-manifest native UI:143 assertions/0 failures at each resolution, seed42. Mouse controls, initial keyboard focus, long-letter scroll, mid-opening reload state equality, first trade, room choices, sleep and replay skip verified. Runtime logs contain no script/render errors.
- Earlier random-seed trial had an end-of-night transition assertion fail; final targeted UI fixture uses deterministic seed42, not a claim of exhaustive random-night validation. Game rules were not edited to make tests pass.
- No full-game, Windows/export or real-user acceptance claim.

## Implementation checklist

- [x] Selected visual and8final raster assets integrated.
- [x] Preserve story commands, gates and serialized state.
- [x] Correct foreground readability and source-art visibility.
- [x] Native1280×720 and1600×900 flow, screenshots and log checks.
- [x] Document prompt/source hashes and direct isolated review command.

## 试玩修订复验 · 照片、喜帖、回忆

Source truth: 用户11:36:15、11:36:46、11:37:49三张截图及明确反馈，文件位于用户提供的NSIRD_screencaptureui临时目录；项目原图`assets/opening_art/photo.png`、`memory.png`。

Implementation: `docs/qa/opening-art/1280_manqing_memory.png`、`1600_manqing_memory.png`、`1280_gu_value.png`、`1600_gu_value.png`、两分辨率`gu_people`/`gu_flashbacks`/`decision`。原memory画面和1600实机暗淡版本在同一工具输入直接对照；全尺寸图能读清面部、姓名和按钮，不需要另行裁图。

- [P2 resolved] 两次生成导致女孩表情变化：两节点现在使用同一photo.png；UI测试对旧照片人脸区域逐像素比较，两分辨率通过。
- [P2 resolved] 喜帖简体：内置imagegen重做姓名为姚曼卿、陸紹廷；正文引用同步。场景只使用喜帖轮廓，避免重新生成的人脸混入。首轮采样出现矩形裤面接缝，改为纸张轮廓及窄接触阴影后消失。
- [P2 resolved] 回忆与现实未区分：三段顾叔童年回忆统一低饱和、压暗与轻微暗边；仅作用背景，正文和按钮保持原色。回到现实恢复正常，首笔真实成交不会套回忆滤镜。
- 两分辨率各143断言/0失败；开场剧情、读档与首夜流转复验通过。未改剧情条件或存档格式。1280复验曾出现合成点击跨帧漏点及100秒超时；测试改为同帧完整按下/释放、允许300秒并记录逐段事件后，最终全流程通过（ui-1280.log）。

final result: passed

## 周婶引导复验

用户13:38截图作为问题依据。原「观察」已改为实际入口「鉴定」，两种分辨率的neighbor_page_1至5均已输出。人工查看1280第2/3/5页、1600第1/4页：姓名、关系、教学内容及回应按钮清楚，一屏可读。柜台固定姓名为周秀英（周婶）。两分辨率187/0，核心100/0；未新增来访调度。

final result: passed
