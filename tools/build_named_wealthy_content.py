"""Freeze v36 saves; start fixed wealthy characters in v37."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def read(path):
    return json.loads((root / path).read_text(encoding="utf-8-sig"))

def write(path, value):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

run = read("data/watch_patterns/run.json")
run["records"][0]["id"] = "named_wealthy_ten"
run["records"][0]["variety"]["wealthy_fixed_people"] = 1
write("data/named_wealthy/run.json", run)
manifest = read("data/watch_patterns_manifest.json")
manifest["content_version"] = 37
manifest["default_run_id"] = "named_wealthy_ten"
for source in manifest["sources"]:
    if source["path"] == "res://data/watch_patterns/run.json":
        source["path"] = "res://data/named_wealthy/run.json"
write("data/named_wealthy_manifest.json", manifest)
