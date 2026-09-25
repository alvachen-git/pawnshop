# 留声机试听音源 · 修订

当前运行时使用真实早期唱片录音，不再使用现代钢琴素材。

- 曲目：**Waiting**，器乐舞曲。
- 乐队：Joseph C. Smith's Orchestra；指挥 Joseph C. Smith；作曲 Harold Orlob；编配 George A. Cragg。
- 录音日期：1919-08-12，纽约。
- 厂牌 / 唱片号：Victor 18615，矩阵 B-23205，take 1。
- 馆藏条目：https://www.loc.gov/item/jukebox-33811/
- 可下载数据集：https://data.labs.loc.gov/jukebox/
- 原文件：https://data.labs.loc.gov/jukebox/audio/jukebox-33811_1.mp3
- 文件：`source/victor-18615-waiting-1919.mp3`，附馆藏元数据 `source/metadata.json`。
- MD5：a37d2e2285c4d5a6d3742778acb9604b（与图书馆清单一致）。
- 授权依据：图书馆 National Jukebox 数据包说明，其收录的 1900—1922 年唱片按美国法已进入公有领域。核验于 2026-09-25。本记录采用该数据包，不将整个 National Jukebox 的其他年代内容视为同一授权。

## 游戏处理

截取原曲 12—36 秒的连续片段，单声道，保留历史录音本有的表面噪声。轻度削低频和高频、突出中频，模拟小型号筒声音；不添加现代立体声或长混响。正常声音不是无噪音的现代高保真，也不是“只要有杂音就坏”。

发声异常另叠加振膜破音或闷弱处理；损坏唱片的周期性爆豆与沙沙层独立于机器，六种输出使用相同划痕时间及波形。破音的平均响度与正常音校准一致；闷弱保留其本身偏弱的效果。转速不稳和停转由运行时同步改变音高与转盘速度。

`tools/build_gramophone_audio.py` 可复现全部 WAV，依赖 numpy、soundfile；可用 `GRAMOPHONE_AUDIO_DEPS` 指向本地库目录。输出时长 23.9 秒，循环边界交叉衔接；Godot 直接循环 PCM，直到玩家抬针或机械状态导致停转。指南、正常对照与实物共用音源和播放规则。输出校验值与音量统计见 `BUILD_REPORT.json`。

`piano_mamax_44355.mp3` 是上一轮保留的 CC0 来源，不再用于运行时。原出处 https://freesound.org/people/mamax/sounds/44355/ ，作者 mamax，CC0 1.0。
