extends "res://tests/m3_ui_smoke.gd"

func _run() -> void:
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	await super._run()

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
