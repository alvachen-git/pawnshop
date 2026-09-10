extends SceneTree

var checks := 0
var failures := 0
var rollback_checked := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var catalog := JsonContentProvider.new(("res://data/market_familiar_manifest.json" if "combined" in OS.get_cmdline_user_args() else "res://data/familiar_early_manifest.json")).load_catalog().catalog
	var definition := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var files := DirAccess.get_files_at(("res://.godot/qa/early_market" if "combined" in OS.get_cmdline_user_args() else "res://.godot/qa/early"))
	check(files.size() >= 100, "actual route checkpoints")
	for name in files:
		if not name.ends_with(".json"): continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(("res://.godot/qa/early_market/" if "combined" in OS.get_cmdline_user_args() else "res://.godot/qa/early/") + name))
		var codec := SaveCodec.new()
		var state := codec.decode(data, definition, catalog.content_version, catalog, true)
		check(state != null, "read " + name + ": " + codec.error_message)
		if state == null: continue
		if not rollback_checked and state.phase == &"closed_processing" and state.visit_history.any(func(r: Dictionary) -> bool: return r.outcome == "redeemed_early"):
			night_rollback(state, definition, catalog)
			rollback_checked = true
		if not data.pawn_tickets.is_empty():
			var bad := data.duplicate(true)
			bad.pawn_tickets[0].redemption_amount += 1
			check(codec.decode(bad, definition, catalog.content_version, catalog, true) == null, "cannot alter redemption amount")
		for record in data.scenario_history:
			if record.command == "early_redeem":
				var bad := data.duplicate(true)
				bad.scenario_history.append(record.duplicate(true))
				check(codec.decode(bad, definition, catalog.content_version, catalog, true) == null, "duplicate early action rejected")
				bad = data.duplicate(true)
				for malformed in bad.scenario_history:
					if malformed.command == "early_redeem": malformed.erase("minute")
				check(codec.decode(bad, definition, catalog.content_version, catalog, true) == null, "malformed early time rejected without crashing")
				break
		if state.phase != &"private_room": continue
		var library := SaveLibrary.new("user://tests/early_checkpoint/%s" % name)
		check(library.write_entry("manual/1", state, definition, catalog.content_version, catalog), "save v18 to shared slot")
		var bytes := FileAccess.get_file_as_bytes(library.path)
		var before := state.to_read_model()
		library.fail_write = true
		check(not library.write_entry("manual/1", state, definition, catalog.content_version, catalog), "failed overwrite")
		check(bytes == FileAccess.get_file_as_bytes(library.path) and before == state.to_read_model(), "slot and state retained")
		library.fail_write = false
		check(library.write_entry("manual/1", state, definition, catalog.content_version, catalog), "retry save")
		var loaded := library.read_entry("manual/1")
		check(not loaded.is_empty() and loaded.catalog.content_version == catalog.content_version, "load matches new content")
	print("EARLY CHECKPOINTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func night_rollback(state: RunState, definition: RunDefinition, catalog: ContentCatalog) -> void:
	var library := SaveLibrary.new("user://tests/early_checkpoint/rollback_%d.json" % Time.get_ticks_usec())
	check(library.write_entry("manual/1", state, definition, catalog.content_version, catalog), "save after early redemption")
	var manager := SaveManager.new("user://tests/early_checkpoint/unused.json")
	manager.library = library; manager.catalog = catalog
	var session := RunSession.new(definition, catalog.content_version, manager, catalog)
	check(library.adopt(library.read_entry("manual/1"), session), "load before night close")
	check(session.execute("wait_until_seal").ok, "advance to seal")
	var before := session.read_state()
	library.fail_write = true
	check(not session.execute("resolve_night").ok and session.read_state() == before, "night failure rolls back redeemed ticket and money together")
	library.fail_write = false
	check(session.execute("resolve_night").ok, "night retry after early redemption")
	var once := session.read_state()
	check(not session.execute("resolve_night").ok and session.read_state() == once, "no double settlement on retry")
