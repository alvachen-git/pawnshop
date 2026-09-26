extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/start.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame; await process_frame
	var s: RunSession = main.get_node("Bootstrap").session
	if s == null: push_error("merit preview failed"); quit(1); return
	var mode: String = main.get_node("Bootstrap").preview_stage
	var okay := s.content_version == 42 and s.definition.initial_cash == 300 and main.title_menu == null and s._day.state.hidden_merit == 0
	okay = okay and s._save.library.path.begins_with("user://tests/v42_preview/")
	var before := s._day.state.cash
	var action := s.event_command("fd_settle",mode)
	okay = okay and action.ok and s._day.state.hidden_merit == 10 and s._day.state.cash == before - (300 if mode == "pay" else 0)
	var saved := s._save.library.read_entry("auto/" + String(s.definition.id))
	okay = okay and not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(),s.read_state())
	print("MERIT PREVIEW ",mode," ","PASS" if okay else "FAIL"," night",s._day.state.current_night_index," cash",s._day.state.cash)
	if not okay: push_error("preview/save mismatch")
	# Let the audio server release playback before this very short headless test exits.
	main.get_node("ShopBgmPlayer").stop()
	await create_timer(0.1).timeout
	main.queue_free(); await process_frame; quit(0 if okay else 1)
