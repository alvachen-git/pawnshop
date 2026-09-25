extends "res://tests/lu_introduction_ui.gd"

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: quit(1))
	_main = load("res://scenes/start.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var sale := screen.lu_sale
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions; root.content_scale_size = dimensions
		_capture_prefix = "lu_sale_%d" % dimensions.x
		await restore_fixture("introduced")
		screen._close_drawer(); await _frames()
		await _click_button(screen._market_notice)
		_check(sale.visible and not screen.get_node("%Drawer").visible, "letter opens tray without business drawer")
		_check(screen._bell_blocked(), "tray blocks counter actions")
		var id: String = sale._buyer.stock[0].id
		await _click_button(sale.find_child("Pick_" + id.replace("/", "_"), true, false))
		_check(sale._selected == [id] and sale._submit.disabled, "pre-open quote selectable but delivery blocked")
		await _capture("01_preopen")
		await _click_button(sale._close)
		_check(not sale.visible and screen._market_notice.has_focus(), "close returns keyboard focus to letter")
		_check(_session.execute("open_shop").ok, "open shop")
		for guard in 20:
			var active := _session._counter.customers.active(_session._day.state)
			if active == null: break
			_session.counter_command("reject", active.visit_id)
		screen._departure_queue.clear(); screen._departure.hide(); screen._receipt.hide(); screen._cancel_feedback(true)
		screen._close_drawer(); await _frames()
		await _click_button(screen._market_notice)
		if sale._selected.is_empty(): await _click_button(sale.find_child("Pick_" + id.replace("/", "_"), true, false))
		_check(not sale._submit.disabled, "delivery becomes available after opening and clearing counter")
		var income: int = sale._preview.income
		var before := _session.read_state()
		await _click("价目明细")
		_check(sale._details, "actual details button opens prices")
		await _capture("02_details")
		sale.cancel(); await _frames()
		_check(not sale._details and sale.visible, "Escape closes detail before tray")
		_check(before == _session.read_state(), "browsing and selection do not spend money or time")
		# A last-moment rule rejection must keep the draft and not charge anything.
		_session._day.state.phase = &"pre_open"
		var blocked_before := _session.read_state()
		await _click_button(sale._submit)
		_check(sale.visible and sale._selected == [id] and not sale._error.is_empty(), "rejected delivery retains draft and shows reason")
		_check(_session.read_state() == blocked_before, "rejected delivery has no gameplay mutation")
		_session._day.state.phase = &"open"
		_session._notify_changed(); await _frames()
		screen._close_drawer(); await _frames()
		await _click_button(screen._market_notice)
		await _click_button(sale._submit)
		_check(not sale.visible, "successful delivery closes tray")
		_check(_session._day.state.cash == before.cash + income and _session._day.state.game_minutes == before.game_minutes + 20, "actual delivery matches quoted income and single trip time")
		_check(InventoryManager.new().find(_session._day.state, id).ownership_state == "sold", "actual selected stock sold")
		await _capture("03_receipt")
		# Visual-only read model fixture: multiple items, mixed eligibility and pagination.
		# Gameplay above uses a naturally acquired, codec-validated save.
		screen._receipt.hide(); screen._cancel_feedback(true); screen._close_drawer()
		var inventory: Dictionary = _session.counter_model().inventory.duplicate(true)
		var buyer: Dictionary = {}
		for entry in inventory.sales.buyers:
			if entry.id == "buyer_lu": buyer = entry
		buyer.reason = ""; buyer.wanted = "首饰"; buyer.stock = []; buyer.pairs = []
		inventory.visual.stock = []
		var names := ["银簪", "银戒", "银锁", "凤纹银镯", "青花碗"]
		var assets := ["placeholder.silver_hairpin", "goods.silver_ring", "goods.silver_lock", "fd.phoenix", "asset.item_blue_bowl"]
		for index in 5:
			buyer.stock.append({"id": "qa%d" % index, "name": names[index], "price": [32, 48, 64, 140, 0][index], "cost": 20, "premium": 0, "reason": "眼下只收首饰。" if index == 4 else ""})
			inventory.visual.stock.append({"id": "qa%d" % index, "name": names[index], "asset": assets[index]})
		sale.reset_draft(); sale._only_saleable = false; sale.present(inventory); await _frames()
		await _click_button(sale.find_child("Pick_qa0", true, false))
		await _click_button(sale.find_child("Pick_qa1", true, false))
		_check(sale._preview.income == 80 and not sale.find_child("SelectAll", true, false).button_pressed, "partial selection quote and all-checkbox correct")
		_check(sale.find_child("Pick_qa4", true, false).disabled, "wrong category cannot be selected")
		await _capture("04_selected")
		_check(_find_button(sale, "×") == null and _find_button(sale, "清空") == null, "receipt omits remove and clear controls")
		await _click_button(sale.find_child("Pick_qa1", true, false))
		_check(sale._selected == ["qa0"] and sale._preview.income == 32, "click selected stock again removes it from receipt")
		await _click_button(sale.find_child("Pick_qa1", true, false))
		await _click_button(sale.find_child("SaleFilter", true, false))
		_check(sale.find_child("Pick_qa4", true, false) == null and sale._selected.size() == 2, "salable filter hides ineligible item and preserves draft")
		await _click_button(sale.find_child("SelectAll", true, false))
		_check(sale._selected.size() == 4 and sale._preview.income == 284, "select all includes every eligible item")
		await _click_button(sale.find_child("SelectAll", true, false))
		_check(sale._selected.is_empty() and sale._submit.disabled, "toggle all off deselects goods and disables delivery")
		buyer.stock = []; sale.render(inventory); await _frames()
		_check(sale._submit.disabled, "empty inventory cannot submit")
		await _capture("05_empty")
		for index in 8:
			buyer.stock.append({"id": "many%d" % index, "name": "银戒", "price": 48, "cost": 20, "premium": 0, "reason": ""})
			inventory.visual.stock.append({"id": "many%d" % index, "name": "银戒", "asset": "goods.silver_ring"})
		sale.render(inventory); await _frames()
		await _click_button(sale.find_child("Pick_many0", true, false))
		await _click("下一页")
		await _click_button(sale.find_child("Pick_many7", true, false))
		_check(sale._selected.size() == 2 and sale._preview.income == 96, "pagination keeps selections across pages")
		buyer.pairs = [{"ids": ["many0", "many7"], "bonus": 40, "label": "原配银戒"}]
		sale.render(inventory); await _frames()
		await _click("原配银戒 +40")
		_check(sale._preview.income == 136 and sale._pairs.size() == 1, "opt-in original pair bonus enters exact preview")
		buyer.fixed_pair = ["many0", "many7"]; buyer.fixed_bonus = 40
		sale.render(inventory); await _frames()
		_check(sale._preview.income == 176, "fixed pair bonus also uses shared preview calculation")
		await _capture("06_pairs")
		inventory.sales.market_id = "changed-demand"
		sale.render(inventory); await _frames()
		_check(sale._selected.is_empty() and sale._pairs.is_empty(), "new demand clears stale quote draft")
		buyer.erase("fixed_pair"); buyer.erase("fixed_bonus"); buyer.pairs = []
		buyer.wanted = "文房"; buyer.stock = []; inventory.visual.stock = []
		var stationery_names := ["银簪", "赛璐珞钢笔", "端式砚台"]
		var stationery_assets := ["placeholder.silver_hairpin", "placeholder.fountain_pen", "placeholder.inkstone"]
		for index in 3:
			buyer.stock.append({"id": "stationery%d" % index, "name": stationery_names[index], "price": [0, 49, 21][index], "cost": 10, "premium": 0, "reason": "眼下只收文房。" if index == 0 else ""})
			inventory.visual.stock.append({"id": "stationery%d" % index, "name": stationery_names[index], "asset": stationery_assets[index]})
		sale._only_saleable = false; sale.render(inventory); await _frames()
		await _click_button(sale.find_child("SelectAll", true, false))
		await _capture("07_stationery")
		sale.hide()
	print("LU SALE UI: %d assertions, %d failures" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
