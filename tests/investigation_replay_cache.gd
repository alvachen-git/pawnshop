extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog = JsonContentProvider.new("res://data/mirror_investigation_manifest.json").load_catalog().catalog
	var run_def = catalog.get_definition("runs", catalog.default_run_id)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/ending.json"))
	var verifier := InvestigationSaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var restored := verifier.restore(data, run_def, catalog, true)
	check(restored != null and verifier.replayed_actions == data.action_journal.size(), "first read fully replays")
	var pristine := restored.to_read_model()
	restored.cash += 1
	restored.action_journal.clear()
	restored.investigation.clear()
	restored = verifier.restore(data, run_def, catalog, true)
	check(restored != null and verifier.replayed_actions == 0 and GhostSaveCodec.same(restored.to_read_model(), pristine), "returned mutable state cannot poison cache")
	for key in ["cash", "personal_damage", "investigation", "ghost_swaps", "death_archive", "bankruptcy_archive"]:
		var forged := data.duplicate(true)
		if key in ["cash", "personal_damage"]: forged[key] += 1
		elif key == "investigation": forged[key]["payment_id"] = "forged"
		else: forged[key] = [{"forged": true}]
		check(verifier.restore(forged, run_def, catalog, true) == null, "warm cache rejects forged " + key)
		check(verifier.restore(data, run_def, catalog, true) != null, "failed verification does not poison " + key)
	var forged := data.duplicate(true)
	forged.action_journal[0].args[0] = "sleep"
	check(verifier.restore(forged, run_def, catalog, true) == null and verifier.replayed_actions > 0, "edited old prefix fully replays and rejects")
	forged = data.duplicate(true)
	forged.action_journal.pop_back()
	check(verifier.restore(forged, run_def, catalog, true) == null and verifier.replayed_actions > 0, "shortened journal cannot borrow later state")
	check(verifier.restore(data, run_def, catalog, true) != null, "valid checkpoint survives failed branches")
	var husband = catalog.get_definition("customers", "mirror_husband")
	husband.life_status = "dead"
	verifier.restore(data, run_def, catalog, true)
	check(verifier.replayed_actions > 0, "mutable content invalidates prefix")
	husband.life_status = "living"
	# Compare successive real checkpoints against an independent cold replay.
	var store := GhostReplayStore.new(); store.origin = data.ghost_origin
	var session := RunSession.new(run_def, 23, store, catalog)
	session.replaying = true
	InvestigationSaveCodec.clear_cache()
	var checkpoints := 0
	for row in data.action_journal:
		session.callv(row.method, row.args)
		if row.method != "execute" or row.args[0] not in ["prep_finish", "resolve_night", "enter_room", "finish_sleep"]: continue
		var payload := SaveCodec.new().encode(session._day.state, 23)
		var warm := verifier.restore(payload, run_def, catalog, true)
		check(warm != null, "incremental real checkpoint " + str(checkpoints))
		InvestigationSaveCodec.clear_cache()
		var cold := verifier.restore(payload, run_def, catalog, true)
		check(cold != null and warm != null and GhostSaveCodec.same(warm.to_read_model(), cold.to_read_model()), "warm/cold equality " + str(checkpoints))
		checkpoints += 1
	# Actual atomic disk failure after successful cached validation, then retry.
	var store2 := GhostReplayStore.new(); store2.origin = data.ghost_origin
	session = RunSession.new(run_def, 23, store2, catalog)
	session.replaying = true
	for row in data.action_journal:
		if session._day.state.current_night_index == 8 and row.method == "execute" and row.args[0] == "enter_room": break
		session.callv(row.method, row.args)
	session.replaying = false
	var saver := SaveManager.new("user://tests/replay_cache/auto.json"); saver.catalog = catalog
	var library := SaveLibrary.new("user://tests/replay_cache/library.json"); saver.library = library
	session._save = saver
	check(saver.save_state(session._day.state, run_def, 23), "real initial publication")
	var before := session.read_state()
	var disk_before := FileAccess.get_file_as_string(library.path)
	library.fail_write = true
	check(not session.execute("enter_room").ok, "publication failure reported")
	check(GhostSaveCodec.same(before, session.read_state()) and disk_before == FileAccess.get_file_as_string(library.path), "failed cached publication rolls back state and file")
	library.fail_write = false
	check(session.execute("enter_room").ok and session._day.state.phase == &"private_room", "retry after rollback succeeds once")
	print("REPLAY CACHE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
