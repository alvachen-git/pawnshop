extends "res://tests/run_personal_risk.gd"

const TRANSFER := "res://.artifacts/shadow-transfer/"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/life_lamp_manifest.json").load_catalog()
	check(loaded.is_success(), "content loads")
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "life_lamp_seven")
	run_def._randomize_seed = false; run_def._seed = 42
	driver.check = check; driver.catalog = catalog
	if "process-read" in OS.get_cmdline_user_args():
		var files := DirAccess.get_files_at(TRANSFER)
		check(files.size() >= 9, "all snapshots exist")
		for filename in files:
			var codec := SaveCodec.new()
			var state := codec.decode(JSON.parse_string(FileAccess.get_file_as_string(TRANSFER + filename)), run_def, 22, catalog)
			check(state != null, "fresh process restores " + filename + ": " + codec.error_message)
			if state != null: check(not BedroomMirrorFeedback.build(state).is_empty() == filename.ends_with("_room.json"), "derived feedback restored " + filename)
	else:
		shadow_units()
		for route in (["pursue"] if "preview-fixture" in OS.get_cmdline_user_args() else ["pursue", "severe", "both"]):
			shadow_route(route)
	print("BEDROOM SHADOW: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func shadow_units() -> void:
	var state := RunState.create(run_def)
	state.phase = &"private_room"
	for damage in range(4):
		state.personal_damage = damage
		check(BedroomMirrorFeedback.build(state).is_empty(), "lamp damage alone never casts shadow")
	for action in ["peek", "stop", "pursue_expired", "pursue"]:
		state.mirror_history.assign([{"night": state.current_night_index, "action": action, "visit_id": "unit", "mirror_id": "mirror"}])
		check(BedroomMirrorFeedback.build(state).is_empty() == (action != "pursue"), "only successful pursuit: " + action)
	var before := state.to_read_model().duplicate(true)
	for i in 4: check(BedroomMirrorFeedback.build(state).event_instance == "mirror/unit", "stable event instance")
	check(before == state.to_read_model(), "observation model has no writes")
	state.personal_damage = 0
	check(not BedroomMirrorFeedback.build(state).is_empty(), "recovery does not resolve a pursuing shadow")
	for phase in [&"open", &"dead", &"day_summary"]:
		state.phase = phase
		check(BedroomMirrorFeedback.build(state).is_empty(), "outside room no effect")
	state.phase = &"private_room"
	state.personal_risk_enabled = false
	check(BedroomMirrorFeedback.build(state).is_empty(), "legacy run retains original reflection")

func shadow_snapshot(s: RunSession, label: String) -> void:
	DirAccess.make_dir_recursive_absolute(TRANSFER)
	var file := FileAccess.open(TRANSFER + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state, 22)))

func shadow_route(route: String) -> void:
	var s := fresh("shadow_" + route)
	for n in 2:
		driver.open(s); driver.work(s, "stop"); driver.finish(s, "covered")
	driver.open(s); chapter_work(s, "pursue")
	var item: ItemInstance = s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.definition_id == "item_weeping_mirror")[0]
	if route != "both": check(s.risk_command("cover", item.instance_id).ok, "cover mirror")
	for command in ["close_shop", "wait_until_seal", "resolve_night"]: driver.action(s, command)
	if route == "both": check(s.risk_command("defy", item.instance_id).ok, "shop injury before room")
	driver.action(s, "enter_room"); driver.drain(s)
	var feedback := BedroomMirrorFeedback.build(s._day.state)
	check(feedback.get("mode") == &"shadow", "production pursuit visible in bedroom")
	var owned := RunSnapshot.copy(s._day.state)
	owned.inventory_instances.clear()
	check(BedroomMirrorFeedback.build(owned) == feedback, "ownership loss alone cannot resolve pursuit (read-model fixture)")
	var before := s.read_state()
	check(s.load_checkpoint().ok and s.read_state() == before and BedroomMirrorFeedback.build(s._day.state) == feedback, "reload preserves unresolved shadow without damage")
	shadow_snapshot(s, route + "_room")
	driver.action(s, "sleep"); driver.drain(s)
	check(BedroomMirrorFeedback.build(s._day.state) == feedback, "sleep keeps shadow until actual response")
	before = s.read_state()
	var library := SaveLibrary.new("res://.godot/shadow-failure-%d.json" % Time.get_ticks_usec())
	library.fail_write = true; s._save.library = library
	check(not s.risk_command("retreat", item.instance_id).ok, "failed avoidance is reported")
	check(before == s.read_state() and BedroomMirrorFeedback.build(s._day.state) == feedback, "failed save rolls back response and shadow together")
	s._save.library = null
	check(s.risk_command("retreat" if route == "pursue" else "defy", item.instance_id).ok, "actual sleep response")
	var damage := 1 if route == "pursue" else 2 if route == "severe" else 4
	check(s._day.state.personal_damage == damage and BedroomMirrorFeedback.build(s._day.state).is_empty(), "response clears reflection, preserves actual injury")
	check(not s.risk_command("defy", item.instance_id).ok and s._day.state.personal_damage == damage, "repeated response cannot damage")
	shadow_snapshot(s, route + "_response")
	if route != "both":
		driver.action(s, "finish_sleep"); driver.action(s, "continue_run")
		check(s._day.state.current_night_index == 4 and s._day.state.personal_damage == damage and BedroomMirrorFeedback.build(s._day.state).is_empty(), "next day has no stale shadow or healing")
	shadow_snapshot(s, route + "_end")
