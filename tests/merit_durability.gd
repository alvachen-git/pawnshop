extends "res://tests/merit_recovery_durability.gd"

func run() -> void:
	var loaded := JsonContentProvider.new(recovery_manifest()).load_catalog()
	check(loaded.is_success(), "v42 catalog")
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id); run_def._initial_cash = 2000
	for mode in ["return", "pay"]:
		var s := load_stage("before-fd_settle", "" if mode == "return" else "-pay")
		if s == null: quit(1); return
		var lib := SaveLibrary.new("res://.godot/qa/v42/merit-" + mode + ".json")
		lib.register_catalog(recovery_manifest(), catalog)
		var store := SaveManager.new(); store.library = lib; store.catalog = catalog; s._save = store
		check(lib.write_entry("auto/" + String(run_def.id), s._day.state, run_def, 42, catalog), "initial save")
		var before := s.read_state(); var bytes := FileAccess.get_file_as_bytes(lib.path)
		check(before.hidden_merit == 0, "no reward before settlement")
		lib.fail_write = true
		check(not s.event_command("fd_settle", mode).ok, "settlement write fails")
		check(before == s.read_state() and bytes == FileAccess.get_file_as_bytes(lib.path), "money items merit history all rollback")
		lib.fail_write = false
		check(s.event_command("fd_settle", mode).ok, "retry settlement")
		check(s._day.state.hidden_merit == 10, "each outcome grants ten")
		check(s.merit_feedback_model().pending and s.merit_feedback_model().safe, "pending safe animation")
		var committed := s.read_state()
		check(not s.event_command("fd_settle", mode).ok and committed == s.read_state(), "no duplicate reward")
		var codec := SaveCodec.new()
		for forged in [-101, 101, 20, 0, 9.5, "10"]:
			var raw := codec.encode(s._day.state, 42); raw.hidden_merit = forged
			check(codec.decode(raw, run_def, 42, catalog, true) == null, "reject merit tamper " + str(forged))
		var raw := codec.encode(s._day.state, 42)
		var file := FileAccess.open("res://.godot/qa/v42/merit-pending-" + mode + ".json", FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
		var restored := codec.decode(raw, run_def, 42, catalog, true)
		check(restored != null and HiddenMerit.feedback(restored).pending, "pending survives replay")
		for danger in ["crisis", "smoke", "dead", "bankrupt", "room", "mirror"]:
			var probe := RunSnapshot.copy(s._day.state)
			if danger == "crisis": probe.risk_pending = "test"
			if danger == "smoke": probe.risk_history.append({"night":probe.current_night_index,"item_id":"probe","action":"close","covered":false})
			if danger == "dead": probe.phase = &"dead"
			if danger == "bankrupt": probe.phase = &"bankrupt"
			if danger == "room": probe.phase = &"private_room"
			check(not HiddenMerit.feedback(probe, danger == "mirror").safe, "defer " + danger)
			check(not HiddenMerit.acknowledge(probe,"seen", danger == "mirror").ok, "cannot consume during " + danger)
		lib.fail_write = true
		check(not s.event_command(HiddenMerit.ECHO, "seen").ok and committed == s.read_state(), "animation write failure retains pending and balance")
		lib.fail_write = false
		check(s.event_command(HiddenMerit.ECHO, "seen").ok, "animation ack retry")
		check(not s.merit_feedback_model().pending and s._day.state.hidden_merit == 10, "ack never grants merit")
		check(s._day.state.cash == committed.cash and s._day.state.game_minutes == committed.game_minutes and s.read_state().inventory_instances == committed.inventory_instances, "animation free and no second return")
		var acknowledged := s.read_state()
		check(not s.event_command(HiddenMerit.ECHO,"seen").ok and acknowledged == s.read_state(), "duplicate animation ack rejected")
		var saved := lib.read_entry("auto/" + String(run_def.id))
		check(not saved.is_empty() and not HiddenMerit.feedback(saved.state).pending, "seen state saved")
		raw = codec.encode(s._day.state, 42)
		file = FileAccess.open("res://.godot/qa/v42/merit-seen-" + mode + ".json", FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
		# Deleting either acknowledgment journal or history cannot forge playback.
		raw.action_journal.pop_back()
		check(codec.decode(raw, run_def,42,catalog,true) == null, "forged echo rejected")
	var bound := RunState.new(); bound.run_definition_id = HiddenMerit.RUN
	HiddenMerit.change(bound, 200); check(bound.hidden_merit == 100,"upper bound")
	HiddenMerit.change(bound,-400); check(bound.hidden_merit == -100,"lower bound")
	var fresh_store := GhostReplayStore.new(); fresh_store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
	var fresh := RunSession.new(run_def,42,fresh_store,catalog)
	check(fresh._day.state.hidden_merit == 0 and not fresh.event_command(HiddenMerit.ECHO,"seen").ok,"fresh cannot claim echo")
	var old_loaded := JsonContentProvider.new("res://data/first_debt_recovery_release_manifest.json").load_catalog()
	var old_run := old_loaded.catalog.get_definition("runs",old_loaded.catalog.default_run_id) as RunDefinition
	var old := RunSession.new(old_run,41,fresh_store,old_loaded.catalog)
	HiddenMerit.change(old._day.state,10)
	check(old._day.state.hidden_merit == 0 and not old.read_state().has("hidden_merit"),"old state shape frozen")
	check(not old.event_command(HiddenMerit.ECHO,"seen").ok,"old run rejects new event")
	print("MERIT DURABILITY: %d passes, %d failures" % [passes, failures]); quit(0 if failures == 0 else 1)
