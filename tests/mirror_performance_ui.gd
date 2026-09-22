extends "res://tests/inventory_event_notice_ui.gd"

var session: RunSession
var screen: CounterScreen
var view: MirrorReunionView
var output_dir := "res://docs/qa/mirror-performance/"
var version := 26
var fixture_dir := "res://.godot/qa/v26/"

func shot(label: String) -> void:
	await create_timer(0.32).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir + "%d-%s.png" % [root.size.x, label])

func choose(command: String) -> void:
	await create_timer(0.32).timeout
	var button := view._choices.get_node_or_null("Reunion_" + command) as Button
	check(button != null and not button.disabled, "choice available " + command)
	if button == null: return
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "choice fits viewport " + command)
	await click(button)
	await frames()

func read_pages() -> void:
	for i in 60:
		if view._page >= view._pages.size() - 1 and not view._stage.animating(): break
		if not view._next.visible:
			await create_timer(0.25).timeout
			continue
		var before := session.read_state()
		await create_timer(0.22).timeout
		var reading_index := view._page
		var moving := view._stage.animating()
		await click(view._next)
		if moving: check(view._page == reading_index, "advancing during motion completes it without skipping dialogue")
		check(before == session.read_state(), "reading has no gameplay effect")
		if not view._pages[view._page].cg.is_empty():
			await create_timer(0.7).timeout
			await shot(view._pages[view._page].cg + "-illustration")
	check(view._page == view._pages.size() - 1, "reached last line")

