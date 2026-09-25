# 冒牌铭文与机械快门音效 · 本地修订

## 铭文图样

保留原 LIETZ 样本，新增 LETIZ、ERNEST、WETZLRA 三种拼写变化。新生成冒牌机从四款等概率抽取，使用独立 engraving 随机键，保存到 camera_value。已有实物缺少该字段时继续用旧 LIETZ 图，不在查看时重新抽取。原装与拼配图、指南原装参考不变。

内置 imagegen 生成；原图未经二次图像编辑，复制接入 assets/camera_desk/imitation_*.png。逐张检查实际字母，并在 1280×720 与 1600×900 实际界面截图检查。

### letter_swap

输出：`assets/camera_desk/imitation_letter_swap.png`

生成指令：

Use case: precise-object-edit. Asset type: one square macro evidence photograph for a 1930s pawnbroker game. Input image is a reference contact sheet only. Recreate ONLY its top-left camera engraving/mount macro as ONE single square photograph filling the whole output, NOT a grid. Match that top-left crop composition: black leather covered vintage camera front, accessory shoe and partial dial at upper edge, EXACTLY two lines of ivory thin engraved capital lettering centered in upper third, two slotted screws flanking lettering, silver lens mounting ring and dark empty lens opening occupying lower half. Warm subdued workshop light, sharp legible detail, no extra labels or framing. Critical deliberate counterfeit lettering: first line must read exactly "ERNST LETIZ", second line exactly "WETZLAR". These are intentional misspellings for a game; DO NOT correct them. Preserve plausible materials, consistent frontal viewpoint, screw and mount scale, and crop similar to reference top-left. No other printed words. This is a new game sample based on the reference, not an additional scene.

### extra_letter

输出：`assets/camera_desk/imitation_extra_letter.png`

生成指令：

Use case: precise-object-edit. Asset type: one square macro evidence photograph for a 1930s pawnbroker game. Input image is a reference contact sheet only. Recreate ONLY its top-left camera engraving/mount macro as ONE single square photograph filling the whole output, NOT a grid. Match that top-left crop composition: black leather covered vintage camera front, accessory shoe and partial dial at upper edge, EXACTLY two lines of ivory thin engraved capital lettering centered in upper third, two slotted screws flanking lettering, silver lens mounting ring and dark empty lens opening occupying lower half. Warm subdued workshop light, sharp legible detail, no extra labels or framing. Critical deliberate counterfeit lettering: first line must read exactly "ERNEST LEITZ", second line exactly "WETZLAR". These are intentional misspellings for a game; DO NOT correct them. Preserve plausible materials, consistent frontal viewpoint, screw and mount scale, and crop similar to reference top-left. No other printed words. This is a new game sample based on the reference, not an additional scene.

### city_swap

输出：`assets/camera_desk/imitation_city_swap.png`

生成指令：

Use case: precise-object-edit. Asset type: one square macro evidence photograph for a 1930s pawnbroker game. Input image is a reference contact sheet only. Recreate ONLY its top-left camera engraving/mount macro as ONE single square photograph filling the whole output, NOT a grid. Match that top-left crop composition: black leather covered vintage camera front, accessory shoe and partial dial at upper edge, EXACTLY two lines of ivory thin engraved capital lettering centered in upper third, two slotted screws flanking lettering, silver lens mounting ring and dark empty lens opening occupying lower half. Warm subdued workshop light, sharp legible detail, no extra labels or framing. Critical deliberate counterfeit lettering: first line must read exactly "ERNST LEITZ", second line exactly "WETZLRA". These are intentional misspellings for a game; DO NOT correct them. Preserve plausible materials, consistent frontal viewpoint, screw and mount scale, and crop similar to reference top-left. No other printed words. This is a new game sample based on the reference, not an additional scene.


## 音效

根据试玩反馈，已去除程序合成音，替换为 animationIsaac 在 Freesound 发布的 CC0 实录：Camera Shutter Fire: 1930s Rangefinder（234118）。作者说明器材为 1935 年 Contax 旁轴相机，不能称为徕卡Ⅰ型实录。

录音出处：https://freesound.org/people/animationIsaac/sounds/234118/
授权：https://creativecommons.org/publicdomain/zero/1.0/

完整出处、原始下载地址、SHA-256 和剪辑范围见 assets/camera_desk/audio/SOURCE.md。原始 MP3 保留在 source/；游戏接入 recorded_fast、recorded_slow、recorded_sticky_fast、recorded_sticky_slow、recorded_jam 五个 WAV。tools/build_camera_audio.py 仅剪辑真实录音，不生成振荡音。

正常快慢挡使用两段完整实录；迟滞增加停顿，卡住截断动作，后两者属于游戏剪辑效果，不是实测故障录音。音量使用统一倍率并检查峰值不削波。切换画面和声音共用对应时序。未上弦不播放，写盘失败也不开始播放。
