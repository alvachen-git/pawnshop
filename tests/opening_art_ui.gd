extends "res://tests/opening_ui_smoke.gd"

# Send a complete click in one frame so native pointer movement cannot interrupt
# the synthetic press/release pair while the real GUI window is rendering.
func click(control: Control) -> void:
	check(control.is_visible_in_tree(), "点击目标可见 " + str(control.name))
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await frames()

# Current production manifest; all saves stay in a unique tests directory.
func _run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("OPENING ART UI TIMEOUT"); quit(1))
	width = 1600 if "wide" in OS.get_cmdline_user_args() else 1280
	root.size = Vector2i(width, width * 9 / 16)
	root.content_scale_size = root.size
	shot_root = "res://docs/qa/opening-art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_root))
	scene = load("res://scenes/start.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = "user://tests/opening_art_%d.json" % Time.get_ticks_usec()
	root.add_child(scene)
	await frames()
	scene.get_node("Bootstrap").session.definition._randomize_seed = false
	scene.get_node("Bootstrap").session.definition._seed = 42
	scene.get_node("Bootstrap").session.new_run()
	await click(scene.title_menu.buttons[0])
	session = scene.get_node("Bootstrap").session
	view = scene.get_node("CounterScreen/NarrativeScene")
	check(session.definition.id == "camera_unified", "测试使用当前正式入口")
	check(view.visible and not view._skip.visible, "首轮完整序章")
	check(view._choices.get_child(0).has_focus(), "继续按钮键盘焦点")
	var photo_pixels := PackedByteArray()
	for step in 12:
		var pending: String = session.read_state().pending_event_id
		print("OPENING STEP ", step, ": ", pending)
		await shot(pending.trim_prefix("evt_intro_"))
		check(view._backdrop._paint.texture != null, "剧情背景有图 " + pending)
		var photo_rect := Rect2i(int(width * 0.37), int(root.size.y * 0.10), int(width * 0.28), int(root.size.y * 0.37))
		if step == 2:
			photo_pixels = root.get_texture().get_image().get_region(photo_rect).get_data()
		if step == 3:
			check(photo_pixels == root.get_texture().get_image().get_region(photo_rect).get_data(), "两处旧照片的人脸和表情逐像素一致")
		if step in [7, 8, 9]:
			check(view._backdrop._paint.material == view._backdrop._memory_material, "顾叔回忆统一褪色 " + pending)
		if step == 10:
			check(view._backdrop._paint.material == null, "回到现实恢复正常颜色")
		if step == 11:
			check(not view._door_audio.playing and not view._audio.playing, "铺外不提前播放推门音效")
		if step == 6:
			check(view._text.get_v_scroll_bar().max_value > view._text.get_v_scroll_bar().page, "长遗信可滚动")
			view._text.scroll_to_line(100)
			await shot("letter_bottom")
			check(view._text.get_v_scroll_bar().value > 0, "可读到信尾")
			var before := session.read_state()
			check(session.load_checkpoint().ok, "开场中途可读档")
			check(session.read_state() == before, "开场读档不改旗标或账目")
		await choice()
	check(view._scene == "inspection", "推门接手旧铺")
	check(view._door_audio.playing, "点击推门后木门声延续到铺内")
	check(not view._audio.playing, "场景纸张声不覆盖推门声")
	await shot("inspection")
	await choice("accounts")
	check(view._text.text.contains("500"), "旧债金额仍清楚")
	await shot("accounts")
	await choice("ledger")
	await shot("ledger")
	await choice("ready")
	check(not view.visible, "坐柜回到经营界面")
	check(session.execute("open_shop").ok, "真实开铺")
	await frames()
	await shot("first_customer")
	var before_tutorial := session.read_state()
	for page in 5:
		check(session.read_state().pending_event_id == "evt_intro_first_customer", "周婶对白仍属于同一首客事件")
		check(view._dialogue_page == page, "周婶对白按顺序分页")
		await shot("neighbor_page_%d" % (page + 1))
		check(view._text.get_content_height() <= view._text.size.y + 2, "周婶对白一屏可读")
		if page < 4:
			check(session.read_state() == before_tutorial, "翻对白不耗时也不改变存档状态")
		await choice()
	check(not view.visible, "周婶介绍结束回到实际柜台")
	check("INTRO_FIRST_CUSTOMER_STARTED" in session.read_state().narrative_flags, "首客事件完成旗标不变")
	var neighbor := session._counter.catalog.get_definition("customers", "intro_neighbor") as CustomerDefinition
	check(neighbor.terms.display_name == "周秀英（周婶）", "周婶固定姓名")
	var visit := session._counter.customers.active(session._day.state)
	check(session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price).ok, "首笔真实交易")
	await frames()
	var screen: CounterScreen = scene.get_node("CounterScreen")
	if screen._receipt.visible: await click(screen._receipt._primary)
	for step in 4:
		if not view.visible: break
		await choice()
	for command in ["close_shop", "wait_until_seal", "resolve_night", "enter_room"]:
		check(session.execute(command).ok, "首夜流程 " + command)
	await frames()
	await shot("room")
	check(not view._backdrop._room_material.get_shader_parameter("photo_placed"), "照片尚未摆上")
	await choice("photo")
	check(view._backdrop._room_material.get_shader_parameter("photo_placed"), "照片随真实选择显示")
	await shot("photo_placed")
	await choice("letter")
	await choice("lamp")
	await choice("settled")
	check(not view.visible, "整理完回到正式寝屋")
	check(session.execute("sleep").ok, "进入就寝剧情")
	await frames()
	await shot("sleep")
	await choice()
	var dawn := session.execute("finish_sleep")
	check(dawn.ok, "第一夜结束：" + dawn.message)
	session.new_run()
	await frames()
	check(view._skip.visible, "看过后才可跳过")
	await click(view._skip)
	check(session.read_state().pending_event_id == "evt_intro_shop_inspection", "重看跳过保留教程")
	check("INTRO_LETTER_RECEIVED" in session.read_state().narrative_flags, "跳过保留剧情物品")
	await shot("repeat_arrival")
	print("OPENING ART UI: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
