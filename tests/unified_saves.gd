extends "res://tests/unified_facilities.gd"

func run() -> void:
	if not setup(): quit(1); return
	var s := fresh_growth()
	var codec := SaveCodec.new()
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNIFIED_FIXTURES + "fan-bought.json"))
	s._day.state = codec.decode(payload,run_def,30,catalog,true)
	check(s._day.state != null, "cold cross-process restore of actual integrated journey")
	if s._day.state == null: quit(1); return
	driver.drain(s)
	act(s,"close_shop")
	act(s,"wait_until_seal")
	var lib := SaveLibrary.new("res://.godot/qa/unified/library-%d.json" % Time.get_ticks_usec())
	s._save.library = lib
	lib.register_catalog("res://data/unified_manifest.json",catalog)
	var written := lib.write_entry("manual/1",s._day.state,run_def,30,catalog)
	check(written,"manual slot accepts complete run: " + lib.error_message)
	var decoded := lib.read_entry("manual/1")
	check(not decoded.is_empty() and lib.adopt(decoded,s),"library selects unified manifest")
	check(s.definition.id == "unified_ten" and s._day.state.social.introduced and ShopKnowledgeService.mastered(s._day.state,"gu_yansheng"),"library retains military and knowledge")
	act(s,"resolve_night")
	driver.drain(s)
	act(s,"enter_room")
	check(s._day.state.phase == &"private_room","sealed save reload can settle and enter bedroom")
	verify(s,"room after sealed manual save")
	for manifest in ["mirror_dream_call", "fan_condition", "social_relations"]:
		var old_catalog := JsonContentProvider.new("res://data/" + manifest + "_manifest.json").load_catalog().catalog
		var old_run := old_catalog.get_definition("runs",old_catalog.default_run_id) as RunDefinition
		var old_store := GhostReplayStore.new()
		old_store.origin = {"seed":42,"run_token":"0123456789abcdef0123456789abcdef"}
		var old_session := RunSession.new(old_run,old_catalog.content_version,old_store,old_catalog)
		check(lib.write_entry("manual/2",old_session._day.state,old_run,old_catalog.content_version,old_catalog),"save old rules " + manifest)
		decoded = lib.read_entry("manual/2")
		check(not decoded.is_empty() and lib.adopt(decoded,s),"load old rules " + manifest)
		check(s.definition.id == old_run.id,"old run identity unchanged")
		var old_slot: Dictionary = lib._read().entries["manual/2"].duplicate(true)
		s.new_run()
		check(s.definition.id == "unified_ten" and s.content_version == 30 and s._day.state.current_night_index == 1,"new game always returns to full default")
		check(lib._read().entries["manual/2"] == old_slot,"new game does not rewrite old save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lib.path))
	print("UNIFIED SAVES: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)
