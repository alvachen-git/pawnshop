extends "res://tests/m6_ui_smoke.gd"

var helper := VarietyTests.new()
var portrait_seeds: Dictionary = {}
var bowl_seed := -1
var late_seed := -1

func seed_game(seed_value: int) -> void:
	_session.new_run()
	_session._day.state.run_seed = seed_value
	_session._day.state.ordinary_selections.clear()
	_session._day.state.scenario_selections.clear()
	_session._counter.customers.prepare_night(_session._day.state, _session.definition, helper.catalog)
	helper.open(_session)
	await _frames()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE; esc.pressed = true
	root.push_input(esc)
	await _frames()

func _run() -> void:
	_capture_prefix = "variety_1600" if "wide" in OS.get_cmdline_user_args() else "variety_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://data/legacy/content_v10.json"
	_main.get_node("Bootstrap").save_path = "user://tests/" + _capture_prefix + ".json"
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	helper._expect = _check
	helper.catalog = _session._counter.catalog
	helper.run_def = _session.definition
	for seed_value in 256:
		var row: Dictionary = VarietyService.plan(helper.run_def, helper.catalog, seed_value)[0]
		if not portrait_seeds.has(row.customer_id): portrait_seeds[row.customer_id] = seed_value
		if bowl_seed < 0 and row.item_id == "item_blue_bowl" and row.source == "authentic": bowl_seed = seed_value
		if late_seed < 0 and row.customer_id == "customer_teahouse" and row.situation == "ordinary": late_seed = seed_value
	for customer in ["seamstress", "watchmaker", "teahouse", "bookkeeper"]:
		await seed_game(portrait_seeds["customer_" + customer])
		_check(_session.counter_model().visual.portrait_asset == "asset.customer_" + customer, "distinct portrait asset " + customer)
		await _capture("portrait_" + customer)
	await seed_game(portrait_seeds.customer_watchmaker)
	var watch_model := _session.counter_model()
	for entry in watch_model.appraisal.buttons:
		if entry.command == "appraise":
			_session.counter_command("appraise", watch_model.active_id, entry.detail)
			break
	await _click("交易")
	var trade := _find_trade(_main)
	_check(not trade._body.text.contains("耐心") and not trade._body.text.contains("最迟留到") and trade._metrics.get_child_count() == 2, "trade panel hides patience and deadline system data")
	_check(trade._bargain_toggle.visible, "revealed evidence is collected behind the bargain menu")
	_check(trade._purchase_mode.button_pressed and trade._price.visible and not trade._pawn_price.visible, "purchase mode uses the shared amount slot")
	await _click_button(trade._bargain_toggle)
	_check(trade._bargain_popup.visible and root.get_visible_rect().encloses(trade._bargain_popup.paper.get_global_rect()), "bargain dialog opens inside the viewport")
	await _capture("01b_bargain_menu")
	await _click_button(trade._bargain_popup.close_button)
	_check(not trade._bargain_popup.visible, "bargain menu closes without leaving the form scrolled open")
	await _click_button(trade._pawn_mode)
	_check(trade._pawn_mode.button_pressed and trade._pawn_price.visible and not trade._price.visible and trade._terms.text.contains("期限"), "pawn mode reuses the amount slot and shows its terms")
	await _click_button(trade._purchase_mode)
	await _capture("01_watchmaker_rules")
	trade._price.value = 1
	await _click("正式报价并收购")
	_check(_session.read_state().visit_history[0].outcome == "patience_exhausted", "UI failed price leaves immediately")
	await seed_game(bowl_seed)
	await _click("对话")
	await _click("问：这件东西从哪里来？ · 5分钟")
	await _click("问：青花小碗有哪些旧处？ · 5分钟")
	await _capture("02_testimony")
	await _click("鉴定")
	await _click("核对来源凭据与原物 · 5分钟")
	var panel := _main.find_child("AppraisalPanel", true, false) as AppraisalPanel
	_check(panel._body.text.contains("已证实") and not panel._body.text.contains("true_value"), "verified source rendered without hidden fields")
	await _capture("03_verified")
	await _click("交易")
	trade._price.value = helper.active(_session).trade.reserve_price
	await _click("正式报价并收购")
	helper.wait_to(_session, 60)
	await _click("库存")
	var item: ItemInstance = _session._day.state.inventory_instances[0]
	var label := ""
	for button in _session.counter_model().inventory.buttons:
		if button.detail == "buyer_collector": label = button.label
	await _click("查看货物 · 青花小碗")
	await _capture("04_premium_quote")
	await _click(label)
	await _settle_feedback()
	await _click_button((_main.get_node("CounterScreen") as CounterScreen)._recent_button)
	var receipt := _main.find_child("TradeReceipt", true, false) as TradeReceiptView
	_check(receipt.visible and receipt._detail.text.contains("来源溢价"), "sale receipt separates premium")
	await create_timer(0.2).timeout
	await _capture("05_premium_receipt")
	await seed_game(42)
	await _click("交易")
	trade._price.value = helper.active(_session).trade.reserve_price
	await _click("正式报价并收购")
	await _click("库存")
	await _click("委托来源调查 · 2银元 / 10分钟")
	var dialog := visible_dialog(_main)
	_check(dialog != null and dialog.dialog_text.contains("2银元") and dialog.dialog_text.contains("10分钟") and dialog.dialog_text.contains("可能查无实据"), "inquiry confirms amount, time and uncertainty")
	await _capture("06_inquiry_confirmation")
	var before := _session.read_state()
	await _click_button(dialog.get_cancel_button())
	_check(_session.read_state() == before, "cancel inquiry is free")
	await _click("委托来源调查 · 2银元 / 10分钟")
	await _click_button(visible_dialog(_main).get_ok_button())
	var feedback := (_main.get_node("CounterScreen") as CounterScreen)._feedback
	_check(not feedback.visible and feedback.record.amount == -2 and _session.read_state().cash == before.cash - 2, "inquiry nonmodal record / exact debit")
	await create_timer(0.2).timeout
	await _capture("07_inquiry_receipt")
	await _click("库存")
	_check(not _session.counter_model().inventory.buttons.any(func(b: Dictionary) -> bool: return b.command == "inquire"), "completed source inquiry no longer offered")
	await _capture("08_inquiry_result")
	await seed_game(late_seed)
	helper.wait_to(_session, 85)
	await _click("交易")
	trade._price.value = helper.active(_session).trade.reserve_price
	await _click("正式报价并收购")
	_check(not feedback.visible and not receipt.visible and helper.active(_session) != null and helper.active(_session).arrival == 90, "nonmodal result allows next active visitor")
	await _settle_feedback()
	await _click_button((_main.get_node("CounterScreen") as CounterScreen)._recent_button)
	_check(receipt.z_index == 20 and receipt._paper.get_global_rect().encloses(receipt._primary.get_global_rect()), "receipt above portrait / controls fit")
	_check(_main.get_node("CounterScreen").get_global_rect().encloses(receipt._paper.get_global_rect()), "receipt fits actual viewport")
	before = _session.read_state()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = Vector2(30, 250)
	root.push_input(click)
	click = click.duplicate(); click.pressed = false; root.push_input(click)
	await _frames()
	_check(receipt.visible and _session.read_state() == before, "receipt isolates background clicks")
	await create_timer(0.2).timeout
	await _capture("09_next_customer_receipt")
	await _click_button(receipt._primary)
	_check(helper.finish(_session), "new UI run settles")
	await _frames()
	await _capture("10_night_expenses")
	print("VARIETY UI TESTS: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	quit(0 if _failures == 0 else 1)

func visible_dialog(node: Node) -> ConfirmationDialog:
	if node is ConfirmationDialog and node.visible: return node
	for child in node.get_children():
		var found := visible_dialog(child)
		if found != null: return found
	return null
