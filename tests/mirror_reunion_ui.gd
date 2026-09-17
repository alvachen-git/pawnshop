extends "res://tests/inventory_event_notice_ui.gd"

var session: RunSession
var screen: CounterScreen
var view: MirrorReunionView

func shot(label: String) -> void:
	await create_timer(0.32).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa/v26/%d-%s.png" % [root.size.x, label])

func choose(command: String) -> void:
	await create_timer(0.32).timeout
	var button := view._choices.get_node_or_null("Reunion_" + command) as Button
	check(button != null and not button.disabled, "choice available " + command)
	if button == null: return
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "choice fits viewport " + command)
	await click(button)
	await frames()

func read_pages() -> void:
	for i in 20:
		if view._page >= view._pages.size() - 1: break
		var before := session.read_state()
		await create_timer(0.22).timeout
		await click(view._next)
		check(before == session.read_state(), "reading has no gameplay effect")
	check(view._page == view._pages.size() - 1, "reached last line")

func install(stage: String) -> void:
	var codec := SaveCodec.new()
	session._day.state = codec.decode(JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v26/" + stage + ".json")), session.definition, 26, session._counter.catalog, true)
	check(session._day.state != null, "valid fixture " + codec.error_message)
	session.message = ""
	session.restored.emit(); session.changed.emit()
	await frames()
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"risk")
	await frames()

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa/v26"))
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").manifest_path = "res://data/mirror_reunion_manifest.json"
	main.get_node("Bootstrap").save_path = "user://tests/v26-ui-%d/auto.json" % root.size.x
	root.add_child(main)
	session = main.get_node("Bootstrap").session
	screen = main.get_node("CounterScreen")
	view = screen.get_node("MirrorReunion")
	var notice: Button = screen.get_node("InventoryEventNotice")
	for ending in MirrorReunionService.ENDINGS:
		await install("ready-apology" if ending == "acknowledged" else "ready-angry")
		var panel: RiskPanel = screen.get_node("%RiskPanel")
		var before_entry := session._day.state.game_minutes
		var buttons: VBoxContainer = panel._buttons
		var column: VBoxContainer = panel._column
		if ending in ["acknowledged", "released"]:
			var dialogue: DialoguePanel = screen.get_node("%DialoguePanel")
			screen.get_node("%ScreenFlowCoordinator").show_panel(&"dialogue")
			buttons = dialogue._buttons; column = dialogue._column
			await frames()
		for child in buttons.get_children():
			if child is Button and child.text.contains("请镜中女子现身"):
				(column.get_parent() as ScrollContainer).ensure_control_visible(child)
				await frames(); await click(child); break
		await frames()
		check(view.visible, "native dialogue opens")
		var close := view.find_child("CollapseDialogue", true, false) as Button
		check(close.get_parent().get_child_count() == 2, "header contains speaker and one close control")
		check(view._next.size.x <= 200 and view._next.size.y <= 44, "continue is a compact button")
		check(absf(view._next.get_global_rect().end.x - view._text.get_global_rect().end.x) < 1.0, "continue aligns with right edge of dialogue text")
		check(session._day.state.mirror_resolution.step == 1 and session._day.state.game_minutes == before_entry + 5, "single entry click reveals wife for exactly five minutes")
		check(view._wife.visible and view._choices.get_node_or_null("Reunion_reveal") == null, "no repeated reveal prompt")
		var before_key := session.read_state()
		await create_timer(0.22).timeout
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER; key.pressed = true
		root.push_input(key)
		key = InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = false
		root.push_input(key)
		await frames()
		check(view._page == 1 and before_key == session.read_state(), "Enter advances one line without gameplay action")
		await shot(ending + "-reunion")
		await create_timer(0.22).timeout
		await click(view._next)
		var position := view._page
		await click(view.find_child("CollapseDialogue", true, false))
		check(not view.visible and notice.visible, "close preserves reminder")
		await shot(ending + "-hidden")
		await click(notice)
		check(view.visible and view._page == position, "badge restores exact page")
		await read_pages()
		check(view._choices.get_node_or_null("Reunion_pause") == null, "intervention contains no postpone choice")
		await shot(ending + "-intervention")
		await choose("mediate" if ending == "disappointed" else "press")
		await read_pages()
		check(view._choices.get_node_or_null("Reunion_pause") == null, "ending choices contain no postpone choice")
		await shot(ending + "-response")
		var reaction: String = session._day.state.mirror_resolution.husband
		await click(view.find_child("CollapseDialogue", true, false))
		check(not view.visible and notice.visible, "closing choices retains reminder")
		await click(notice)
		check(view.visible and session._day.state.mirror_resolution.husband == reaction, "returning to choices does not reroll")
		var before := session.read_state()
		await choose(ending)
		check(not MirrorEndingService.finished(session._day.state), "final scene is not committed before reading")
		await read_pages()
		check(before == session.read_state(), "final preview grants no resource or death")
		check(not view._text.text.contains("怨气") and not view._text.text.contains("能力"), "no early reward text")
		await shot(ending + "-last-line")
		await create_timer(0.22).timeout
		await click(view._next)
		check(session._day.state.mirror_resolution.ending == ending, "completed " + ending)
		check(view._notification and not notice.visible, "result after committed ending only")
		check(session._save.load_state(session.definition, 26) != null, "real saved ending reloads")
		await create_timer(1.4).timeout
		check(view._text.get_content_height() <= view._text.size.y, "whole result notification fits without scrolling")
		check(view._text.text.contains("铜镜怨气") if ending == "resentment" else view._text.text.contains("无法再用"), "actual consequence visible in result body")
		await shot(ending + "-result")
		await click(view._next)
		check(not view.visible and not view._notification, "result dismissed once")
		session.restored.emit(); session.changed.emit(); await frames()
		check(not view.visible, "restore does not repeat notification")
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"inventory")
		await frames(); await shot(ending + "-inventory")
		screen.get_node("%ScreenFlowCoordinator").show_panel(&"risk")
		panel.show_notes(true)
		await frames()
		for child in panel._categories.get_children():
			if child is Button and child.text == "查访会面": await click(child); break
		for card in panel._journal.get_children():
			if card.get_meta("entry_id", "") != "resolution_" + ending: continue
			var header: Button = card.get_child(0).get_child(0)
			(panel._column.get_parent() as ScrollContainer).ensure_control_visible(header)
			await frames(); await click(header); break
		await frames(); await shot(ending + "-journal")
	print("MIRROR REUNION UI %d: %d checks, %d failures" % [root.size.x, checks, failures])
	quit(0 if failures == 0 else 1)
