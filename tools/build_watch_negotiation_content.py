"""Generate v35 while preserving v34 definitions and save routing."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def read(p): return json.loads((root/p).read_text(encoding='utf-8-sig'))
def write(p, value):
    target = root/p
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
run = read('data/watch_market/run.json')
run['records'][0]['id'] = 'watch_negotiation_ten'
run['records'][0]['variety']['watch_negotiation_version'] = 1
write('data/watch_negotiation/run.json', run)
manifest = read('data/watch_market_manifest.json')
manifest['content_version'] = 35
manifest['default_run_id'] = 'watch_negotiation_ten'
for source in manifest['sources']:
    if source['path'] == 'res://data/watch_market/run.json': source['path'] = 'res://data/watch_negotiation/run.json'
write('data/watch_negotiation_manifest.json', manifest)
