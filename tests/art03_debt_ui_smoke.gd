extends "res://tests/m6_ui_smoke.gd"

func _capture(label: String) -> void:
	_capture_prefix = "art03_debt_1600" if "wide" in OS.get_cmdline_user_args() else "art03_debt_1280"
	# Account rows are rebuilt after settlement; measure after container layout.
	await RenderingServer.frame_post_draw
	if label == "03_shortfall_summary":
		var view := _main.find_child("NightResolutionView", true, false) as NightResolutionView
		var found := false
		for child in view._account.get_children():
			if child is Label and child.name == "ArrearsNotice" and child.text.contains("短款 3 银元 · 第2夜夜末须补齐"):
				found = true
				var scroll := view._account.get_parent().get_parent() as ScrollContainer
				_check(scroll.get_global_rect().encloses(child.get_global_rect()), "短款与期限在日结首屏可见")
		_check(found, "日结明确展示实际短款及期限")
	if label in ["02_ledger", "04_due_tonight"]:
		await _click("债务")
		var ledger := _main.find_child("LedgerPanel", true, false) as LedgerPanel
		_check(ledger._pages[1].is_visible_in_tree(), "真实债务页签可见")
		var model: Dictionary = _session.counter_model().ledger.visual
		_check(model.debt.contains("本金 300"), "借据本金来自当前规则")
		if label == "04_due_tonight": _check(model.debt.contains("第2夜夜末须补齐（今夜到期）"), "短款及到期夜次有明确提示")
	await super._capture(label)
