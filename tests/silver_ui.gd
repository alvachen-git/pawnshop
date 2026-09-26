extends "res://tests/ui_smoke.gd"

func restore_fixture(label: String) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/qa/silver/" + label + ".json"))
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new()
	var state := codec.decode(payload, _session.definition, 48, _session._counter.catalog, true)
	_check(state != null, "valid saved fixture " + label + " " + codec.error_message)
	if state == null: quit(1); return
	_session._day.state = state
	var store := preload("res://tests/shop_growth.gd").CountingStore.new(); store.origin = state.ghost_origin.duplicate(true)
	_session._save = store
	_session.restored.emit(); _session.changed.emit(); await _frames()

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(1))
	_main = load("res://scenes/start_silver_v48.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	_main.get_node("Bootstrap").save_library_path = ""
	root.add_child(_main); _session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var talk := screen.first_debt_conversation
	var sale := screen.lu_sale
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "silver/v48_%d" % dimensions.x
		await restore_fixture("intro-0"); await _frames()
		_check(talk.visible and not screen.get_node("%Drawer").visible, "RPG conversation uses scene, not business drawer")
		_check(screen._counter_view._portrait.texture.resource_path.ends_with("silver_owner_v48.png"), "dedicated portrait")
		var before := _session.read_state()
		await _capture("01_arrival")
		await _click_button(_find_button(talk, "收起 · Esc")); await _frames()
		_check(not talk.visible and before == _session.read_state() and not _session.can_execute("open_shop"), "collapse free, opening still blocked")
		screen._route_from_customer(&"dialogue"); await _frames()
		_check(talk.visible, "click customer resumes conversation")
		for step in 3:
			_check(_session._day.state.pending_event_id == SilverPolicy.EVENTS[step], "sequential RPG stage")
			for page in 12:
				if talk._choices.get_child_count() > 0: break
				talk._last_press = 0; await _click_button(talk._next)
			_check(talk._choices.get_child_count() == 1 and talk._speaker.text == "银楼掌柜", "independent response and correct speaker")
			await _capture("02_stage_" + str(step))
			await _click_button(talk._choices.get_child(0)); await _frames()
		_check(SilverPolicy.unlocked(_session._day.state) and _session._day.state.game_minutes == 0 and PreparationService.action_points(_session._day.state, _session.definition) == 2, "farewell unlocks with no resource cost")
		for page in 8:
			if not talk.visible: break
			talk._last_press = 0; await _click_button(talk._next)
		screen._flow.show_panel(&"day"); await _frames()
		var business := screen.get_node("%DayFlowPanel") as DayFlowPanel
		_check(business._buttons.has("sale/buyer_silversmith"), "business gains silver entry")
		await _capture("03_business")
		await _click_button(business._buttons["sale/buyer_silversmith"])
		_check(sale.visible and sale.buyer_id == SilverPolicy.BUYER and sale._buyer.preopen, "silver page selected")
		_check(_find_button(sale, "清空") == null and _find_button(sale, "×") == null, "no clutter controls")
		var id: String = sale._buyer.stock.filter(func(row: Dictionary) -> bool: return row.reason.is_empty())[0].id
		await _click_button(sale.find_child("Pick_" + id.replace("/", "_"), true, false))
		var details := _find_button(sale, "价目明细")
		_check(details.size == sale._submit.size and details.position.y == sale._submit.position.y, "equal aligned action buttons")
		_check(not sale._buyer.has("regime") and not sale._buyer.has("day"), "no hidden market type or phase fields")
		await _capture("04_selected")
		await _click_button(details); await _capture("05_details")
		sale.cancel(); await _frames()
		before = _session.read_state()
		var income: int = sale._preview.income
		_session._save.fail = true
		await _click_button(sale._submit)
		_check(sale.visible and sale._selected == [id] and not sale._error.is_empty() and _session.read_state() == before, "failed write preserves selected goods and resources")
		_session._save.fail = false
		await _click_button(sale._submit); await _frames()
		_check(screen._receipt.visible and _session._day.state.cash == before.cash + income and PreparationService.action_points(_session._day.state, _session.definition) == 1, "successful sale and one AP")
		await _capture("06_receipt")
		await _click_button(screen._receipt._primary); await _frames()
		_check(business.is_visible_in_tree() and screen._flow.get_active_panel_id() == &"day" and _session._day.state.game_minutes == 0, "receipt returns to preopening business")
		await _capture("07_return")
		# Presentation fixture only: explicit tagged corpse item; do not fabricate a story source.
		await restore_fixture("unlocked")
		var source: ItemInstance = _session._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state == "owned" and i.silver_trade.get("material") == "silver")[0]
		source.silver_trade.origin = "corpse"
		screen._open_business_sale(SilverPolicy.BUYER); await _frames()
		var refused: Dictionary = sale._buyer.stock.filter(func(row: Dictionary) -> bool: return row.id == source.instance_id)[0]
		_check(not refused.reason.is_empty() and (sale.find_child("Pick_" + source.instance_id.replace("/", "_"), true, false) as Button).disabled, "explicit forbidden source visibly rejected")
		await _capture("08_refusal")
		screen._close_drawer()
	_main.queue_free(); await _frames()
	print("SILVER UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
