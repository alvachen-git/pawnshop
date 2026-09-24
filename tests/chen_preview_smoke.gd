extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/start.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var session: RunSession = main.get_node("Bootstrap").session
	if session == null: push_error("Chen preview bootstrap failed"); quit(1); return
	var visitor := session._counter.customers.active(session._day.state)
	var okay := session.content_version == 29 and session._day.state.current_night_index == 12 and visitor != null and visitor.customer_id == "fd_chen"
	okay = okay and FirstDebt.owned(session._day.state, FirstDebt.PHOENIX) != null and session.counter_model().get("case_dialogue", {}).is_empty()
	okay = okay and session._save.library.path == "user://tests/v29_preview/chen_library.json"
	var result := session.counter_command("reject", visitor.visit_id)
	okay = okay and result.ok and session.counter_model().get("case_dialogue", {}).get("auto_open", false)
	var saved := session._save.library.read_entry("auto/first_debt_reckoning")
	okay = okay and not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), session.read_state())
	if not okay: push_error("Chen preview or checkpoint failed: " + result.message)
	print("CHEN PREVIEW: ", "PASS" if okay else "FAIL", " - night12 ordinary trade, isolated save, post-trade scene")
	main.queue_free(); await process_frame
	quit(0 if okay else 1)
