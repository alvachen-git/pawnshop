extends "res://tests/run_aqi.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/aqi_manifest.json").load_catalog()
	check(loaded.is_success(), "durability catalog")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", "aqi_seven")
	for stage in ["paper-2-room", "paper-7-seal"]:
		var codec := SaveCodec.new()
		var raw = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/process/" + stage + ".json"))
		var state := codec.decode(raw, run_def, 22, catalog)
		check(state != null, "validated source " + stage)
		if state == null: quit(1); return
		var s := fresh("durability")
		s._day.state = state
		var lib := SaveLibrary.new(OUT + "/durable_%d.json" % Time.get_ticks_usec())
		s._save.library = lib
		check(lib.write_entry("auto/aqi_seven", state, run_def, 22, catalog), "baseline aqi auto slot")
		check(lib.write_entry("manual/1", state, run_def, 22, catalog), "same shared manual slot")
		var bytes := FileAccess.get_file_as_bytes(lib.path)
		var before := s.read_state()
		lib.fail_write = true
		var observation: bool = stage.contains("2-room")
		var failed := s.observe_room("aq_coat") if observation else s.event_command("aq_arrival", "inspect")
		check(not failed.ok and not failed.message.is_empty() and before == s.read_state(), "failed write restores in-memory source")
		check(bytes == FileAccess.get_file_as_bytes(lib.path), "failed write preserves existing auto and manual bytes")
		lib.fail_write = false
		check(not lib.read_entry("auto/aqi_seven").is_empty(), "previous checkpoint remains readable")
		var retry := s.observe_room("aq_coat") if observation else s.event_command("aq_arrival", "inspect")
		check(retry.ok, "same intent retry succeeds")
		var count := s._day.state.event_history.size()
		if observation: check(s.observe_room("aq_coat").ok, "reread succeeds")
		else: check(not s.event_command("aq_arrival", "inspect").ok, "old button ignored")
		check(count == s._day.state.event_history.size(), "exactly one new record")
		var read := lib.read_entry("auto/aqi_seven")
		check(not read.is_empty() and read.state.event_history.size() == count, "retry persisted exactly once")
		var manual := lib.read_entry("manual/1")
		check(not manual.is_empty() and manual.state.event_history.size() == before.event_history.size(), "manual source slot unchanged by auto retry")
	print("AQI DURABILITY: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
