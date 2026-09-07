extends SceneTree

var failures := 0
var assertions := 0
var scene: Node
var save_path := "user://tests/title_menu_" + str(Time.get_ticks_usec()) + ".json"
var shots := "res://.artifacts/title-menu-check/screenshots/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(65.0).timeout.connect(func() -> void: push_error("TITLE MENU TEST TIMEOUT"); quit(1))
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start.tscn", "启动配置使用主菜单")
	await _spawn()
	var menu: TitleMenuView = scene.title_menu
	if "quit" in OS.get_cmdline_user_args():
		var point := menu.buttons[2].get_global_rect().get_center()
		await _move(point)
		create_timer(2.0).timeout.connect(func() -> void: push_error("退出未结束进程"); quit(1))
		print("TITLE MENU EXIT CLICK")
		# Do not leave an awaiting click coroutine alive while the tree quits.
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = point
			root.push_input(click, true)
		return
	var session: RunSession = scene.get_node("Bootstrap").session
	_check(menu.visible and not scene.get_node("CounterScreen").visible, "启动时只显示主菜单")
	_check(scene.get_node("CounterScreen").process_mode == Node.PROCESS_MODE_DISABLED, "主菜单阻断后台游戏输入")
	_check(menu.buttons.size() == 3 and menu.buttons[1].disabled, "三枚按钮齐全，无档时读取不可用")
	_check(not FileAccess.file_exists(save_path), "打开主菜单不写档")
	for button in menu.buttons:
		_check(is_zero_approx(button.hover_amount), "初始按钮不常驻红色")
	await _capture("idle")
	var before_state := session.read_state()
	for index in [0, 2]:
		await _move(menu.buttons[index].get_global_rect().get_center())
		await create_timer(1.2).timeout
		_check(menu.buttons[index].hover_amount > 0.98, "悬停变暗红 " + str(index))
		if index == 0: await _capture("hover-new")
		await _move(Vector2(1100, 450))
		await create_timer(1.2).timeout
		_check(is_zero_approx(menu.buttons[index].hover_amount), "移开恢复暗木色 " + str(index))
	_check(before_state == session.read_state(), "主菜单动效不改游戏状态")
	await _capture("released")
	await _key(KEY_HOME)
	await create_timer(1.0).timeout
	_check(menu.buttons[0].has_focus() and menu.buttons[0].hover_amount > 0.98, "键盘首页键选中新游戏")
	await _move(Vector2(1100, 450))
	await create_timer(1.0).timeout
	_check(is_zero_approx(menu.buttons[0].hover_amount), "切回鼠标后清除键盘高亮")
	await _click(menu.buttons[0])
	await _frames()
	_check(not scene.get_node("CounterScreen").is_processing() or scene.get_node("CounterScreen").process_mode == Node.PROCESS_MODE_INHERIT, "新游戏恢复处理")
	_check(scene.get_node("CounterScreen").visible and not is_instance_valid(menu), "新游戏进入柜台并释放主菜单")
	_check(session.read_state().current_night_index == 1, "新游戏从第一夜开始")
	_check(not FileAccess.file_exists(save_path), "新游戏按钮不提前覆盖存档")
	await _capture("new-game")
	var token: String = session.read_state().run_token
	var helper = preload("res://tests/integrated_test_driver.gd").new()
	helper.check = _check
	helper.catalog = session._counter.catalog
	helper.open(session)
	helper.finish(session, "covered")
	_check(FileAccess.file_exists(save_path), "实际夜末生成独立测试存档：" + session._save.error_message)
	if not FileAccess.file_exists(save_path): quit(1); return
	var bytes := FileAccess.get_file_as_bytes(save_path)
	await _spawn()
	menu = scene.title_menu
	_check(not menu.buttons[1].disabled, "有档时读取可用")
	await _move(menu.buttons[1].get_global_rect().get_center())
	await create_timer(1.1).timeout
	_check(menu.buttons[1].hover_amount > 0.98, "读取按钮悬停")
	await _move(Vector2(1100, 450))
	await create_timer(1.1).timeout
	_check(is_zero_approx(menu.buttons[1].hover_amount), "读取按钮移开复原")
	await _click(menu.buttons[0])
	_check(menu.confirmation.visible, "已有存档的新游戏要求确认")
	await _click(menu.confirmation.get_cancel_button())
	_check(not menu.confirmation.visible, "返回关闭新游戏确认框")
	_check(menu.visible and not scene.get_node("CounterScreen").visible, "取消后仍在主菜单")
	_check(FileAccess.get_file_as_bytes(save_path) == bytes, "取消不改存档")
	await _click(menu.buttons[1])
	await _frames()
	_check(scene.get_node("CounterScreen").visible and not is_instance_valid(menu), "读取后进入本体")
	_check(scene.get_node("Bootstrap").session.read_state().run_token == token, "恢复真实存档运行标识")
	_check(FileAccess.get_file_as_bytes(save_path) == bytes, "读档不重写存档")
	await _capture("loaded")
	await _spawn()
	menu = scene.title_menu
	await _click(menu.buttons[0])
	await _click(menu.confirmation.get_ok_button())
	_check(scene.get_node("CounterScreen").visible and not is_instance_valid(menu), "确认新游戏进入本体")
	_check(scene.get_node("Bootstrap").session.read_state().run_token != token, "确认新游戏建立新一局")
	_check(FileAccess.get_file_as_bytes(save_path) == bytes, "确认新游戏仍等待正常保存时机才替换旧档")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("broken-json")
	corrupt.close()
	await _spawn()
	menu = scene.title_menu
	await _click(menu.buttons[1])
	_check(menu.visible and menu.error_dialog.visible and not scene.get_node("CounterScreen").visible, "坏档保留主菜单并提示错误")
	_check(menu.error_dialog.dialog_text.contains("损坏"), "错误信息如实说明损坏")
	_check(FileAccess.get_file_as_string(save_path) == "broken-json", "读取失败不覆盖原文件")
	await _capture("load-error")
	await _click(menu.error_dialog.get_ok_button())
	_check(not menu.error_dialog.visible, "返回关闭读档错误框")
	# Real GUI input must emit exit; disconnect only tree quit so the test can report.
	menu.exit_requested.disconnect(scene._exit_game)
	var exited := [false]
	menu.exit_requested.connect(func() -> void: exited[0] = true)
	await _click(menu.buttons[2])
	_check(exited[0], "离开游戏按钮触发退出入口")
	ProjectSettings.set_setting("gui/accessibility/reduce_motion", true)
	await _spawn()
	menu = scene.title_menu
	await _move(menu.buttons[0].get_global_rect().get_center())
	await create_timer(0.5).timeout
	_check(menu.buttons[0].hover_amount == 1.0 and menu.buttons[0]._ink.modulate.a == 0.0, "减少动态保留颜色反馈并关闭重影")
	_check(menu._dim_amount == 0.0 and menu.buttons[0]._plaque.position == Vector2.ZERO, "减少动态关闭灯光和位移")
	await _move(Vector2(1100, 450))
	_check(menu.buttons[0].hover_amount == 0.0, "减少动态移开立即复原")
	ProjectSettings.set_setting("gui/accessibility/reduce_motion", null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	scene.queue_free()
	await _frames()
	print("TITLE MENU UI TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func _spawn() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames()
	scene = load("res://scenes/start.tscn").instantiate()
	scene.get_node("Bootstrap").save_path = save_path
	root.add_child(scene)
	await _frames()


func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event)
	await _frames()


func _click(button: BaseButton) -> void:
	var viewport := button.get_viewport()
	var point := button.get_global_rect().get_center()
	if viewport is Window and viewport != root and viewport.is_embedded():
		point += Vector2(viewport.position)
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await _frames()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)
		await _frames()


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event)
		await _frames()


func _frames() -> void:
	for index in 3: await process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var size_tag := "1600" if "wide" in OS.get_cmdline_user_args() else "1280"
	_check(image.save_png(shots + size_tag + "-" + label + ".png") == OK, "截图 " + label)


func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TITLE MENU FAIL: " + message)
