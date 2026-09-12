extends SceneTree

var scene: Node
var session: RunSession
var view: NarrativeScene
var failures := 0
var checks := 0
var shot_root := "res://.artifacts/opening-check/screenshots/"
var width := 1280

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func frames() -> void:
	for n in 4: await process_frame

func click(control: Control) -> void:
	check(control.is_visible_in_tree(), "点击目标可见 " + str(control.name))
	var point := control.get_global_rect().get_center()
	if control.get_window() != root: point += Vector2(control.get_window().position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await frames()

func choice(id := "") -> void:
	if view._choices.get_child_count() == 0:
		check(false, "缺少剧情按钮")
		return
	var button: Button = view._choices.get_child(0) if id.is_empty() else view._choices.get_node("Choice_" + id)
	await click(button)

func shot(name: String) -> void:
	await frames()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var path := shot_root + str(width) + "_" + name + ".png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if view.visible:
		for button in view._choices.get_children():
			check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "按钮在窗口内 " + name)
		check(view._text.size.y >= 110, "正文保留可读高度 " + name)
		check(not "opening." in view._text.text, "本地化键已解析 " + name)

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("OPENING UI TIMEOUT"); quit(1))
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_root))
	scene = load("res://scenes/opening.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = "user://tests/opening_ui_%d.json" % Time.get_ticks_usec()
	root.add_child(scene)
	await frames()
	await click(scene.title_menu.buttons[0])
	session = scene.get_node("Bootstrap").session
	view = scene.get_node("CounterScreen/NarrativeScene")
	check(view.visible and not view._skip.visible, "首轮从纱厂开始，无跳过按钮")
	check(view._choices.get_child(0).has_focus(), "进入开场时键盘焦点在继续按钮")
	await shot("factory")
	for step in 3: await choice()
	await shot("wedding")
	for step in 3: await choice()
	await shot("letter")
	check(view._text.get_v_scroll_bar().max_value > view._text.get_v_scroll_bar().page, "长信可滚动")
	for step in 6: await choice()
	await shot("inspection")
	await choice("accounts")
	await shot("accounts")
	await choice("ledger")
	await choice("ready")
	check(not view.visible, "检查后回到正式柜台")
	session.execute("open_shop")
	await frames()
	await shot("customer")
	await choice()
	var visit := session._counter.customers.active(session._day.state)
	session.counter_command("appraise", visit.visit_id, "observe")
	session.counter_command("appraise", visit.visit_id, "inspect")
	scene.get_node("CounterScreen")._flow.show_panel(&"appraisal")
	await shot("appraisal")
	session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price)
	await frames()
	var receipt: TradeReceiptView = scene.get_node("CounterScreen/TradeReceipt")
	check(receipt.visible and receipt._stamp.visible, "真实成交统一展示盖章凭据")
	var money: int = session.read_state().cash
	await shot("receipt")
	check(receipt._stamp.visible and session.read_state().cash == money, "盖章展示，不重复扣款")
	await shot("stamped")
	await click(receipt._primary)
	check(not receipt.visible and "INTRO_FIRST_TRADE_DONE" in session.read_state().narrative_flags, "收好凭据一次确认首单，不重复弹成交剧情")
	session.execute("close_shop")
	session.execute("wait_until_seal")
	session.execute("resolve_night")
	check(session.execute("enter_room").ok, "首次回房")
	await frames()
	await shot("room")
	await choice("photo")
	await shot("photo_placed")
	await choice("letter")
	await choice("lamp")
	await choice("settled")
	var room: PrivateRoomView = scene.get_node("CounterScreen/PrivateRoom")
	await click(room._desk)
	check(room._letter.visible, "遗信可永久回看")
	await shot("letter_reread")
	room._letter.hide()
	await click(room._bed)
	check(room._confirm.visible, "点击床先确认")
	await click(room._confirm.get_cancel_button())
	check(session.read_state().phase == "private_room", "取消就寝保留房间")
	await click(room._bed)
	await click(room._confirm.get_ok_button())
	await shot("sleep")
	await choice()
	await click(room._bed)
	check(session.read_state().phase == "day_summary", "床等到天明")
	# The repeat option replays canonical choices, retaining the real tutorial.
	session.new_run()
	await frames()
	check(view._skip.visible, "看过序章后才出现跳过")
	await click(view._skip)
	check(session.read_state().pending_event_id == "evt_intro_shop_inspection" and "INTRO_LETTER_RECEIVED" in session.read_state().narrative_flags, "跳过补齐剧情物品，保留进店和教程")
	await shot("repeat_arrival")
	print("OPENING UI: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
