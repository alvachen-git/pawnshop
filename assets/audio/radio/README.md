# 当铺收音机：苏州评弹本地试听版

`programme.wav` 取自真人苏州评弹录音，替换了上一版合成小曲。无合成报时，无原背景音乐。保留唱腔与伴奏，使用单声道、420–2450 Hz 频段、中频喇叭共振、扬声器失真和缓慢的小幅音量波动，模拟店内旧收音机。已移除额外叠加的电流嘶声、50 Hz 嗡声及突发干扰，原录音自带的现场环境声仍保留。

截取源录音 3.5–157.5 秒，以 4 秒首尾交叠形成约 150 秒循环。每次从头播放先完全静音 5 秒，再以 1 秒淡入评弹；Godot 的循环起点设在第 6 秒，后续循环不重复静音。成品总长约 156 秒。游戏沿用 -14 dB 音量；独立试听文件为了方便听清，未施加游戏的音量衰减。

营业且当铺界面可见时，22:00 前播放评弹；到 22:00 时用 5 秒渐弱结束，之后不再播放滴答背景音；关店仍保持 5 秒渐弱。报时播放器及四段报时音频已经移出游戏资源目录。

## 素材署名与许可

- 作品：**Pingtan Treasure**
- 录音者：**Jason M. C., Han**
- 录音日期：2017-11-01；苏州姑苏区现场实录，非民国原始电台录音。
- 来源：https://commons.wikimedia.org/wiki/File:Pingtan_Treasure.ogg
- 来源版本：https://commons.wikimedia.org/w/index.php?title=File:Pingtan_Treasure.ogg&oldid=1261539237
- 下载：https://upload.wikimedia.org/wikipedia/commons/3/3d/Pingtan_Treasure.ogg
- 源文件 SHA-1：`08a03f47a3c4fdcff8f434b3c964384dbd9e984a`
- 页面标注许可：**Creative Commons Attribution-ShareAlike 4.0 International**
- 许可：https://creativecommons.org/licenses/by-sa/4.0/
- 许可全文：https://creativecommons.org/licenses/by-sa/4.0/legalcode.en
- 本次改动：截取、混为单声道、滤波、压缩、响度处理、收音机失真/缓慢音量波动（已移除添加的电流噪声与突发干扰）、循环交叠、5 秒静音及 1 秒淡入开头；没有添加报时，没有声称录音者或演出者为游戏背书。
- 本目录的改编音频及其试听片段沿用 **CC BY-SA 4.0**。分发时须保留署名、来源、许可、改动说明及相同许可。

### 发行前待确认

来源页录音者只明确提到现场允许游客录音，未提供两位演出者姓名、曲目名称或演出/词曲的再利用授权证明。页面许可不能据此被表述为所有权利均已清理。本素材已按用户要求纳入仓库；底层演出及曲目的再利用授权仍待确认，正式游戏发行前须确认或替换为有完整授权的录音。Windows 打包脚本将本说明复制到包内 licenses/Pingtan-radio-source.md，保留可供玩家阅读的署名、许可及改动说明。

## 重新生成

需要 `ffmpeg` 和 Python 3。先从上述公开下载地址获取源文件，然后运行：

```sh
python3 tools/create_shop_radio_audio.py /path/to/Pingtan_Treasure.ogg
```

生成工具校验源录音 SHA-1，输出 `programme.wav` 及 `.artifacts/radio-audio/pingtan_radio_clean_preview.wav`，无运行时网络依赖。
