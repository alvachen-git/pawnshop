extends "res://tests/integrated_ui_smoke.gd"

var received: Array = []

func _capture(label: String) -> void:
	await create_timer(0.2).timeout
	await super._capture(label)

func _run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("RECEIPT CONSISTENCY TIMEOUT"); quit(1))
	_capture_prefix = "receipt_consistency_1600" if "wide" in OS.get_cmdline_user_args() else "receipt_consistency_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	root.content_scale_size = root.size
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/goods_expertise_manifest.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	driver.check = _check; driver.catalog = _session._counter.catalog
	_session.definition._randomize_seed = false; _session.definition._seed = 42
	_session.new_run()
	_session.transaction_completed.connect(func(row: Dictionary) -> void: received.append(row))
	await _frames()
	driver.open(_session)
	var screen := _main.get_node("CounterScreen")
	var receipt: TradeReceiptView = screen._receipt
	var first := _session._counter.customers.active(_session._day.state)
	_check(_session.counter_command("offer", first.visit_id, "", first.trade.reserve_price).ok, "first sale commits")
	await _frames()
	_check(receipt.visible and receipt._stamp.visible and receipt._primary.text == "收好凭据", "first sale uses the same stamped receipt")
	_check(not screen._narrative.visible and receipt._detail.text.contains("顾叔"), "first account story included once in receipt")
	await _capture("01_first_sale")
	await _click_button(receipt._primary)
	_check(not receipt.visible and not screen._narrative.visible and "INTRO_FIRST_TRADE_DONE" in _session.read_state().narrative_flags, "one click completes first account event without a second screen")
	_check(_session._day.state.event_history.filter(func(row: Dictionary) -> bool: return row.event_id == "evt_intro_first_trade").size() == 1, "first event history recorded exactly once")
	var count := 0
	var fourth := false
	for night in range(2, 8):
		var state := _session._day.state
		state.current_night_index = night; state.phase = &"open"; state.game_minutes = 0
		state.pending_event_id = ""; state.pending_event_minute = -1
		_session._counter.customers.prepare_night(state, _session.definition, driver.catalog)
		var visits := state.visits.duplicate()
		for visit: CustomerVisit in visits:
			var customer := driver.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
			var definition := driver.catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
			var modes: Array = customer.transaction_modes if visit.transaction_modes.is_empty() else visit.transaction_modes
			if "sell" not in modes or not definition.ghost_rule_id.is_empty() or EarlyRedemption.is_visit(visit): continue
			# Isolate each real planned seller; fixture setup is not player progress.
			state.visits.assign([visit]); visit.status = "active"
			state.phase = &"open"; state.game_minutes = visit.arrival; state.cash = 10000
			var teapot := visit.visit_id.ends_with("/n4_visit2")
			if teapot: state.cash = 128
			state.pending_event_id = ""; state.pending_event_minute = -1
			_session.changed.emit()
			var before := received.size()
			var result := _session.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price if teapot else visit.trade.asking_price)
			_check(result.ok and received.size() == before + 1, "night %d %s emits one receipt" % [night, visit.visit_id])
			_check(receipt.visible and receipt._stamp.visible and receipt._primary.text == "收好凭据", "all sellers use one stamped layout")
			_check(not receipt._note.text.contains("有几分顾掌柜") and not receipt._note.text.contains("妇人收起钱"), "later sellers never inherit opening dialogue")
			if visit.voice.has("completed"): _check(receipt._note.text.contains(visit.voice.completed), "receipt uses this seller's actual completed voice")
			await _frames()
			_check(screen.get_global_rect().encloses(receipt._paper.get_global_rect()), "receipt fits viewport for actual seller voice")
			_check(receipt._paper.get_global_rect().encloses(receipt._primary.get_global_rect()), "receipt action remains on paper")
			if visit.visit_id.ends_with("/n4_visit2"):
				fourth = true
				_check(receipt._item.text == "紫砂小壶", "reproduce fourth-night teapot")
				await _capture("02_fourth_night_teapot")
				state.phase = &"night_resolution"
				_session.changed.emit()
				_check(receipt.visible, "committed receipt survives sealing-time refresh")
			var settled := _session.read_state()
			await _click_button(receipt._primary)
			_check(not receipt.visible and _session.read_state() == settled, "one-click acknowledgement never changes money goods or time")
			count += 1
	_check(fourth and count >= 20, "covered fourth-night regression and sellers across all later nights")
	# New service postings also use the same receipt pipeline, without exposing
	# unrevealed quality before the paid review has actually taken place.
	var state := _session._day.state
	state.phase = &"open"; state.current_night_index = 4; state.game_minutes = 0
	state.pending_event_id = ""; state.pending_event_minute = -1; state.visits.clear()
	var fan := ItemInstance.new()
	fan.instance_id = "receipt-review-fan"; fan.definition_id = GoodsExpertise.FAN; fan.selected_variant_id = "sound"
	fan.provenance = {"truth": "none", "status": "unchecked", "evidence": [], "investigated": false}
	state.inventory_instances.append(fan)
	var before := received.size()
	_check(_session.commerce_command("expert_fan", fan.instance_id).ok, "paid expert review commits")
	_check(received.size() == before + 1 and receipt._title.text == "行家复核结清" and receipt.visible, "paid review no longer omits receipt")
	await _frames(); await _capture("03_expert_receipt")
	await _click_button(receipt._primary)
	before = received.size()
	_check(not _session.commerce_command("expert_fan", fan.instance_id).ok and received.size() == before and not receipt.visible, "repeat review neither charges nor duplicates receipt")
	_session.new_run()
	_check(not receipt.visible, "new run clears old receipt")
	print("RECEIPT CONSISTENCY: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
