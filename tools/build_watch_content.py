"""Isolated v33 content; never rewrite released v32 saves or definitions."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
def write(p, data):
    target = ROOT/p
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
run = read('data/tiered/run.json')
run['records'][0]['id'] = 'watch_ten'
run['records'][0]['variety']['watch_appraisal_version'] = 1
write('data/watch/run.json', run)
items = read('data/wealthy/items.json')
for item in items['records']:
    if item['id'] == 'item_luxury_gold_watch':
        item['display_name'] = '百达翡丽猎壳金怀表'
        item['description'] = '客人称是百达翡丽出品。金壳带护盖，白珐琅盘下另设小秒盘。'
write('data/watch/items.json', items)
manifest = read('data/tiered_manifest.json')
manifest['content_version'] = 33
manifest['default_run_id'] = 'watch_ten'
for source in manifest['sources']:
    if source['path'] == 'res://data/tiered/run.json': source['path'] = 'res://data/watch/run.json'
    if source['path'] == 'res://data/wealthy/items.json': source['path'] = 'res://data/watch/items.json'
write('data/watch_manifest.json', manifest)
