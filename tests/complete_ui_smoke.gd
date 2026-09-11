extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa/complete_ui"))
	create_timer(300).timeout.connect(func() -> void: quit(1))
	_capture_prefix = "complete_1600" if "wide" in OS.get_cmdline_user_args() else "complete_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/complete_seven_manifest.json"
	_main.get_node("Bootstrap").save_path = "user://complete_seven/autosave_v19.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	_session._save.library.path = "res://.godot/qa/complete_ui/ui_%d.json" % Time.get_ticks_usec()
	_main.title_menu.configure(true, false)
	_session.definition._randomize_seed = false
	for seed_value in 128:
		var initial := MarketService.current(_session.definition, seed_value, 1, 0)
		if MarketService.demand(_session.definition, initial).category == "jewelry":
			_session.definition._seed = seed_value; break
	driver.check = _check; driver.catalog = _session._counter.catalog
	narrative = _main.get_node("CounterScreen/NarrativeScene")
	await _frames()
	await _click_button(_main.title_menu.buttons[0])
	driver.open(_session)
	_check(_session.definition.id == "complete_seven", "unified default entry")
	await _frames()
	await _click("库存"); await _click("卖货")
	await _click("选择买家 · 陆掌眼")
	var panel := _main.find_child("InventoryPanel", true, false) as InventoryPanel
	_check(panel._sale_view._submit.disabled and panel._sale_view._total.text.contains("店里还有客人"), "new default guest blocks trip")
	_check(panel._sale_view._total.text.contains("当前不能交货，以下为试算"), "blocked batch marked trial")
	_check(panel._cash_flow.visible and panel._cash_flow.get_child(0).text.contains("留足息费"), "inventory overview visible")
	await _capture("01_guest_blocked")
	await _click("交易")
	var visit := _session._counter.customers.active(_session._day.state)
	_find_trade(_main)._price.value = visit.trade.asking_price
	await _click("正式报价并收购")
	await receipts(); driver.drain(_session); await _frames()
	var notice := _main.get_node("CounterScreen/MarketNotice") as Button
	_check(notice.visible and not notice.disabled, "public counter notice available")
	await _click_button(notice)
	await _click("选择买家 · 陆掌眼")
	await _click("选中全部可售货物")
	_check(not panel._sale_view._submit.disabled, "real acquired hairpin matches initial demand")
	await _scroll_market(panel._sale_view._submit)
	await _capture("02_lu_quote")
	var before := _session.read_state()
	var selection_before := panel._sale_view._selected.duplicate()
	_check(not selection_before.is_empty(), "selected batch exists before channel change")
	await _click("更换买家")
	_check(panel._sale_view._selected.is_empty(), "changing buyer clears previous batch")
	var recycler: Dictionary = _session.counter_model().inventory.sales.buyers.filter(func(b: Dictionary) -> bool: return b.id == "buyer_recycler")[0]
	await _click("选择买家 · " + recycler.name)
	_check(panel._sale_view._selected.is_empty() and panel._sale_view._submit.disabled, "new buyer does not inherit an executable batch")
	await _click("选中全部可售货物")
	await _click("取消选货")
	_check(panel._sale_view._selected.is_empty() and panel._sale_view._buyer.is_empty(), "cancel clears buyer and batch")
	await _click("选择买家 · 陆掌眼")
	await _click("选中全部可售货物")
	_check(panel._sale_view._selected == selection_before, "return to Lu uses current stock only")

	var sales: Dictionary = _session.counter_model().inventory.sales
	var buyer: Dictionary = sales.buyers.filter(func(b: Dictionary) -> bool: return b.id == "buyer_lu")[0]
	var preview := CashFlowReadModel.sale_preview(sales.cash_flow, buyer, panel._sale_view._selected)
	_check(panel._sale_view._total.text.contains("成交后预计现银"), "cash after selected sale shown")
	await _click("完成交易 · 20分钟")
	_check(_session._day.state.game_minutes == before.game_minutes + 20 and _session._day.state.sale_records.back().buyer_id == "buyer_lu", "real UI Lu sale takes twenty minutes")
	await create_timer(0.3).timeout
	await _capture("03_lu_receipt")
	await receipts()
	_check(_session._day.state.cash == preview.cash, "visible preview matches actual cash")
	await _click("账本")
	await _click("债务")
	var ledger := _main.find_child("LedgerPanel", true, false) as LedgerPanel
	_check(ledger._model.cash_flow == panel._model.cash_flow, "ledger and inventory share flow numbers")
	await _capture("04_debt")
	var fingerprint := SaveLibrary.fingerprint(_session._day.state)
	await _click("流水"); await _click("当票"); await _click("库存"); await _click("铺中货物")
	var tab_key := InputEventKey.new()
	tab_key.keycode = KEY_TAB; tab_key.pressed = true
	Input.parse_input_event(tab_key)
	await _frames()
	tab_key = InputEventKey.new(); tab_key.keycode = KEY_TAB; tab_key.pressed = false
	Input.parse_input_event(tab_key)
	var focused := root.gui_get_focus_owner()
	_check(focused != null and focused.is_visible_in_tree(), "keyboard tab stays on visible controls")
	_check(SaveLibrary.fingerprint(_session._day.state) == fingerprint, "viewing and tabs do not dirty save")
	await _capture("05_inventory")
	driver.work(_session, "covered"); driver.finish(_session, "covered")
	for night in [2, 3]: driver.open(_session); driver.work(_session, "covered"); driver.finish(_session, "covered")
	driver.drain(_session)
	_check(_session.execute("prep_investigate").ok, "investigate existing appointment")
	await _frames()
	await _click("营业")
	await _capture("04_preparation")
	driver.open(_session)
	await receipts()
	var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	await _click_button(notice)
	await _click("查看往来口信")
	var history: String = _session.counter_model().inventory.sales.history
	_check(history.contains(PreparationService.DETAILS) and history.contains("陆掌眼"), "known appointment and Lu history coexist")
	var history_label := panel._sale_view.get_child(panel._sale_view.get_child_count() - 1) as Label
	var ancestor := history_label.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.scroll_vertical += roundi(history_label.global_position.y - ancestor.global_position.y)
		ancestor = ancestor.get_parent()
	await _frames()
	await _capture("05_shared_history")
	print("COMPLETE UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)

func _scroll_market(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await _frames()
