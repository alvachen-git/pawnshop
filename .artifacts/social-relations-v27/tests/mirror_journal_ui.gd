extends "res://tests/inventory_event_notice_ui.gd"

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/mirror-journal-%d-%s.png" % [root.size.x, label])

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/mirror_journal/auto.json"
	root.add_child(main)
	var session: RunSession = main.get_node("Bootstrap").session
	session._save = GhostReplayStore.new()
	var screen = main.get_node("CounterScreen")
	var panel: RiskPanel = screen.get_node("%RiskPanel")
	var flow = screen.get_node("%ScreenFlowCoordinator")
	check(session.risk_model().get("note_sections", []).is_empty(), "unacquired records remain hidden")
	var codec := SaveCodec.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v23/ending.json"))
	var state := codec.decode(data, session.definition, 23, session._counter.catalog, true)
	check(state != null, "validated completed investigation fixture: " + codec.error_message)
	if state == null: quit(1); return
	session._day.state = state
	# Add a presentation fixture for an acquired mirror fragment, which the
	# no-mirror investigation route deliberately never obtains. Never persisted.
	state.mirror_history.append({"action": "peek", "night": 3, "minute": 375, "encounter_id": session.definition.mirror_encounters[0].id, "visit_id": "journal-ui-fragment"})
	var sections: Array = session.risk_model("item_weeping_mirror").note_sections
	check(sections.size() == 3, "three acquired categories")
	check(sections[0].entries.size() == 7, "each acquired manual record appears once")
	check(sections[1].entries.size() == 1, "mirror fragments separated from real investigation")
	check(sections[2].entries.size() == 6, "two sources, three answers, one current progress")
	var before := state.to_read_model()
	state.soul_history.append({"result": "living", "visit_id": "never-journalled", "night": 0, "minute": 0})
	check(session.risk_model("item_weeping_mirror").note_sections == sections, "customer scans never enter journal")
	state.soul_history.pop_back()
	state.investigation.read = false
	var sealed: Array = session.risk_model("item_weeping_mirror").note_sections
	check(sealed.back().entries.size() == 1 and not str(sealed).contains("连续数月"), "delivered unopened report does not reveal sources or answers")
	state.investigation.read = true
	var answers: Array = state.investigation.answers.duplicate(true)
	state.investigation.answers = [answers[0]]
	var partial: Array = session.risk_model("item_weeping_mirror").note_sections
	check(partial.back().entries.size() == 4 and not str(partial).contains("是我自己躲着"), "partial meeting never adds unasked answers")
	state.investigation.answers = answers
	var inventory: Array[ItemInstance] = state.inventory_instances.duplicate()
	state.inventory_instances = state.inventory_instances.filter(func(item: ItemInstance) -> bool: return item.definition_id != "item_weeping_mirror")
	check(session.risk_model("item_weeping_mirror").note_sections == sections, "acquired evidence remains after selling the mirror")
	state.inventory_instances = inventory
	session.restored.emit()
	session.changed.emit()
	flow.show_panel(&"risk")
	await frames()
	await click(panel._notes_tab)
	check(not panel._history.visible and panel._journal.visible, "structured cards replace plain history")
	await capture("clues")
	var tabs_position := panel._categories.global_position
	await click(panel._categories.get_child(1))
	await capture("memories")
	await click(panel._categories.get_child(2))
	await capture("investigation")
	# Click the first collapsed substantive answer below the progress card.
	var card = panel._journal.get_child(2)
	var header: Button = card.get_child(0).get_child(0)
	var scroll := panel._column.get_parent() as ScrollContainer
	scroll.ensure_control_visible(header)
	await frames()
	await click(header)
	check(flow.get_active_panel_id() == &"risk" and panel._expanded.investigation == "answer_contact", "actual click expands answer in the journal")
	await capture("answer")
	var expanded := panel._expanded.duplicate()
	scroll.scroll_vertical = 100
	await frames()
	var position := scroll.scroll_vertical
	session.changed.emit()
	await frames()
	check(panel._expanded == expanded and scroll.scroll_vertical == position, "unrelated refresh preserves reading position and open entry")
	check(panel._categories.global_position == tabs_position, "category navigation stays fixed while reading")
	check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "no horizontal overflow")
	check(state.to_read_model() == before, "reading and switching sections mutate no saved state or time")
	for entry_card in panel._journal.get_children():
		if entry_card.get_meta("entry_id", "") != "answer_contact": continue
		var answer_header: Button = entry_card.get_child(0).get_child(0)
		scroll.ensure_control_visible(answer_header)
		await frames()
		await click(answer_header)
		check(panel._expanded.investigation.is_empty(), "actual second click folds the record")
		break
	var blocked := session.risk_model("item_weeping_mirror")
	blocked.requires_response = true
	panel.render(blocked)
	check(not panel._notes_open and panel._body.visible and panel._notes_tab.disabled, "crisis forces actionable page")
	check(not panel._categories.visible, "no journal navigation covers crisis")
	# Unknown categories stay out of the UI, not greyed-out future spoilers.
	state.investigation.clear()
	state.mirror_history.clear()
	var only_clues := session.risk_model("item_weeping_mirror")
	panel.render(only_clues)
	panel.show_notes(true)
	check(panel._categories.get_child_count() == 1, "only acquired categories appear")
	await frames()
	await capture("early")
	print("MIRROR JOURNAL UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
