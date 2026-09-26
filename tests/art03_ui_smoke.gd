extends "res://tests/m3_ui_smoke.gd"

func _run() -> void:
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	if "ledger-context" in OS.get_cmdline_user_args():
		await _ledger_context_run()
	else: await super._run()

func _capture(label: String) -> void:
	_capture_prefix = "art03_1600" if "wide" in OS.get_cmdline_user_args() else "art03_1280"
	var ledger := _main.find_child("LedgerPanel", true, false) as LedgerPanel
	var stock := _main.find_child("InventoryPanel", true, false) as InventoryPanel
	var before := _session.read_state()
	if label == "01_buyers":
		_check(_session.counter_model().inventory.visual.financial.inventory_cost == 18, "货签成本与真实收购相符")
		await _click("出柜记录")
		_check(_all_text(stock).contains("尚无出柜记录"), "出柜记录空态明确")
		await super._capture("00_empty_history")
		await _click("铺中货物")
		await super._capture("01_stock")
		await _click("查看货物 · 青花小碗")
		_check(_all_text(stock).contains("品相要点"), "库存可以复查影响价值的已知品相")
	if label == "03_tickets":
		await super._capture("03_cash_entries")
		await _click("当票")
		_check(ledger._pages[2].is_visible_in_tree(), "当票页签实际切换")
		_check(_all_text(ledger._pages[2]).contains("第2夜到期"), "当票期限明确")
		_check(_session.counter_model().ledger.visual.tickets.size() == 2, "不同当约均有独立票据")
	if label == "04_summary":
		var view := _main.find_child("NightResolutionView", true, false) as NightResolutionView
		_check(view._account.visible and not view._body.visible, "日结使用结构化账页，避免重复正文")
		_check(view._continue.get_global_rect().end.y < 586, "下一夜按钮固定在抽屉内")
		_check(_all_text(view._account).contains("-53") and _all_text(view._account).contains("-6"), "现金变化与交易毛利分别显示")
	if label == "05_redeemed":
		await _click("账本")
		await _click("当票")
		_check(_all_text(ledger._pages[2]).contains("已赎回"), "赎回后票据章同步更新")
		await _click("流水")
		_check(_all_text(ledger._pages[0]).contains("+33"), "赎金进入真实流水")
		await _click("本夜流水")
		_check(_all_text(ledger._pages[0]).contains("-27"), "全部流水可查前夜放款")
		await _click("全部流水")
		await _click("当票")
	if label == "06_defaulted_stock":
		await _click("出柜记录")
		_check(_all_text(stock).contains("已赎回") and _all_text(stock).contains("已售"), "出柜记录可区分出柜记录")
		await super._capture("06_history")
		await _click("铺中货物")
		await _click("账本")
		await _click("当票")
		_check(_all_text(ledger._pages[2]).contains("已绝当转现货"), "到期未赎票据标记绝当")
		await super._capture("06_defaulted_ticket")
		await _click("库存")
	_check(_session.read_state() == before, "查货、翻账与切页不改变经营数据")
	await super._capture(label)

func _all_text(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += _all_text(child)
	return result

func _check_ledger_context(ledger: LedgerPanel, label: String) -> void:
	var previous := _session.message
	var snapshot := _session.read_state()
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mirror_investigation/events.json"))
	var mirror_note := ""
	for event in events.records:
		for option in event.get("choices", []):
			if str(option.get("result", "")).contains("借镜照客"): mirror_note = option.result
	_check(not mirror_note.is_empty(), "real mirror event fixture")
	_session.message = mirror_note
	_session.changed.emit()
	await _frames()
	_check(_session.message == mirror_note, "ledger leaves story feedback available to its own view")
	for page in [2, 0, 1, 2]:
		ledger.select_page(page)
		_check(ledger._body.text.is_empty() and not ledger._body.visible, label + " ledger excludes unrelated story on page " + str(page))
	_check(_all_text(ledger._pages[2]).contains("本金"), label + " ticket-specific information retained")
	_check(snapshot == _session.read_state(), "viewing ledger preserves save state")
	await super._capture("ledger_" + label)
	var presenter: LedgerPresenter
	for child in _main.get_node("CounterScreen").get_children():
		if child is LedgerPresenter: presenter = child
	_check(presenter != null, "ledger presenter available")
	if presenter != null:
		presenter._on_intent("sell", "missing-item", "missing-buyer", 0)
		_check(not ledger._body.text.is_empty() and ledger._body.visible, "ledger action failure still visible")
		ledger.select_page(1)
		_check(not ledger._body.visible, "ticket action failure stays on its source page")
		ledger.select_page(2)
	_session.message = previous
	_session.changed.emit()
	await _frames()
	_check(ledger._body.text.is_empty(), "unrelated next action clears ledger feedback")

func _ledger_context_run() -> void:
	_capture_prefix = "ledger_clean_1600" if "wide" in OS.get_cmdline_user_args() else "ledger_clean_1280"
	_main = load("res://scenes/start_special_guests_wet_v45.tscn").instantiate()
	_main.start_at_title = false
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main); current_scene = _main
	_session = _main.get_node("Bootstrap").session
	await _frames()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.content_scale_size = root.size
	PrecisionPreview.apply(_session,3,"camera","sound","intact",false)
	_session.restored.emit(); _session.changed.emit()
	await _frames()
	var screen := _main.get_node("CounterScreen") as CounterScreen
	screen._route_from_counter(&"ledger",&"ledger")
	await _frames()
	var ledger := _main.find_child("LedgerPanel",true,false) as LedgerPanel
	ledger.select_page(2)
	_check(_session.counter_model().ledger.visual.tickets.is_empty(),"empty pawn ticket fixture")
	await _check_ledger_context(ledger,"empty")
	var v := _session._counter.customers.active(_session._day.state)
	var result := _session.counter_command("pawn",v.visit_id,"",v.trade.asking_price)
	_check(result.ok,"actual pawn transaction succeeds: " + result.message)
	await _frames()
	for name in ["TradeReceipt", "CustomerDeparture"]:
		var receipt := _main.find_child(name,true,false)
		if receipt != null: receipt.hide()
	screen._route_from_counter(&"ledger",&"ledger")
	await _frames()
	ledger.select_page(2)
	_check(_session.counter_model().ledger.visual.tickets.size() == 1,"actual pawn produces one ticket")
	await _check_ledger_context(ledger,"populated")
	var text := _all_text(ledger._pages[2])
	_check(text.contains("本金") and text.contains("赎金") and text.contains("到期"),"pawn terms remain visible")
	_check(root.get_texture().get_image().get_size() == root.size,"actual screenshot dimensions")
	print("LEDGER CONTEXT UI: %d assertions, %d failures" % [_assertions,_failures])
	_main.queue_free(); await _frames()
	quit(0 if _failures == 0 else 1)
