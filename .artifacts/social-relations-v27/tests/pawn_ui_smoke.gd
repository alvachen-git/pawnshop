extends "res://tests/m3_ui_smoke.gd"

func _run() -> void:
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_capture_prefix = "pawn_1600" if "wide" in OS.get_cmdline_user_args() else "pawn_1280"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("Bootstrap").manifest_path = "res://tests/fixtures/m3_manifest.json"
	_main.get_node("Bootstrap").save_path = _save_path
	root.add_child(_main)
	_session = _main.get_node("Bootstrap").session
	await _frames()
	await _click("开铺")
	await _click("交易")
	_find_trade(_main)._pawn_price.value = 27
	await _click("正式报价并活当")
	await _click("营业")
	await _click("整理桌面（占位） · 10 分钟")
	await _click("交易")
	_find_trade(_main)._pawn_price.value = 20
	await _click("正式报价并活当")
	await _finish_night()
	await _click("进入下一夜")
	await _click("开铺")
	_check(_session.counter_model().trade.pawn_return, "开铺直接接待原主")
	_check(not _find_trade(_main)._price.is_visible_in_tree(), "赎当柜台不显示收购报价框")
	await _capture("01_return_counter")
	var before := _session.read_state()
	await _click("账本")
	await _click("当票")
	_check(_session.read_state() == before and _session.counter_model().ledger.buttons.size() == 1, "账本只提供回柜台导航")
	await _click("到柜台接待原当户")
	await _click("验票收赎，交还原物")
	_check(_session.read_state().cash == 86 and _session.read_state().pawn_returns[0].status == "completed", "真实点击收赎并交还原物")
	await _capture("02_redemption_receipt")
	await _click("营业")
	await _click("关门（本夜不可重开）")
	await _click("等到封铺（消耗全部剩余时间）")
	var night := _main.find_child("NightResolutionView", true, false) as NightResolutionView
	_check(night._resolve.disabled, "夜末未选去向不能合账")
	await _capture("03_expired_ticket")
	await _click("撕票留货")
	_check(_session.read_state().cash == 86, "草稿留货不变账")
	await _click("折价转给同行 · 实收 16 银元")
	_check(_session.read_state().cash == 86 and not night._resolve.disabled, "草稿可改转当，确认前不收钱")
	await _capture("04_transfer_selected")
	_check(night._resolve.get_global_rect().end.y < root.size.y, "合账按钮在窗口内")
	await _click("核妥当票，合上账册")
	_check(_session.read_state().cash == 102 and _session.read_state().summaries[1].pawn_transfer_receipts == 16, "统一合账转入十六银元")
	_check(_session.read_state().pawn_tickets[1].status == "transferred", "票据已转当")
	await _capture("05_disposal_receipt")
	await _click("进入下一夜")
	await _click("开铺")
	await _click("库存")
	await _click("出柜记录")
	await _capture("06_transferred_inventory")
	await _receipt_with_waiting_owner()
	print("PAWN UI SMOKE: %d assertions, %d failures" % [_assertions, _failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	_main.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

func _receipt_with_waiting_owner() -> void:
	_session.new_run()
	_session.execute("open_shop")
	_session.counter_command("pawn", _session.counter_model().active_id, "", 27)
	while _session.read_state().game_minutes < 90:
		_session.execute("short_task")
	_session.counter_command("pawn", _session.counter_model().active_id, "", 27)
	await _finish_night()
	await _click("进入下一夜")
	await _click("开铺")
	await _click("验票收赎，交还原物")
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var receipt := screen._receipt
	var counter := _main.get_node("CounterScreen/CounterView") as CounterView
	_check(not screen._feedback.visible and not receipt.visible and _session.counter_model().trade.pawn_return and not counter.feedback_held and counter._active_id == _session.counter_model().active_id, "首票不弹窗，直接接待下一位原主")
	await _settle_feedback()
	_check(not counter.feedback_held and _find_trade(_main).is_visible_in_tree(), "自动反馈结束直接接待下一位原主")
	await _click_button(screen._recent_button)
	await create_timer(0.25).timeout
	await _capture("07_receipt_with_waiting_owner")
	if DisplayServer.get_name() != "headless":
		var paper_rect := Rect2i(root.get_stretch_transform() * receipt._paper.get_global_rect().grow(-3))
		var with_customer := root.get_texture().get_image().get_region(paper_rect)
		counter.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var without_customer := root.get_texture().get_image().get_region(paper_rect)
		_check(with_customer.get_data() == without_customer.get_data(), "凭据纸面像素不受背后人物、对白与货物影响")
		counter.show()
		await _frames()
	var before := _session.read_state()
	await _click_button(counter.get_hotspot(&"customer"))
	_check(receipt.visible and not counter._customer_context.visible and _session.read_state() == before, "凭据阻止点击穿透到下一位当户")
	await _click("收好凭据")
	_check(not receipt.visible and _find_trade(_main).is_visible_in_tree(), "收好凭据后继续接待下一位原主")
	await _capture("08_next_owner")
	await _click("验票收赎，交还原物")
	_check(_session.read_state().cash == 112 and _session.read_state().pawn_returns[1].status == "completed", "下一位原主可正常验票结清")
