# v25 侧视陪伴资产记录

本批可玩草图，使用 imagegen 技能和内置 imagegen 工具。最终文件：`assets/aqi/companion-side.png`，1280×1280 RGBA；原生成文件保留于 `/Users/alvachen/.codex/generated_images/01a08f6d-f5ec-7460-8b00-17e2b157dae1/exec-e9a4d70f-0764-4525-9436-311a98f5af9e.png`。

首轮参考 `assets/aqi/counter-aqi-resting.png`，提示词：

> Create a new game sprite variant of this exact fictional 9-11 year old Chinese girl, preserving her facial identity, tidy twin braids with small dark red ties and jade-green neat Republican-era Chinese jacket with cream collar. NEW POSE: seated on the LEFT side of an antique pawnshop counter, seen in three-quarter SIDE PROFILE facing RIGHT, head tilted slightly upward looking attentively at an adult customer to her right. Curious innocent warm lively eyes, subtle natural smile, not vacant. Only her complete head, braids, neck and a SMALL amount of collar/upper shoulders in the sprite; no arms, no hands, no desk, no props. This is a small background companion sprite, not a frontal portrait. Keep recognizable painterly realistic game-art style with soft warm light from upper right, no ragged clothes, no ghost cues. One single isolated sprite centered filling approximately 80 percent canvas height with comfortable space around hair, transparent background with actual alpha, no frame, no text. Do not include the pink background of the reference. Save the generated file for integration into a Godot game.

首轮图姿态合适，但背景含棋盘纹。第二轮以首轮为参考，要求纯品红替换背景：

> Edit ONLY the background of this game character sprite. Replace every gray/white checkerboard background square with one perfectly uniform flat pure magenta #FF00FF background. No checkerboard, no gradient, no shadow on background. Keep the exact same girl, side-facing-right pose, face, hair, clothing, size, placement and rendering unchanged. This is a chroma-key sprite for a game. Maintain clean hair edges. Single image.

工具第二轮实际返回可用alpha透明图，已用 `sips -g hasAlpha` 核实，并在实际Godot窗口检验边缘。直接复制结果，未做程序抠图或图像合成。身体下缘由柜台View遮挡，鼠标范围比头部稍大。无新增手臂或桌面接触关系。
