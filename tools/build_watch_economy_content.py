"""Build v34 without rewriting the v33 catalog."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def read(path): return json.loads((root/path).read_text(encoding='utf-8-sig'))
def write(path, value):
    target = root/path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
run = read('data/watch/run.json')
run['records'][0]['id'] = 'watch_market_ten'
run['records'][0]['variety']['watch_economy_version'] = 1
write('data/watch_market/run.json', run)
manifest = read('data/watch_manifest.json')
manifest['content_version'] = 34
manifest['default_run_id'] = 'watch_market_ten'
for source in manifest['sources']:
    if source['path'] == 'res://data/watch/run.json': source['path'] = 'res://data/watch_market/run.json'
write('data/watch_market_manifest.json', manifest)
