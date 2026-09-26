extends "res://tests/ui_smoke.gd"

func restore_fixture(label: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/recycler/" + label + ".json"))
	var codec := SaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var state := codec.decode(payload, _session.definition, 47, _session._counter.catalog, true)
	_check(state != null, "recycler fixture loads " + label + " " + codec.error_message)
	if state == null: quit(1); return
	_session._day.state = state
	var store := preload("res://tests/shop_growth.gd").CountingStore.new()
	store.origin = state.ghost_origin.duplicate(true)
	_session._save = store
	_session.restored.emit(); _session.changed.emit()
	await _frames()

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	_main = load("res://scenes/start_recycler_v47.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	_main.get_node("Bootstrap").save_library_path = ""
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var sale := screen.lu_sale
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "recycler/v47_%d" % dimensions.x
		for first_phase in ["first-preopen", "first-open"]:
			await restore_fixture(first_phase)
			screen._flow.show_panel(&"day"); await _frames()
			var first_business := screen.get_node("%DayFlowPanel") as DayFlowPanel
			_check(not first_business._buttons.keys().any(func(id: String) -> bool: return id.begins_with("sale/")), "first night has no sale entry " + first_phase)
			var first_before := _session.read_state()
			screen._open_business_sale(RecyclerPolicy.BUYER); await _frames()
			_check(not sale.visible and first_before == _session.read_state(), "stale first-night route cannot open sale sheet")
			await _capture("00_" + first_phase)
		await restore_fixture("preopen")
		screen._flow.show_panel(&"inventory"); await _frames()
		var inventory := screen.get_node("%InventoryPanel") as InventoryPanel
		_check(not inventory._tabs.get_child(2).is_visible_in_tree(), "inventory sale tab removed")
		await _capture("01_inventory")
		screen._flow.show_panel(&"day"); await _frames()
		var business := screen.get_node("%DayFlowPanel") as DayFlowPanel
		var before := _session.read_state()
		await _capture("02_business")
		await _click_button(business._buttons["sale/buyer_recycler"])
		_check(sale.visible and sale.buyer_id == RecyclerPolicy.BUYER and not screen.get_node("%Drawer").visible, "business opens recycler sheet")
		var id: String = sale._buyer.stock[0].id
		await _click_button(sale.find_child("Pick_" + id.replace("/", "_"), true, false))
		_check(sale._selected == [id] and not sale._submit.disabled, "preopening selection allows delivery")
		var details := _find_button(sale, "价目明细")
		_check(details.position.y == sale._submit.position.y and details.size == sale._submit.size and details.position.x < sale._submit.position.x, "equal aligned buttons")
		_check(_find_button(sale, "清空") == null and _find_button(sale, "×") == null, "no clear or removal buttons")
		await _capture("03_selected")
		await _click_button(details)
		_check(sale._details, "price details opens")
		await _capture("04_details")
		sale.cancel(); await _frames()
		await _click_button(sale._close)
		_check(not sale.visible and business.is_visible_in_tree(), "closing returns to business")
		await _click_button(business._buttons["sale/buyer_recycler"])
		_check(sale._selected == [id] and _session.read_state() == before, "same-day draft retained and all browsing free")
		# Real save failure must leave the sheet open with the selected goods.
		_session._save.fail = true
		await _click_button(sale._submit)
		_check(sale.visible and sale.buyer_id == RecyclerPolicy.BUYER and sale._selected == [id] and not sale._error.is_empty(), "failed save retains recycler draft and error")
		_check(before == _session.read_state(), "failed click rolls back state")
		_session._save.fail = false
		var income: int = sale._preview.income
		await _click_button(sale._submit)
		_check(not sale.visible and _session._day.state.cash == before.cash + income and PreparationService.action_points(_session._day.state, _session.definition) == 1 and _session._day.state.game_minutes == 0, "actual click commits one AP without time")
		await _frames()
		_check(screen._receipt.is_visible_in_tree() and not screen.get_node("%Drawer").visible, "completed sale shows its receipt before returning")
		_check(_session._day.state.phase == &"pre_open" and _session._day.state.current_night_index == 2 and _session._day.state.game_minutes == 0, "sale preserves opening phase, night and time")
		await _capture("05_receipt")
		await _click_button(screen._receipt._primary)
		_check(business.is_visible_in_tree() and screen._flow.get_active_panel_id() == &"day", "closing receipt returns to business, not night settlement")
		await _capture("05_after_sale")
		await restore_fixture("no-points-stock")
		screen._open_business_sale(RecyclerPolicy.BUYER); await _frames()
		id = sale._buyer.stock[0].id
		await _click_button(sale.find_child("Pick_" + id.replace("/", "_"), true, false))
		_check(sale._submit.disabled, "no AP still permits browsing but not delivery")
		await _capture("06_no_points")
		await restore_fixture("preopen")
		_check(sale._selected.is_empty(), "load clears draft")
		# Existing letter must still select Lu's identity, portrait and demand.
		screen._close_drawer(); await _frames()
		screen._market_notice.pressed.emit(); await _frames()
		_check(sale.visible and sale.buyer_id == "buyer_lu" and sale._buyer.name == "陆掌眼", "Lu letter retains separate buyer")
		await _capture("07_lu")
		screen._close_drawer()
	_main.queue_free(); await _frames()
	print("RECYCLER UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
