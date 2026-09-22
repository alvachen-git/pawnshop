extends "res://tests/integrated_ui_smoke.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("GROWTH UI TIMEOUT"); quit(1))
	_capture_prefix = "growth_1600" if "wide" in OS.get_cmdline_user_args() else "growth_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/start.tscn").instantiate()
	_main.get_node("Bootstrap").save_path = "user://tests/growth_ui/auto.json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var store := GhostReplayStore.new(); store.origin = _session._day.state.ghost_origin
	_session._save = store
	await _frames()
	await _capture("00_title")
	await _click_button(_main.title_menu.buttons[0])
	_check(_session.content_version == 25 and _session.definition.id == "shop_growth_ten", "default growth new game")
	install("preparation")
	await service()
	await _click_button(_main.get_node("CounterScreen").facilities.room.hotspots.bench)
	await _capture("01_before_build")
	var cash := _session._day.state.cash
	await _click("整修鉴物台 · 40银元 / 准备1次")
	await _click_button(_main.get_node("CounterScreen").facilities.room.hotspots.display)
	await _click("整修陈列柜 · 60银元 / 准备1次")
	_check(_session._day.state.cash == cash - 100 and PreparationService.count(_session._day.state) == 2, "UI actually buys facilities")
	await _capture("02_built")
	await _click_button(_main.get_node("CounterScreen").facilities.room.hotspots.display)
	await _click("陈列：银簪")
	_check(not _session._day.state.shop_growth.display_id.is_empty(), "UI chooses stock")
	await _capture("03_display")
	install("closed")
	await service(); await _click_button(_main.get_node("CounterScreen").facilities.room.hotspots.archive)
	await _click("整理旧账 · 15分钟")
	await _capture("04_directory")
	await _click("核对柜号 · 15分钟")
	await _click("检查夹板 · 20分钟")
	_check(_session._day.state.shop_growth.exploration.size() == 3, "UI completes cabinet local route")
	await _capture("05_compartment")
	install("buyer")
	await buyer_page()
	await _capture("06_buyer_offer")
	_check(_find_button(_main, "正式报价并收购") == null and _find_button(_main, "正式报价并活当") == null, "no seller operations on buyer UI")
	var panel := _find_trade_panel(_main)
	panel._growth_amount.grab_focus()
	var offer: int = ShopGrowthService.opportunity(_session._day.state).offer
	for character in str(offer + 1):
		var event := InputEventKey.new(); event.pressed = true; event.unicode = character.unicode_at(0)
		root.push_input(event, true)
	await _click_button(panel._growth_counter)
	_check(ShopGrowthService.opportunity(_session._day.state).has("decision"), "real keyboard counter offer resolves")
	await _capture("07_counter_result")
	await receipts()
	install("buyer")
	await buyer_page()
	await _click("接受报价 · 5分钟")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	_check(screen._recent.get("kind", "") == "sale" and screen._receipt.is_visible_in_tree(), "onsite sale shows committed receipt")
	await create_timer(0.35).timeout
	await _capture("08_receipt")
	_check(_session._day.state.sale_records.size() == 1, "real accept sells once")
	await receipts()
	_check(screen._recent_button.is_visible_in_tree(), "receipt can be reopened after acknowledgment")
	install("ending")
	await _click("夜间结算")
	await _capture("09_summary")
	print("SHOP GROWTH UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)

func service() -> void:
	await receipts()
	var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	await _click_button(_main.get_node("CounterScreen/%MenuButton"))
	await _click("修缮与查铺")
	await create_timer(0.6).timeout

func buyer_page() -> void:
	await receipts()
	var close := _main.get_node("CounterScreen/%CloseDrawerButton") as Button
	if close.is_visible_in_tree(): await _click_button(close)
	var view := _main.get_node("CounterScreen/CounterView") as CounterView
	await _click_button(view.get_hotspot(&"customer"))
	await _click("议价售货")

func install(stage: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/shop-growth/" + stage + ".json"))
	var codec := SaveCodec.new()
	var state := codec.decode(data, _session.definition, 25, _session._counter.catalog, true)
	_check(state != null, "validated UI fixture " + stage + " " + codec.error_message)
	if state == null: return
	_session._day.state = state
	_session.message = ""
	_session.restored.emit()
	_session.changed.emit()
