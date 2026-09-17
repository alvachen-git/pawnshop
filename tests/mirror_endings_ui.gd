extends "res://tests/inventory_event_notice_ui.gd"

var session: RunSession
var screen: CounterScreen
var panel: RiskPanel
var flow: ScreenFlowCoordinator

func button_with(text: String) -> Button:
	for child in panel._buttons.get_children():
		if child is Button and child.text.contains(text): return child
	return null

func choose(text: String) -> void:
	var button := button_with(text)
	check(button != null, "choice exists " + text)
	if button == null: return
	var scroll := panel._column.get_parent() as ScrollContainer
	scroll.ensure_control_visible(button)
	await frames()
	check(not button.disabled, "choice available " + text)
	await click(button)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa/v25/%d-%s.png" % [root.size.x, label])

func install() -> void:
	var codec := SaveCodec.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/v25/ready.json"))
	var restored := codec.decode(data, session.definition, 25, session._counter.catalog, true)
	check(restored != null, "verified UI fixture")
	session._day.state = restored
	# Use real atomic file saving, isolated from the player's save library.
	session.message = ""
	session.restored.emit()
	session.changed.emit()
	panel.show_notes(false)
	flow.show_panel(&"risk")
	await frames()

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa/v25"))
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/v25-ui-%d/auto.json" % root.size.x
	root.add_child(main)
	session = main.get_node("Bootstrap").session
	screen = main.get_node("CounterScreen")
	panel = screen.get_node("%RiskPanel")
	flow = screen.get_node("%ScreenFlowCoordinator")
	var notice: Button = screen.get_node("InventoryEventNotice")
	for ending in ["acknowledged", "released", "resentment"]:
		await install()
		await choose("把旧事带到镜前")
		check(MirrorEndingService.active(session._day.state), "started through UI")
		await shot(ending + "-approach")
		await click(screen.get_node("%CloseDrawerButton"))
		check(notice.visible, "hidden event retains badge")
		await shot(ending + "-hidden")
		var before := session.read_state()
		await click(notice)
		check(before == session.read_state() and flow.get_active_panel_id() == &"risk", "badge returns without advancing")
		await choose("先说明" if ending == "acknowledged" else "揭开铜镜")
		await shot(ending + "-attitude")
		await choose("暂且收起")
		check(not notice.visible and not MirrorEndingService.active(session._day.state), "pause dismisses event")
		await choose("继续镜前的话")
		await choose("把当票")
		panel.reset_reading_position()
		await frames()
		await shot(ending + "-warning")
		await choose({"acknowledged": "请他亲口", "released": "劝她", "resentment": "让她"}[ending])
		check(session._day.state.mirror_resolution.ending == ending, "UI terminal " + ending)
		check(not notice.visible, "resolved badge removed")
		panel.reset_reading_position()
		await frames()
		await shot(ending + "-effect")
		await create_timer(1.4).timeout
		await shot(ending + "-ending")
		check(screen.get_node("MirrorEndingEffect").play_count == ["acknowledged", "released", "resentment"].find(ending) + 1, "one effect after committed ending")
		check(session.has_save(), "terminal auto-saved")
		var saved := session._save.load_state(session.definition, 25)
		check(saved != null and saved.mirror_resolution.ending == ending, "actual file restores terminal")
		await click(panel._notes_tab)
		await frames()
		for child in panel._categories.get_children():
			if child is Button and child.text == "查访会面": await click(child); break
		for card in panel._journal.get_children():
			if card.get_meta("entry_id", "") != "resolution_" + ending: continue
			var header: Button = card.get_child(0).get_child(0)
			(panel._column.get_parent() as ScrollContainer).ensure_control_visible(header)
			await frames()
			await click(header)
			break
		await shot(ending + "-journal")
		flow.show_panel(&"inventory")
		await frames()
		await shot(ending + "-inventory-overview")
		var inventory: InventoryPanel = screen.get_node("%InventoryPanel")
		(inventory._column.get_parent() as ScrollContainer).scroll_vertical = 10000
		await frames()
		await shot(ending + "-inventory")
	print("MIRROR ENDINGS UI %d: %d checks, %d failures" % [root.size.x, checks, failures])
	quit(0 if failures == 0 else 1)
