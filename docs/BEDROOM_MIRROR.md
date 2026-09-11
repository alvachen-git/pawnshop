# 寝屋镜子组件

## 使用与试玩

正常游戏与 `试玩寝屋.cmd` 已使用独立镜子。双击根目录 `预览镜面异象.cmd` 可单独切换正常、灯灭、起雾、扭曲、慢半拍。这个预览没有 RunSession，不读写游戏存档；右下角关闭预览。

正式寝屋只保留正常倒影与命灯联动。本次没有新增异象触发条件、遭遇、损失或存档字段。人影和裂纹目前是可插入的美术图层接口，不是已经制作完成的剧情效果。

## 空间与素材

沿用紧凑衣柜版机位。右侧镜子位于远墙，同墙衣服、墙画及床头不直接出现在倒影里。正常镜面采用对面偏右墙角、灰泥和低木墙裙，不再出现来源不明的柜架、独立暖色光球。

这是固定机位的二维绘制倒影，不是三维实时反射。今后更改镜子位置、机位或房间平面布局时，需要重新校准倒影。命灯不直接处于镜面视野内，只改变间接暖调；熄灯后镜面褪暖并变暗。

- `assets/bedroom/mirror/reflection-normal.png`：内置 image_gen 生成的正常倒影。按纵向镜面等比适配；mipmap 平滑缩小后的笔触，避免高频噪点。
- `assets/bedroom/room-shell.png`：内置 image_gen 移除整面镜框与镜面后的旧墙。背景 shader 只取原镜子范围，其他房间像素仍来自已批准底图。
- 镜框仍准确采样 `room-normal.png` 中原有木框，由独立 Frame 节点显示；玻璃开口在 frame shader 中镂空。无需重画已批准的木框。
- `surface.gdshader`：旧银镜的低饱和调色、间接灯光、雾与局部折射。

生成提示词约束：保持原寝屋所有家具位置、机位、1672×941画幅和水粉材质；shell 仅移除右侧整面镜子并补墙。reflection 仅显示无人物的对面墙角和低木墙裙，无镜框、挂衣、柜架、灯具、光球或异象。两张均使用内置工具，非外部 API。

## 独立结构

场景 `ui/room/bedroom_mirror.tscn`，脚本 `BedroomMirror`：

```
BedroomMirror
├─ Glass（限制绘制在镜内）
│  ├─ Reflection（正常或替换倒影）
│  └─ Phenomena（人影、裂纹等透明纹理）
├─ Frame（固定木框）
└─ HitTarget（观察、悬停、键盘焦点）
```

每个实例拥有独立 ShaderMaterial。`reset()` 清除异象、替换纹理、叠加纹理和待执行的延迟更新。场景离开时也会 reset，防止下次进入残留异象。

## 给后续剧情接入

`PrivateRoomView.render(model)` 接受可选 `model.mirror` 字典，转交 `BedroomMirror.set_state()`。当前 Presenter 不发送异象，因此常态不会随机变化。命灯开关由现有 `model.dead` 统一提供，死亡立即复位为正常熄灯镜面。

| 字段 | 作用 |
| --- | --- |
| `mode` | `normal`、`fog`、`ripple`、`delayed`；未知值按正常处理 |
| `strength` | 雾或扭曲强度，限制0–1 |
| `lamp_lit` | 组件的间接暖光开关；在正式寝屋由宿主提供 |
| `delay_seconds` | 延迟更新0–3秒，默认0.65；新状态会取消过期请求 |
| `reflection_texture` | 可替换整个镜内画面，传 Texture2D |
| `overlay_texture` | 镜内透明叠加纹理，供人影、裂纹等使用 |
| `overlay_opacity` | 叠加透明度0–1 |
| `description` | 可选的本次异象观察文案，与可见状态一起更新 |

示例（剧情代码组装画面模型，组件不决定剧情后果）：

```gdscript
model.mirror = {"mode": &"fog", "strength": 0.65,
    "description": "镜面浮起一层薄雾，对面的墙角渐渐看不清了。"}
# 恢复：下一次 model.mirror = {}。
```

`delayed` 指延迟提交倒影状态，不是录制人物动作的视频缓存。后续需要人物倒影慢半拍时，由人物表现层提供纹理帧或状态快照，再通过此入口提交。剧情触发、保存与恢复仍由 RunSession/Presenter 所属逻辑负责，不能把组件临时状态当作存档。

检查记录见 [镜面 QA](qa/bedroom-mirror/design-qa.md)。本轮未推送。