func install(stage: String) -> void:
	var codec := SaveCodec.new()
	session._day.state = codec.decode(JSON.parse_string(FileAccess.get_file_as_string(fixture_dir + stage + ".json")), session.definition, version, session._counter.catalog, true)
	check(session._day.state != null, "valid fixture " + codec.error_message)
	session.message = ""
	session.restored.emit(); session.changed.emit()
	await frames()
	screen.get_node("%ScreenFlowCoordinator").show_panel(&"risk")
	await frames()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	if "v27" in OS.get_cmdline_user_args():
		version = 27
		fixture_dir = "res://.godot/qa/v27-reunion/"
	if "v28" in OS.get_cmdline_user_args():
		version = 28
		fixture_dir = "res://.godot/qa/v28/"
		output_dir = "res://docs/qa/mirror-dream/endings/"
	if "v29" in OS.get_cmdline_user_args():
		version = 29
		fixture_dir = "res://.godot/qa/v29/"
		output_dir = "res://docs/qa/mirror-dream-call/endings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").manifest_path = "res://data/mirror_dream_call_manifest.json" if version == 29 else "res://data/mirror_dream_manifest.json" if version == 28 else "res://data/aqi_reunion_manifest.json" if version == 27 else "res://data/mirror_reunion_manifest.json"
	main.get_node("Bootstrap").save_path = "user://tests/v26-ui-%d/auto.json" % root.size.x
	root.add_child(main)
	session = main.get_node("Bootstrap").session
	screen = main.get_node("CounterScreen")
	view = screen.get_node("MirrorReunion")
	check(CounterVisualCatalog.portrait("asset.customer_hawker", "mirror_husband").resource_path == view._stage._normal.resource_path, "third-night husband and confrontation share approved portrait")
	check(CounterVisualCatalog.portrait("asset.customer_hawker", "mirror_husband", InvestigationService.PERSON).resource_path == view._stage._normal.resource_path, "appointment keeps the same husband identity")
	var notice: Button = screen.get_node("InventoryEventNotice")
	for ending in MirrorReunionService.ENDINGS:
		print("ROUTE ", ending)
		await install("ready-apology" if ending == "acknowledged" else "ready-angry")
		if ending == "acknowledged":
			screen._close_drawer()
			await shot("husband-counter")
			screen.get_node("%ScreenFlowCoordinator").show_panel(&"risk")
			await frames()
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
				await frames()
				await click(child); break
		await frames()
		check(view.visible, "native dialogue opens")
		if not view.visible: quit(1); return
		var close := view.find_child("CollapseDialogue", true, false) as Button
		check(close.get_parent().get_child_count() == 2, "header contains speaker and one close control")
		check(view._next.size.x <= 200 and view._next.size.y <= 44, "continue is a compact button")
		check(absf(view._next.get_global_rect().end.x - view._text.get_global_rect().end.x) < 1.0, "continue aligns with right edge of dialogue text")
		check(session._day.state.mirror_resolution.step == 1 and session._day.state.game_minutes == before_entry + 5, "single entry click reveals wife for exactly five minutes")
		check(view._wife.visible and view._choices.get_node_or_null("Reunion_reveal") == null, "no repeated reveal prompt")
		var before_key := session.read_state()
		await create_timer(0.22).timeout
		var key := InputEventKey.new()
		var entrance_busy := view._stage.animating()
		var page_before_key := view._page
		key.keycode = KEY_ENTER; key.pressed = true
		root.push_input(key)
		key = InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = false
		root.push_input(key)
		await frames()
		check(view._page == page_before_key + (0 if entrance_busy else 1) and before_key == session.read_state(), "Enter finishes active motion or advances one line")
		var page_after_key := view._page
		await create_timer(0.22).timeout
		key = InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = true; root.push_input(key)
		key = InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = false; root.push_input(key)
		await frames()
		check(view._page == page_after_key + 1 and before_key == session.read_state(), "second Enter advances one line")
		await shot(ending + "-reunion")
		await create_timer(0.22).timeout
		await click(view._next)
		var position := view._page
		var sound_count := view._stage.sound_count
		await click(view.find_child("CollapseDialogue", true, false))
		check(not view.visible and notice.visible, "close preserves reminder")
		await shot(ending + "-hidden")
		await click(notice)
		check(view.visible and view._page == position, "badge restores exact page")
		check(not view._stage.animating() and view._stage.sound_count == sound_count, "reopening restores scene silently")
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
		var real_store = session._save
		var failing := FailingStore.new()
		session._save = failing
		var before_commit := session.read_state()
		var final_sound_count := view._stage.sound_count
		await click(view._next)
		check(before_commit == session.read_state() and failing.writes == 1, "failed save rolls back full ending")
		check(view._pending == ending and not view._notification and view._next.text == "重试保存", "failure retains final retry")
		var blocked := session.execute("close_shop")
		check(not blocked.ok and blocked.message.contains("镜前"), "failed ending still blocks a valid business action")
		await click(close); await click(notice)
		check(view._next.text == "重试保存" and view._stage.sound_count == final_sound_count, "reopen does not replay final scene")
		session._save = real_store
		await create_timer(0.22).timeout
		await click(view._next)
		check(view._stage.sound_count == final_sound_count, "retry does not replay attack sound")
		check(session._day.state.mirror_resolution.ending == ending, "completed " + ending)
		check(view._notification and not notice.visible, "result after committed ending only")
		check(screen.get_node("MirrorEndingEffect").play_count == 0, "new scene suppresses duplicate legacy ending flash and audio")
		check(session._save.load_state(session.definition, version) != null, "real saved ending reloads")
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
		check(session.execute("close_shop").ok, "normal shop closing resumes after " + ending)
	print("PERFORMANCE stage_apply_max_us=%d animation_frame_max_ms=%.2f" % [view._stage.max_apply_usec, view._stage.max_animation_frame_ms])
	print("PERFORMANCE entrance_frame_max_ms=%.2f illustration_frame_max_ms=%.2f" % [view._stage.opening_frame_max_ms, view._stage.illustration_frame_max_ms])
	print("MIRROR PERFORMANCE UI %d: %d checks, %d failures" % [root.size.x, checks, failures])
	quit(0 if failures == 0 else 1)

class FailingStore extends GhostReplayStore:
	var writes := 0
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool:
		writes += 1
		error_message = "Injected UI save failure"
		return false
