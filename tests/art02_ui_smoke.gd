extends "res://tests/m5_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "art02_1600" if "wide" in OS.get_cmdline_user_args() else "art02_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/art02_review.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	if _session == null:
		_check(false, "美术样板必须成功载入")
		quit(1)
		return
	_seed_repaired_and_plated()
	await _resolve_events()
	await _click("营业")
	await _click("开铺")
	await _click("收起 · Esc")
	await _capture("01_customer_bowl")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var item_image := screen.get_node("CounterView/CounterItemImage") as TextureRect
	var item_hotspot := (screen.get_node("CounterView") as CounterView).get_hotspot(&"item")
	_check(item_image.texture != null, "柜台显示青花碗独立轮廓")
	var before := _session.read_state()
	await _click_control(item_hotspot)
	_check(_find_button(_main, "鉴定") != null, "点击柜台物品只显示鉴定入口")
	await _click("鉴定")
	var appraisal := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
	_check(appraisal.is_visible_in_tree(), "点击情境入口打开鉴定")
	_check(appraisal._images.size() == 2, "未知品相只有正背面，无缺陷图")
	await _capture("02_appraisal_front")
	await _click("背面")
	_check(appraisal._selected == "back", "真正切换物品背面")
	await _capture("03_appraisal_back")
	await _click("正面")
	_check(_session.read_state() == before, "点货物和翻面不耗时、不生成证据")
	await _click("对话")
	await _intent("dialogue", "question", "repairs")
	_check(_session.counter_model().visual.clues.is_empty(), "口供不能产生实物线索")
	await _click("鉴定")
	await _intent("appraisal", "appraise", "light")
	_check(appraisal._images.size() == 3 and appraisal._selected == "repaired", "侧光取证后才出现并选中接缝局部图")
	await _capture("04_bowl_detail")
	await _click("对话")
	await _intent("dialogue", "question", "seam")
	var dialogue := _main.find_child("DialoguePanel", true, false) as DialoguePanel
	_check(dialogue._body.text.contains(_session.counter_model().visual.speech.back().answer), "当前口供显示真实问答结果")
	_check(dialogue._body.text.count(_session.counter_model().visual.speech.back().answer) == 1, "同一口供不与操作反馈重复展示")
	await _capture("05_testimony")
	await _click(dialogue._history_toggle.text)
	_check(dialogue._history.visible and dialogue._history.text.contains(_session.counter_model().visual.speech.front().answer), "可复查此前问过的口供")
	await _click(dialogue._history_toggle.text)
	await _click("交易")
	var trade := _find_trade(_main)
	_check(trade._ask_value.text == str(_session.counter_model().trade.asking_price), "报价栏与真实要价一致")
	_check(trade._estimate_value.text == _session.counter_model().visual.estimate, "证据估值分列，不使用底价")
	await _capture("06_trade")
	var price: int = _session.counter_model().trade.asking_price
	var cash: int = _session.read_state().cash
	trade._price.value = price
	await _click("正式报价并收购")
	_check(_session.read_state().cash == cash - price and _session.counter_model().active_id.is_empty(), "新界面完成真实收购")
	_check(item_image.texture == null and not item_hotspot.visible, "成交后清除旧物品图像与热点")
	await _capture("07_purchase")
	await _wait_to(90)
	await _click("收起 · Esc")
	_check(item_image.texture.resource_path.contains("holder_front"), "下一客切换为烛台，没有旧物品残留")
	await _capture("08_hawker_holder")
	await _click("鉴定")
	_check(appraisal._selected == "front" and appraisal._images.size() == 2, "换客时恢复正面并清除旧线索图")
	await _intent("appraisal", "appraise", "magnet")
	_check(appraisal._images.size() == 2, "磁针结论不提前泄露底部划痕图片")
	await _intent("appraisal", "appraise", "scratch")
	_check(appraisal._selected == "plated", "取得划痕后显示灰芯局部图")
	await _capture("09_holder_detail")
	await _click("交易")
	await _intent("trade", "pressure", "iron_core")
	trade._pawn_price.value = _session.counter_model().trade.pawn_asking
	await _click("正式报价并活当")
	_check(_session.read_state().pawn_tickets.size() == 1, "活当报价仍能出票")
	await _new_m5()
	await _third_m5()
	_check(_session.risk_model().held_ids.size() == 1, "铜镜通过新鉴定和议价界面收购")
	await _click("盖好红布 · 10分钟")
	await _finish_m5()
	_check(_session.read_state().summaries.back().outcome == "mirror_safe", "美术变化保留铜镜规则与安全结算")
	# Validate the entire portrait family and imported item/detail assets.
	for asset in CounterVisualCatalog.PORTRAITS:
		_check(CounterVisualCatalog.portrait(asset) != null, "角色模板可载入：" + asset)
	_check(screen.get_node("%ShopStatusView").get_global_rect().end.y <= screen.size.y + 0.1, "底栏保持完整可见")
	print("ART02 UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _intent(feature: String, command: String, detail: String) -> void:
	for entry in _session.counter_model()[feature].buttons:
		if entry.command == command and entry.detail == detail:
			await _click(entry.label)
			return
	_check(false, "找不到可见行动：%s/%s" % [command, detail])

func _wait_to(minute: int) -> void:
	await _click("营业")
	var attempts := 0
	while int(_session.read_state().game_minutes) < minute:
		attempts += 1
		if attempts > 30:
			_check(false, "等待顾客的测试流程必须能够推进")
			quit(1)
			return
		await _resolve_events()
		await _click("营业")
		await _click("等待 · 60 分钟" if minute - int(_session.read_state().game_minutes) >= 60 else "歇一歇 · 5 分钟")
	await _resolve_events()

func _seed_repaired_and_plated() -> void:
	# Test-only deterministic setup, before any gameplay; production remains random.
	for seed_value in 300:
		_session._day.state.run_seed = seed_value
		_session._day.state.scenario_selections.clear()
		_session._counter.customers.prepare_night(_session._day.state, _session.definition, _session._counter.catalog)
		if _session._day.state.visits[0].item.selected_variant_id == "repaired" and _session._day.state.visits[1].item.selected_variant_id == "plated":
			_session.changed.emit()
			return
	_check(false, "可生成两个有瑕疵的美术验收样本")

func _click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()
