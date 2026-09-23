extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/start.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var session: RunSession = main.get_node("Bootstrap").session
	if session == null: push_error("preview bootstrap failed"); quit(1); return
	var before := session.read_state()
	var visitor := session._counter.customers.active(session._day.state)
	var okay: bool = session.content_version == 28 and before.current_night_index == 11 and before.game_minutes == 0 and before.cash == 368 and visitor != null and visitor.customer_id == "fd_seller"
	okay = okay and main.title_menu == null and main.get_node("CounterScreen").visible
	okay = okay and "aq_ticket_seen" in before.narrative_flags and "fd_ticket_read" not in before.narrative_flags and "fd_receipt_read" not in before.narrative_flags
	okay = okay and session._save.library.path == "user://tests/v28_preview/seller_library.json"
	var action := session.observe_document("fd_receipt")
	okay = okay and action.ok and session.read_state().game_minutes == 0
	var saved := session._save.library.read_entry("auto/first_debt_open")
	okay = okay and not saved.is_empty() and GhostSaveCodec.same(saved.state.to_read_model(), session.read_state())
	if not okay: push_error("preview state or isolated atomic save failed: " + action.message)
	print("FIRST DEBT PREVIEW: ", "PASS" if okay else "FAIL", " - night11, seller, unseen papers, isolated save/replay")
	main.queue_free(); await process_frame
	quit(0 if okay else 1)
