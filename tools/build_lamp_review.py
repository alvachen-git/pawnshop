"""Assemble unretouched native screenshots and measure local light/motion."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageStat, ImageChops
import json

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'docs/qa/life-lamp'
font_path = Path('C:/Windows/Fonts/msyh.ttc')
def font(size): return ImageFont.truetype(str(font_path), size)
def mean(image, box): return round(sum(ImageStat.Stat(image.crop(box)).mean) / (3 * 255), 5)

names = ['正常', '轻度缠身', '中度缠身', '高度缠身', '熄灭']
notes = ['暖火自然稳定', '火苗缩短、偏斜，暖光减弱', '火苗泛青，光线进一步变弱', '只余一线细火，桌面暖光收缩', '灯芯冷透，进入绝当录']
sheet = Image.new('RGB', (1620, 714), '#12110f')
draw = ImageDraw.Draw(sheet)
draw.text((24, 20), '命灯 · 个人风险反馈', font=font(34), fill='#d7c297')
draw.text((24, 69), 'v22 实机对照  /  黑窗与暗室基调保持一致', font=font(19), fill='#978a73')
metrics = {}
for i, name in enumerate(names):
    image = Image.open(QA / f'1600_lamp_{i}.png').convert('RGB')
    assert image.size == (1600, 900)
    x = 20 + i * 320
    draw.text((x, 116), name, font=font(24), fill='#d7c297')
    sheet.paste(image.resize((300, 169), Image.Resampling.LANCZOS), (x, 160))
    detail = image.crop((145, 264, 385, 472)).resize((300, 260), Image.Resampling.LANCZOS)
    sheet.paste(detail, (x, 353))
    draw.text((x, 631), notes[i], font=font(17), fill='#a59b88')
    metrics[str(i)] = {'window': mean(image, (271, 75, 341, 155)), 'desk': mean(image, (244, 409, 382, 459)), 'mirror': mean(image, (1030, 110, 1135, 250))}
    for width in (1280, 1600):
        first = Image.open(QA / f'{width}_lamp_{i}.png').convert('RGB')
        second = Image.open(QA / f'{width}_motion_{i}.png').convert('RGB')
        difference = ImageChops.difference(first, second)
        bbox = difference.getbbox()
        metrics[str(i)][f'motion_bounds_{width}'] = bbox
        if bbox:
            # Continuous shader movement stays around the lamp, never fullscreen.
            assert bbox[0] >= width * .11 and bbox[2] <= width * .16, bbox
            assert bbox[1] >= width * .21 and bbox[3] <= width * .25, bbox
    assert metrics[str(i)]['window'] < .02
for region in ('desk', 'mirror'):
    assert all(metrics[str(i)][region] > metrics[str(i+1)][region] for i in range(4)), (region, metrics)
assert metrics['4']['motion_bounds_1280'] is None and metrics['4']['motion_bounds_1600'] is None
draw.text((24, 681), '上：寝屋全景    下：命灯与桌面局部    ·    标签仅用于本次设计评审，游戏内不显示等级', font=font(17), fill='#978a73')
sheet.save(QA / 'lamp-comparison.png')
(QA / 'light-and-motion.json').write_text(json.dumps(metrics, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(metrics, ensure_ascii=False))
