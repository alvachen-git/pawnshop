extends SceneTree

const QA := "res://.godot/qa/pawn_chance/"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL " + message)

func run() -> void:
	var catalog := JsonContentProvider.new("res://data/pawn_chance_manifest.json").load_catalog().catalog
	var run_def := catalog.get_definition("runs", catalog.default_run_id) as RunDefinition
	var library := SaveLibrary.new(QA + "process_library.json")
	if "read" in OS.get_cmdline_user_args():
		for key in ["manual/1", "auto/pawn_chance_seven", "manual/2", "auto/market_familiar"]:
			var entry := library.read_entry(key)
			check(not entry.is_empty(), "cross-process shared library " + key)
			if entry.is_empty(): continue
			check(entry.catalog.content_version == (19 if key in ["manual/2", "auto/market_familiar"] else 20), "matching content version")
		var manager := SaveManager.new(QA + "unused.json"); manager.library = library
		var session := RunSession.new(run_def, 20, manager, catalog)
		check(library.adopt(library.read_entry("manual/2"), session) and session.content_version == 19, "load old run")
		session.new_run()
		check(session.content_version == 20 and session.definition.id == "pawn_chance_seven", "new game after old save restores default")
	else:
		for route in ["keep", "transfer", "higher", "pressure"]:
			for night in range(1, 8):
				for stage in ["pre", "done"]:
					var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QA + "%s_%d_%s.json" % [route, night, stage]))
					var codec := SaveCodec.new()
					var state := codec.decode(payload, run_def, 20, catalog, true)
					check(state != null, "cross-process checkpoint %s/%d/%s: %s" % [route, night, stage, codec.error_message])
					if state == null: continue
					if not payload.pawn_tickets.is_empty():
						var bad := payload.duplicate(true)
						bad.pawn_tickets[0].terms_id = PawnRedemptionPolicy.DEFAULT if bad.pawn_tickets[0].terms_id == PawnRedemptionPolicy.REDEEM else PawnRedemptionPolicy.REDEEM
						check(codec.decode(bad, run_def, 20, catalog, true) == null, "reject forged redemption result")
					if route == "keep" and night == 5 and stage == "pre":
						for key in ["manual/1", "auto/pawn_chance_seven"]:
							check(library.write_entry(key, state, run_def, 20, catalog), "write shared slot " + library.error_message)
						var bytes := FileAccess.get_file_as_bytes(library.path)
						var before := state.to_read_model()
						library.fail_write = true
						check(not library.write_entry("manual/1", state, run_def, 20, catalog), "failed manual save")
						check(bytes == FileAccess.get_file_as_bytes(library.path) and before == state.to_read_model(), "file and state preserved")
						library.fail_write = false
		var old := JsonContentProvider.new("res://data/market_familiar_manifest.json").load_catalog().catalog
		var old_run := old.get_definition("runs", old.default_run_id) as RunDefinition
		var old_session := RunSession.new(old_run, 19, SaveManager.new(QA + "unused19.json"), old)
		for key in ["manual/2", "auto/market_familiar"]: check(library.write_entry(key, old_session._day.state, old_run, 19, old), "write old version alongside new")
	print("PAWN CHANCE PROCESS TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
