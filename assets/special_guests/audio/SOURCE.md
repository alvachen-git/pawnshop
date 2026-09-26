# 卧房持货异响

滴水：Independent.nu，qubodup 上传；CC0。
https://opengameart.org/content/dripping-water-loop
附件：https://opengameart.org/sites/default/files/atmosbasement.mp3_.flac

木响与摩擦：从本项目 assets/opening/wooden_door_open.wav 剪辑、降调；原始来源与授权见 assets/opening/WOODEN_DOOR_SOURCE.md。

成品采用短段、低通、淡入淡出及低音量播放，无突发尖叫。

核对日期：2026-09-25。未采用需另行获取的 Breviceps 木响候选，按方案使用项目已有的 CC0 木门声音。

剪辑参数（44.1kHz、PCM16）：滴水截取源文件1.00—7.25秒，低通1800Hz；木响取木门0—1.70秒，以0.7倍速并低通1000Hz；摩擦取0.35—1.75秒，以0.45倍速并低通550Hz。均做淡入淡出，加入约150ms低比例延迟；运行时增益-20dB。各成品没有削波，运行录音峰值约0.061。低通、慢放和轻微延迟用于营造隔层传来的距离感。

素材试听入口为根目录 `preview-special-guests-sound.cmd`；带原运行声音的预览见 `.godot/qa/special-guests/bedroom-preview.mp4`。听感由试玩时确认，客观音量和播放间隔数据见同目录 `audio-verification.json`。

SHA-256：
- `dripping-source.flac`: `247c0ef181c8ba8d190a6194f6ea02d9defb23b70194c52c7f9187b5b7b1cc61`
- `drips.wav`: `0f666c6005e0147714de1f48bf0bda7039fd2020e45e5c837a323572644d7d7b`
- `rustle.wav`: `3eeb5c22885cece5f2138bd18097b565b7271e6af48ddec6288b17a7475e1373`
- `wood.wav`: `d1c9114ea81a0d849a0a3a3b4b0d88668fe6eb5a5a04f90a041c840b2d1f59ba`
