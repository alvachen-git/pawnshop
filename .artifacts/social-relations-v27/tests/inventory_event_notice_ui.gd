extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 4: await process_frame

func click(button: Button) -> void:
	check(button.is_visible_in_tree(), "click target visible: " + button.name)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event)
		await process_frame
	await frames()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/inventory-notice-%d-%s.png" % [root.size.x, label])

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/start.tscn").instantiate()
	main.start_at_title = false
	main.get_node("Bootstrap").save_path = "user://tests/inventory_notice/auto.json"
	root.add_child(main)
	var session: RunSession = main.get_node("Bootstrap").session
	session._save = GhostReplayStore.new()
	var state := session._day.state
	state.current_night_index = 3
	state.phase = &"open"
	state.pending_event_id = ""
	var mirror := ItemInstance.new()
	mirror.instance_id = "ui-notice-mirror"
	mirror.definition_id = "item_weeping_mirror"
	mirror.selected_variant_id = session._counter.catalog.get_definition("items", mirror.definition_id).possible_variants[0].id
	mirror.acquired_night = 3
	state.inventory_instances.append(mirror)
	session.changed.emit()
	var screen: CounterScreen = main.get_node("CounterScreen")
	var notice = screen.get_node("InventoryEventNotice")
	var flow = screen.get_node("%ScreenFlowCoordinator")
	var panel: RiskPanel = screen.get_node("%RiskPanel")
	await frames()
	check(not notice.visible, "merely holding an item does not signal an event")
	# Trigger the actual uncovered-mirror closing event through existing actions.
	for action in ["close_shop", "wait_until_seal", "resolve_night"]:
		check(session.execute(action).ok, action)
	await frames()
	check(state.risk_pending == mirror.instance_id and notice.visible, "triggered event lights inventory")
	flow.show_panel(&"day")
	var day_panel: DayFlowPanel = screen.get_node("%DayFlowPanel")
	check(day_panel._buttons.has("enter_room") and day_panel._buttons.enter_room.disabled, "pending crisis blocks room entry in business page")
	check(day_panel._buttons.has("read_risk"), "business page provides pending crisis route")
	flow.show_panel(&"risk")
	await capture("event")
	await click(screen.get_node("%CloseDrawerButton"))
	check(not screen.get_node("%Drawer").visible and notice.visible, "closing the event keeps the reminder")
	await capture("closed")
	var before := session.read_state()
	await click(notice)
	check(screen.get_node("%Drawer").visible and flow.get_active_panel_id() == &"risk", "badge opens the event page")
	check(not panel._notes_open and panel._body.visible and panel._buttons.visible, "event actions are shown, not notes")
	check(session.read_state() == before, "opening the reminder changes neither time nor state")
	await capture("reopened")
	session.restored.emit()
	session.changed.emit()
	check(notice.visible, "restored pending event remains visible")
	var response: Button
	for child in panel._buttons.get_children():
		if child is Button and child.text.contains("低头"):
			response = child
	check(response != null, "response button exists")
	if response != null: await click(response)
	check(session._day.state.risk_pending.is_empty() and not notice.visible, "actual resolution removes the badge")
	await capture("resolved")
	# An already-triggered item narrative uses its own event page.
	for id in session.definition.event_ids:
		var event := session._counter.catalog.get_definition("events", id) as EventDefinition
		if event.required_items.is_empty(): continue
		session._day.state.phase = &"open"
		session._day.state.pending_event_id = id
		notice.refresh()
		check(notice.visible and notice.pending_panel() == &"events", "item narrative routes to events")
		break
	session._day.state.pending_event_id = ""
	notice.refresh()
	check(not notice.visible, "no triggered event means no reminder")
	print("INVENTORY NOTICE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
