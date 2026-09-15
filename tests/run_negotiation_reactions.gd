extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	var helper := BargainingTests.new()
	helper.setup(check)
	var session := helper.session()
	helper.open(session)
	var visit := helper.active(session)
	check(session.counter_model().trade.reactions.is_empty(), "初次接客不把开铺提示当成谈价回应")
	helper.action(session, "belittle")
	var rows: Array = session.counter_model().trade.reactions
	check(rows.size() == 1 and rows[0].before == 72 and rows[0].after == 69, "实际谈价提取公开价格前后值")
	var state_before := session.read_state()
	helper.action(session, "belittle")
	check(session.counter_model().trade.reactions == rows and session.read_state() == state_before, "不可重复动作不添加伪回应")
	rows[0].message = "篡改视图副本"
	check(session.counter_model().trade.reactions[0].message != rows[0].message, "读模型副本不能污染回应")
	helper.action(session, "appraise", "observe")
	check(session.counter_model().trade.reactions.size() == 1, "鉴定反馈不进入谈价记录")
	check(not session.read_state().has("reactions"), "谈价展示不改变存档结构")
	# Restored/replaced state with the same visit IDs must not inherit old replies.
	var original_state := session._day.state
	session._day.state = session._copy_state(original_state)
	check(session.counter_model().trade.reactions.is_empty(), "同来访ID换状态后不串旧回应")
	session.new_run()
	helper.open(session)
	check(session.counter_model().trade.reactions.is_empty(), "新游戏不继承旧局记录")
	var panel := TradePanel.new()
	root.add_child(panel)
	var label := Label.new()
	panel._style_price_change(label, {"before": 50, "after": 55})
	check(label.text == "要价调高 · 50 → 55 银元" and label.get_theme_color("font_color") == TradePanel.PRICE_UP, "涨价分支使用暗红及明确文字")
	panel._style_price_change(label, {"before": 55, "after": 50})
	check(label.text == "要价调低 · 55 → 50 银元" and label.get_theme_color("font_color") == TradePanel.PRICE_DOWN, "降价使用深绿及明确文字")
	panel._style_price_change(label, {"before": 50, "after": 50})
	check(label.text == "要价未变 · 50 银元" and label.get_theme_color("font_color") == TradePanel.PRICE_UNCHANGED, "未变重置为普通墨色")
	label.free()
	panel.queue_free()
	await process_frame
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("NEGOTIATION REACTIONS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
