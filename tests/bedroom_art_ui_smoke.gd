extends "res://tests/opening_ui_smoke.gd"

var _keep_open := false

func _run() -> void:
	_keep_open = "interactive" in OS.get_cmdline_user_args()
	if not _keep_open:
		create_timer(90).timeout.connect(func() -> void: push_error("BEDROOM UI TIMEOUT"); quit(1))
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16)
	root.content_scale_size = root.size
	shot_root = "res://docs/qa/bedroom/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_root))
	scene = load("res://scenes/start.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = "user://tests/bedroom_review_%d.json" % Time.get_ticks_usec()
	root.add_child(scene)
	await frames()
	await click(scene.title_menu.buttons[0])
	session = scene.get_node("Bootstrap").session
	view = scene.get_node("CounterScreen/NarrativeScene")
	for step in 12: await choice()
	await choice("accounts")
	await choice("ledger")
	await choice("ready")
	check(session.execute("open_shop").ok, "新版首夜开铺")
	await frames()
	await choice()
	var visit := session._counter.customers.active(session._day.state)
	session.counter_command("appraise", visit.visit_id, "observe")
	session.counter_command("appraise", visit.visit_id, "inspect")
	check(session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "新版首笔交易")
	await frames()
	var receipt: TradeReceiptView = scene.get_node("CounterScreen/TradeReceipt")
	await click(receipt._primary)
	await click(receipt._primary)
	await choice()
	for command in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]:
		check(session.execute(command).ok, "首夜进入寝屋：" + command)
	await frames()
	await choice("photo")
	await choice("letter")
	await choice("lamp")
	await choice("settled")
	var room: PrivateRoomView = scene.get_node("CounterScreen/PrivateRoom")
	check(room.visible and not view.visible, "新版房间显示")
	check(room._photo.visible, "摆好照片后可查看")
	check(not scene.get_node("CounterScreen/ShopStatusView").visible, "寝室不叠加柜台底栏")
	await _pointer(Vector2(1250, 100))
	await shot("normal")
	if _keep_open:
		root.title = "鬼市当铺 · 寝室试玩（独立测试存档）"
		print("BEDROOM REVIEW READY")
		return
	var before := session.read_state()
	await _pointer(room._lamp.get_global_rect().get_center())
	check(room._prop_hint.visible and room._prop_hint.text == "命灯", "命灯移入即显示名称")
	await shot("lamp_hover")
	await _pointer(Vector2(1250, 100))
	check(not room._prop_hint.visible, "命灯移出隐藏提示")
	await click(room._lamp)
	check(room._observation.visible and room._body.text == room._model.lamp, "命灯点击显示实际灯况")
	await shot("lamp_inspect")
	await _key(KEY_ESCAPE)
	check(not room._observation.visible, "Esc关闭观察")
	check(before == session.read_state(), "看命灯不消耗时间或改变存档")
	await click(room._desk)
	check(room._letter != null and room._letter.visible, "新版遗信可回看")
	room._letter.hide()
	await click(room._photo)
	check(room._body.text == tr("opening.room.photo"), "照片对应正式剧情")
	room.dismiss_observation()
	room._bed.grab_focus()
	await _key(KEY_ENTER)
	check(room._confirm != null and room._confirm.visible, "键盘确认可就寝")
	await click(room._confirm.get_cancel_button())
	check(before == session.read_state(), "取消就寝保留进度")
	await click(room._menu)
	var menu: SessionMenuView = scene.find_child("SessionMenu", true, false)
	check(menu.visible, "右下菜单接入正式菜单")
	await _key(KEY_ESCAPE)
	check(not menu.visible and room._menu.has_focus(), "关闭菜单恢复寝室菜单焦点")
	var live := room._model.duplicate(true)
	var no_photo := live.duplicate(true)
	no_photo.photo_placed = false
	room.render(no_photo)
	await _pointer(Vector2(1250, 100))
	await shot("no_photo")
	check(not room._photo.visible and not room._state_material.get_shader_parameter("photo_placed"), "未摆照片时图像和热区一起移除")
	var dead := live.duplicate(true)
	dead.phase = "dead"
	dead.dead = true
	dead.can_sleep = false
	dead.can_finish = false
	dead.body = "灯盏冷了，灯芯再没有亮起来。"
	room.render(dead)
	await shot("lamp_out")
	check(room._lamp.disabled and room._bed.disabled and room._state_material.get_shader_parameter("lamp_dead"), "死亡画面灯灭且不可操作")
	room.render(live)
	check(before == session.read_state(), "画面状态检查不改正式运行")
	await click(room._bed)
	await click(room._confirm.get_ok_button())
	await choice()
	check(room._close_observation.text == "放松入眠" and room._observation.visible, "剧情结束后显示入眠操作")
	await shot("relax_sleep")
	await click(room._close_observation)
	check(session.read_state().phase == "pre_open" and session.read_state().current_night_index == 2, "放松入眠直接进入次日开铺前")
	check(scene.get_node("CounterScreen/MenuButton").visible and scene.get_node("CounterScreen/ShopStatusView").visible, "离开寝室恢复柜台控件")
	print("BEDROOM ART UI: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await frames()

func _key(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await frames()
