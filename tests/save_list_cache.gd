extends SceneTree

class CountingLibrary extends SaveLibrary:
	var decodes := 0
	func decode_entry(entry: Variant, extended := true) -> Dictionary:
		decodes += 1
		return super.decode_entry(entry, extended)

var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var result := JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog()
	var catalog := result.catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var manager := SaveManager.new("user://tests/cache_legacy.json")
	var lib := CountingLibrary.new("user://tests/save_cache_%d.json" % Time.get_ticks_usec())
	manager.library = lib
	manager.catalog = catalog
	var session := RunSession.new(run_def, catalog.content_version, manager, catalog)
	check(lib.write_entry("manual/1", session._day.state, run_def, catalog.content_version, catalog), "save valid state")
	var rows := lib.entries()
	check(rows[0].valid and lib.decodes > 0, "first list fully validates")
	check(lib._catalogs.size() < SaveLibrary.MANIFESTS.size(), "only compatible versions load")
	var calls := lib.decodes
	check(lib.entries() == rows and lib.decodes == calls, "unchanged list avoids duplicate replay")
	rows[0].detail = "changed UI copy"
	check(lib.entries()[0].detail != rows[0].detail, "UI rows cannot mutate cached data")
	check(not lib.read_entry("manual/1").is_empty() and lib.decodes == calls + 1, "actual load always validates afresh")
	var original := FileAccess.get_file_as_string(lib.path)
	var data: Dictionary = JSON.parse_string(original)
	data.entries["manual/1"].payload.cash += 1
	var file := FileAccess.open(lib.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	check(not lib.entries()[0].valid, "changed content invalidates cached summary")
	check(lib.read_entry("manual/1").is_empty(), "tampered content still rejected on load")
	file = FileAccess.open(lib.path, FileAccess.WRITE)
	file.store_string(original); file.close()
	check(lib.entries()[0].valid, "restored valid content displays correctly")
	var prior := FileAccess.get_file_as_string(lib.path)
	lib.fail_write = true
	check(not lib.write_entry("manual/1", session._day.state, run_def, catalog.content_version, catalog), "failed publication is rejected")
	check(FileAccess.get_file_as_string(lib.path) == prior and lib.entries()[0].valid, "failed publication preserves file and summary")
	print("SAVE LIST CACHE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
