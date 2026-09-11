extends "res://tests/receipt_ui_smoke.gd"

func _run() -> void:
	_capture_prefix = "feedback_state_1600" if "wide" in OS.get_cmdline_user_args() else "feedback_state_1280"
	root.size = Vector2i(1600, 900) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	await _boot("res://data/legacy/content_v9.json")
	var helper := RoomTests.new()
	helper._expect = _check; helper.catalog = _session._counter.catalog; helper.run_def = _session.definition
	helper.events(_session)
	_check(_session._save.save_state(_session._day.state, _session.definition, _session.content_version), "保存独立开铺前检查点")
	helper.open(_session)
	var screen := _main.get_node("CounterScreen") as CounterScreen
	var trade := _find_trade(_main)
	var v := helper.active(_session)
	await _click("交易")
	_check(trade._amount_caption.text == "出价（银元）" and not trade._body.text.contains("剩余议价"), "按确认方案隐藏剩余轮次，不影响报价入口")
	var modes := v.transaction_modes.duplicate()
	v.transaction_modes.assign(["sell"])
	_session.changed.emit()
	_check(trade._pawn_mode.disabled and not trade._purchase_mode.disabled and trade._terms.text.contains("不接受活当") and not trade._terms.text.contains("期限"), "只卖客说明拒当，不展示虚假当约")
	await _capture("01_sell_only")
	v.transaction_modes.assign(["pawn"])
	_session.changed.emit()
	_check(trade._purchase_mode.disabled and trade._pawn_mode.button_pressed and trade._terms.text.contains("不接受收购"), "只当客明确意愿并选择可行方式")
	var before := _session.read_state()
	trade._pawn_price.value = 101
	_check(trade._pawn_submit.disabled and trade._availability.text.contains("现银不足"), "输入超出现金时解释暂不可用")
	_check(_session.read_state() == before, "编辑报价不耗钱和时间")
	await _capture("02_pawn_cash")
	trade._pawn_price.value = 30
	_check(not trade._pawn_submit.disabled and trade._availability.text.is_empty(), "降低报价后恢复可用")
	v.trade.rounds_left = 0
	_session.changed.emit()
	_check(trade._pawn_submit.disabled and trade._availability.text.contains("议价已经结束") and not trade._pawn_mode.disabled, "轮次与交易资格分别说明")
	v.trade.rounds_left = 3; v.transaction_modes.assign(modes)
	_session.changed.emit()
	_session.counter_command("appraise", v.visit_id, "light")
	_check((_main.find_child("AppraisalPanel", true, false) as AppraisalPanel)._body.text.contains("本次发现"), "新增物证醒目标识")
	_session.counter_command("offer", v.visit_id, "", 72)
	_check(screen._feedback.visible, "成交启动演出")
	before = _session.read_state()
	screen._flow.show_panel(&"inventory")
	await create_timer(0.85).timeout
	_check(not screen._feedback.visible and not screen._counter_view.feedback_held and screen._flow.get_active_panel_id() == &"inventory" and screen.get_node("%Drawer").visible and before == _session.read_state(), "切页面取消演出，过期回调不改导航或账目")
	_check(_session.load_checkpoint().ok, "真实读取检查点")
	_check(screen._recent.is_empty() and not screen._feedback.visible, "读档清空旧结果")
	helper.open(_session); v = helper.active(_session)
	_session.counter_command("offer", v.visit_id, "", v.trade.asking_price)
	_check(screen._feedback.visible and _session.load_checkpoint().ok, "演出中读取检查点")
	await create_timer(0.85).timeout
	_check(not screen._feedback.visible and screen._recent.is_empty() and _session.read_state().cash == 100, "读档取消演出与扣款，不触发迟到回调")
	helper.open(_session); v = helper.active(_session)
	v.expires_at = _session._day.state.game_minutes + 5
	_session.changed.emit()
	var id := v.visit_id
	_check(not _session.counter_command("offer", id, "", v.trade.asking_price).ok, "报价完成前超时，实际未成交")
	await _frames()
	_check(screen._feedback.visible and screen._feedback.record.kind == "departure" and screen._counter_view._active_id == id and screen._counter_view.feedback_held and _session.read_state().cash == 100, "失败操作的真实离场仍归属原客，不扣款")
	await _settle_feedback()
	_check(not screen._feedback._step.text.contains("收讫"), "未成交不盖收货章")
	_session.new_run(); helper.open(_session); v = helper.active(_session)
	_session.counter_command("offer", v.visit_id, "", v.trade.asking_price)
	_session._save.library = SaveLibrary.new("user://tests/feedback_title_library.json")
	_main.storage = SaveLibraryView.new(); _main.add_child(_main.storage); _main.storage.bind(_session)
	_main._leave("title")
	await create_timer(0.85).timeout
	_check(_main.title_menu.visible and not screen.visible and not screen._feedback.visible and screen._recent.is_empty(), "返回标题取消演出和后台回调")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_session._save.path))
	print("FEEDBACK LIFECYCLE UI: %d assertions, %d failures" % [_assertions, _failures])
	_main.queue_free(); await process_frame
	quit(0 if _failures == 0 else 1)
