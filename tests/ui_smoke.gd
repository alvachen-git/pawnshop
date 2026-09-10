extends SceneTree

var _main: Node
var _session: RunSession
var _failures := 0
var _assertions := 0
var _capture_prefix := "m1"
var _save_path := "user://tests/ui_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m3_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	await _capture("01_pre_open")
	var before := _session.read_state()
	for label in ["库存", "账本", "夜间结算", "营业"]:
		await _click(label)
	var counter_view := _main.get_node("CounterScreen/CounterView") as CounterView
	_check(not counter_view.get_hotspot(&"customer").visible and not counter_view.get_hotspot(&"item").visible, "无客无货时不显示情境入口")
	await create_timer(1.0).timeout
	_check(_session.read_state() == before, "现实等待和面板查看不耗时")
	await _click("开铺")
	_check(_session.read_state().phase == "open", "鼠标开铺")
	await _click("等待 · 60 分钟")
	await _click("关门（本夜不可重开）")
	_check(_session.read_state().phase == "closed_processing", "鼠标关门")
	await _capture("02_closed")
	await _click("整理桌面（占位） · 10 分钟")
	_check(_session.read_state().game_minutes == 70, "关门后行动耗时")
	await _click("等到封铺（消耗全部剩余时间）")
	_check(_session.read_state().phase == "night_resolution", "封铺自动切换夜间面板")
	await _capture("03_sealed")
	await _click("结算本夜（占位）并自动保存")
	_check(_session.read_state().phase == "day_summary", "UI结算与自动保存")
	await _capture("04_summary")
	await _click("进入下一夜")
	_check(_session.read_state().current_night_index == 2, "UI进入下一夜")
	await _click("开铺")
	await _click("短行动（占位） · 5 分钟")
	await _click("读取夜末存档")
	await _frames()
	var dialog := _find_dialog(_main)
	_check(dialog != null and dialog.visible, "读取存档有丢弃进度确认")
	await create_timer(0.3).timeout
	await _capture("06_load_confirmation")
	if dialog != null:
		await _click_button(dialog.get_ok_button())
	_check(_session.read_state().phase == "pre_open" and _session.read_state().game_minutes == 0, "确认后恢复下一夜开铺前检查点")
	for night in 2:
		await _click("开铺")
		await _click("等到封铺（消耗全部剩余时间）")
		await _click("结算本夜（占位）并自动保存")
		await _click("进入下一夜" if night == 0 else "结束本轮试玩")
	_check(_session.read_state().phase == "run_ended", "UI三夜日循环闭环")
	await _capture("05_finished")
	await _click("营业")
	await _click("新游戏")
	dialog = _find_dialog(_main)
	await create_timer(0.3).timeout
	if dialog != null:
		await _click_button(dialog.get_cancel_button())
	_check(_session.read_state().phase == "run_ended", "取消新游戏不改变运行")
	print("UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _click(label: String) -> void:
	# Historical flow suites acknowledge the new presentation-only receipt
	# before their next action. receipt_ui_smoke verifies the page explicitly.
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	if receipt != null and receipt.visible and label not in ["收好凭据", "查看库存", "查看当票"]:
		await _click_button(receipt._primary)
	# Departure pages are acknowledged before continuing historical flow tests.
	# customer_departure_ui_smoke checks their content and input explicitly.
	await _frames()
	var departure := _main.find_child("CustomerDeparture", true, false) as TradeReceiptView
	for guard in 50:
		if departure == null or not departure.visible or label in ["继续接待", "继续当前接待", "知道了"]: break
		await _click_button(departure._primary)
		await _frames()
	var scene_routes := {
		"营业": &"shop",
		"库存": &"inventory",
		"账本": &"ledger",
	}
	if scene_routes.has(label):
		# Painted shortcuts can be visible in the tree while occluded by the drawer.
		# Close it with real input before using the original scene hotspot.
		var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
		if close.is_visible_in_tree(): await _click_button(close)
		var counter_view := _main.get_node("CounterScreen/CounterView") as CounterView
		await _click_button(counter_view.get_hotspot(scene_routes[label]))
		return
	if label in ["对话", "交易"] and _find_button(_main, label) == null:
		var counter_view := _main.get_node("CounterScreen/CounterView") as CounterView
		await _click_button(counter_view.get_hotspot(&"customer"))
	if label == "鉴定" and _find_button(_main, label) == null:
		var counter_view := _main.get_node("CounterScreen/CounterView") as CounterView
		await _click_button(counter_view.get_hotspot(&"item"))
	if label == "更多":
		label = "菜单"
	# Secondary entries and run lifecycle controls live in the grouped menu.
	if label in ["铺中记事", "鬼货与绝当录", "夜间结算", "新游戏", "读取夜末存档"] and _find_button(_main, label) == null:
		await _click("菜单")
	var button := _find_button(_main, label)
	if button == null:
		var hidden := _find_any_button(_main, label)
		var parent: Node = hidden
		while parent != null and not parent is FeaturePanel: parent = parent.get_parent()
		if parent is FeaturePanel:
			var title: String = CounterScreen.PANEL_TITLES.get(String(parent.get_panel_id()), "")
			if not title.is_empty() and title != label:
				await _click(title)
				button = _find_button(_main, label)
	# Open the actual account tab / item disclosure before clicking its action.
	if button == null:
		var hidden := _find_any_button(_main, label)
		var ancestor: Node = hidden
		var reveals: Array[String] = []
		while ancestor != null:
			if ancestor.has_meta("reveal_label"): reveals.push_front(str(ancestor.get_meta("reveal_label")))
			ancestor = ancestor.get_parent()
		for reveal in reveals:
			await _click(reveal)
		button = _find_button(_main, label)
	_check(button != null, "可找到按钮：" + label)
	if button != null:
		await _click_button(button)

func _click_button(button: Button) -> void:
	_check(not button.disabled and button.is_visible_in_tree(), "按钮可见且可操作：" + button.text)
	if button.disabled:
		return
	button.grab_focus()
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _frames()

	# Dispatch real viewport mouse input, not a synthetic pressed signal.
	var viewport := button.get_viewport()
	var point := button.get_global_rect().get_center()
	if viewport is Window and viewport != root and viewport.is_embedded():
		point += Vector2(viewport.position)
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		viewport.push_input(event, true)
	await _frames()

func _click_trade_intent(command: String, detail: String) -> void:
	for panel in _main.find_children("*", "", true, false):
		if not panel is TradePanel: continue
		for button in panel._buttons.get_children():
			if button is Button and button.get_meta("trade_command", "") == command and button.get_meta("trade_detail", "") == detail:
				await _click_button(button)
				return
	_check(false, "缺少交易操作：" + command + "/" + detail)

func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node.text == label or node.accessibility_name == label) and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null

func _find_dialog(node: Node) -> ConfirmationDialog:
	if node is ConfirmationDialog:
		return node
	for child in node.get_children():
		var found := _find_dialog(child)
		if found != null:
			return found
	return null

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var error := root.get_texture().get_image().save_png("res://.godot/qa/" + _capture_prefix + "_" + label + ".png")
	_check(error == OK, "已保存实际渲染截图：" + label)

func _frames() -> void:
	await process_frame
	await process_frame

func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures += 1
		push_error("UI FAIL: " + label)

func _find_any_button(node: Node, label: String) -> Button:
	if node is Button and (node.text == label or node.accessibility_name == label): return node
	for child in node.get_children():
		var found := _find_any_button(child, label)
		if found != null: return found
	return null
