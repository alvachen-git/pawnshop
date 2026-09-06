class_name PawnTests
extends M3Tests

func run(expect: Callable) -> void:
	check = expect
	_multiple_returns()
	_disposals()
	_legacy()
	_legacy_closed_tickets()
	_legacy_archives()
	_last_night()
	_production_return()
	_ghost_transfer()
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func fresh() -> void:
	catalog = JsonContentProvider.new("res://tests/fixtures/m3_manifest.json").load_catalog().catalog
	definition = catalog.get_definition("runs", catalog.default_run_id)

func advance(s: RunSession, minute: int) -> void:
	for index in 108:
		if s.read_state().game_minutes >= minute: return
		if not s.execute("short_task").ok: check.call(false, "等待被意外阻断：" + s.message); return
	check.call(false, "等待未到预期时刻")

func _multiple_returns() -> void:
	fresh()
	var s := session()
	s.execute("open_shop")
	check.call(command(s, "pawn", "", 27).ok, "首位原主放款")
	advance(s, 90)
	check.call(command(s, "pawn", "", 27).ok, "同一当户模板第二件原物独立出票")
	end_night(s)
	s.execute("continue_run")
	var state := s.read_state()
	check.call(state.pawn_returns.size() == 2 and state.pawn_returns[0].status == "scheduled", "开铺前回访已编排但未到店")
	check.call(not s.commerce_command("redeem", state.pawn_tickets[0].ticket_id).ok, "未开铺不能收赎金")
	s.execute("open_shop")
	var before := s.read_state()
	check.call(s._day.state.visits[0].arrival == 20 and s._day.state.visits[0].expires_at == 120, "普通来客整体顺延两笔赎当的二十分钟")
	check.call(s.counter_model().active_id == before.pawn_returns[0].id, "回访按出票顺序上柜")
	check.call(s.counter_model().trade.pawn_return and s.counter_model().visual.item_name == "青花小碗", "柜台呈现原物与回访")
	for action in ["short_task", "wait_until_seal", "close_shop"]:
		check.call(not s.execute(action).ok and before == s.read_state(), "不能跳过回访：" + action)
	check.call(not command(s, "pawn", "", 1).ok and not s.commerce_command("redeem", before.pawn_tickets[1].ticket_id).ok, "不能把回访当新卖家或越过队首赎当")
	check.call(s.commerce_command("redeem", before.pawn_tickets[0].ticket_id).ok, "队首原主实际赎回")
	check.call(s.counter_model().active_id == before.pawn_returns[1].id, "第二位原主接续上柜")
	check.call(s.commerce_command("redeem", before.pawn_tickets[1].ticket_id).ok, "第二笔赎回")
	check.call(s.read_state().inventory_instances.size() == 2 and s.read_state().cash == 112 and s.read_state().game_minutes == 20, "原物不复制，本息按两票入账")
	check.call(s.counter_model().active_id.ends_with("early_bowl"), "老客办妥后首位新客正常上柜")
	end_night(s)
	_roundtrip(s)
	for key in ["customer_id", "item_instance_id", "ticket_id", "status", "minute"]:
		var raw := SaveCodec.new().encode(s._day.state, catalog.content_version)
		raw.pawn_returns[0][key] = 15 if key == "minute" else "forged"
		check.call(SaveCodec.new().decode(raw, definition, catalog.content_version, catalog) == null, "伪造回访拒读：" + key)

func _disposals() -> void:
	fresh()
	var terms := catalog.get_definition("pawn_terms", "short_redeem") as PawnTermsDefinition
	terms._return_mode = "absent"
	terms._loan_ratio = 0.1
	var failing := M1Tests.FailingSave.new("user://tests/pawn_atomic.json")
	paths.append(failing.path)
	failing.fail_writes = false
	var s := session(null, failing)
	s.execute("open_shop")
	check.call(command(s, "pawn", "", 15).ok, "本金十五银元活当")
	advance(s, 90)
	check.call(command(s, "pawn", "", 15).ok, "第二张逾期测试票")
	var id: String = s.read_state().pawn_tickets[0].ticket_id
	check.call(not s.choose_pawn_disposal(id, "transfer").ok and not s.commerce_command("transfer", id).ok, "未到期及营业中不可转当")
	end_night(s)
	s.execute("continue_run")
	s.execute("open_shop")
	s.execute("close_shop")
	s.execute("wait_until_seal")
	var before := s.read_state()
	check.call(not s.execute("resolve_night").ok and before == s.read_state(), "逾期票未选择不能合账")
	s.choose_pawn_disposal(id, "keep")
	check.call(not s.can_execute("resolve_night"), "只选一张不能漏掉其余当票")
	s.choose_pawn_disposal(id, "transfer")
	s.choose_pawn_disposal(before.pawn_tickets[1].ticket_id, "keep")
	check.call(s.read_state() == before and s.pawn_disposal_model()[0].quote == 12, "草稿可修改，八折实收十二，确认前不变账")
	failing.fail_writes = true
	check.call(not s.execute("resolve_night").ok and before == s.read_state(), "混合转当留货及流水写盘失败整体回滚")
	failing.fail_writes = false
	check.call(s.execute("resolve_night").ok, "原子重试成功：" + s.message)
	var after := s.read_state()
	check.call(after.cash == 82 and after.summaries[1].pawn_transfer_receipts == 12 and after.summaries[1].realized_profit == -3, "转当收入及本金损失分别入账")
	check.call(after.inventory_instances[0].ownership_state == "transferred" and after.inventory_instances[1].ownership_state == "owned" and after.summaries[1].inventory_cost == 15, "转出原物与留货成本正确")
	check.call(not s.execute("resolve_night").ok and not s.choose_pawn_disposal(id, "keep").ok and after == s.read_state(), "重复合账或处置不会重复收款")
	_roundtrip(s)
	s.execute("continue_run")
	s.execute("open_shop")
	check.call(not s.commerce_command("sell", after.pawn_tickets[0].item_instance_id, "buyer_recycler").ok and not s.commerce_command("redeem", id).ok, "已转当不可再卖或赎")
	check.call(s.commerce_command("sell", after.pawn_tickets[1].item_instance_id, "buyer_recycler").ok, "留货次夜可出售")
	end_night(s)
	_roundtrip(s)
	check.call(s.execute("continue_run").ok and s.read_state().phase == "run_ended", "最后一夜正常结束")
	terms._transfer_ratio = 0.5
	var ticket := PawnTicket.new(); ticket.principal = 15
	check.call(PawnController.new().transfer_quote(ticket, terms) == 7, "同行折扣可配置且向下取整")
	ticket.principal = 1
	check.call(PawnController.new().transfer_quote(ticket, terms) == 1, "转当最低一银元")

func _legacy() -> void:
	fresh()
	var s := session()
	s.execute("open_shop"); command(s, "pawn", "", 27); end_night(s); s.execute("continue_run")
	var codec := SaveCodec.new()
	var raw := codec.encode(s._day.state, catalog.content_version)
	raw.save_version = 7
	raw.erase("pawn_rules_start_night"); raw.erase("pawn_returns")
	for summary in raw.summaries: summary.erase("pawn_transfer_receipts")
	var old_path := "user://tests/pawn_legacy_v7.json"
	paths.append(old_path)
	var file := FileAccess.open(old_path, FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	var hash_before := FileAccess.get_sha256(old_path)
	var saver := SaveManager.new("user://tests/pawn_import_v9.json")
	paths.append(saver.path)
	saver.import_checkpoint_path = old_path
	var restored := session(null, saver)
	check.call(restored.has_save() and restored.load_checkpoint().ok, "旧v7当票导入为v9待回访")
	check.call(restored.read_state().cash == 73 and restored.read_state().pawn_rules_start_night == 2, "旧账不重算，新规则从未结夜开始")
	restored.execute("open_shop")
	check.call(restored.commerce_command("redeem", raw.pawn_tickets[0].ticket_id).ok, "旧在当原物进入新回访流程")
	end_night(restored)
	check.call(FileAccess.get_sha256(old_path) == hash_before, "导入并保存不覆盖旧文件")
	_roundtrip(restored)

func _ghost_transfer() -> void:
	catalog = JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog().catalog
	definition = catalog.get_definition("runs", catalog.default_run_id)
	definition._event_ids = []
	definition._trade_scenarios.clear()
	definition._mirror_encounters.clear()
	definition._randomize_seed = false
	definition._initial_cash = 24
	var mirror := catalog.get_definition("items", "item_weeping_mirror") as ItemDefinition
	definition._customer_slots.assign([VisitSlotDefinition.new("pawn_mirror", 0, "customer_citizen", mirror.id, mirror.possible_variants[0].id, 1, 1)])
	var terms := catalog.get_definition("pawn_terms", "short_redeem") as PawnTermsDefinition
	terms._return_mode = "absent"; terms._loan_ratio = 0.01
	var s := session()
	s.execute("open_shop")
	check.call(command(s, "pawn", "", 15).ok, "鬼货活当入柜")
	var id: String = s.read_state().inventory_instances[0].instance_id
	s.risk_command("cover", id)
	end_night(s)
	var legacy := SaveCodec.new().encode(s._day.state, catalog.content_version)
	legacy.save_version = 8
	legacy.erase("pawn_rules_start_night"); legacy.erase("pawn_returns")
	for summary in legacy.summaries: summary.erase("pawn_transfer_receipts")
	var migrated := SaveCodec.new().decode(legacy, definition, catalog.content_version, catalog)
	check.call(migrated != null and migrated.phase == &"shop_resolution" and migrated.cash == 1, "旧v8铺内收尾和在当原物兼容恢复")
	for action in ["enter_room", "sleep", "finish_sleep", "continue_run"]: check.call(s.execute(action).ok, "鬼货测试首夜：" + action)
	s.execute("open_shop"); s.risk_command("uncover", id); s.execute("close_shop"); s.execute("wait_until_seal")
	s.choose_pawn_disposal(s.read_state().pawn_tickets[0].ticket_id, "transfer")
	check.call(s.execute("resolve_night").ok, "鬼货转当仍可正确保存：" + s.message)
	check.call(s.read_state().cash == 5 and s.read_state().fee_history[1].paid == 8, "转当回款先于息费，十二回款可付八元息费")
	check.call(s.read_state().risk_pending == id and not s.execute("enter_room").ok, "转出鬼货仍须应对封铺危机")
	check.call(s.load_checkpoint().ok and s.read_state().risk_pending == id, "转当后的封铺危机可恢复")
	check.call(s.risk_command("retreat", id).ok, "转当残影可应对")
	for action in ["enter_room", "sleep", "finish_sleep", "continue_run"]: check.call(s.execute(action).ok, "鬼货转当后：" + action)
	s.execute("open_shop")
	check.call(not s._risk.held_at(s._day.state, s._day.state.inventory_instances[0], 3, 0), "次夜原物已离铺，不再产生持货风险")
	end_night(s)
	_roundtrip(s)

func _production_return() -> void:
	var helper := RoomTests.new()
	helper._expect = check
	helper.catalog = JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog().catalog
	helper.run_def = helper.catalog.get_definition("runs", helper.catalog.default_run_id)
	var s := helper.seeded(7)
	helper.open(s)
	check.call(helper.action(s, "pawn", "", 40).ok, "真实生产情境办理活当")
	helper.seal(s)
	helper.finish_room(s)
	check.call(s.execute("continue_run").ok, "生产回访前保存")
	helper.open(s)
	check.call(s.counter_model().trade.get("pawn_return", false), "生产事件办妥后原主优先上柜")
	check.call(s.commerce_command("redeem", s.read_state().pawn_tickets[0].ticket_id).ok, "生产原主赎回")
	check.call(helper.action(s, "offer", "", 80).ok, "赎回后顺延的怀表情境可成交")
	helper.seal(s)
	helper.finish_room(s)
	var before := s.read_state()
	check.call(s.load_checkpoint().ok and s.read_state() == before, "生产情境、回访、房间和财务联合存档往返")
	for path in helper.paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _legacy_closed_tickets() -> void:
	for returned in [true, false]:
		fresh()
		var terms := catalog.get_definition("pawn_terms", "short_redeem") as PawnTermsDefinition
		if not returned: terms._return_mode = "absent"
		var s := session()
		s.execute("open_shop"); command(s, "pawn", "", 27); end_night(s)
		s.execute("continue_run"); s.execute("open_shop")
		if returned: s.commerce_command("redeem", s.read_state().pawn_tickets[0].ticket_id)
		end_night(s)
		var raw := SaveCodec.new().encode(s._day.state, catalog.content_version)
		raw.save_version = 7
		raw.erase("pawn_returns"); raw.erase("pawn_rules_start_night")
		for summary in raw.summaries: summary.erase("pawn_transfer_receipts")
		# The old implementation also defaulted returning customers who were ignored.
		terms._return_mode = "redeem"
		var restored := SaveCodec.new().decode(raw, definition, catalog.content_version, catalog)
		check.call(restored != null and restored.cash == s.read_state().cash and restored.pawn_tickets[0].status == ("redeemed" if returned else "defaulted"), "旧已赎回或自动绝当合同保留历史结果")
		check.call(restored != null and restored.ledger_entries == s._day.state.ledger_entries, "旧合同历史流水逐项不变")

func _last_night() -> void:
	fresh()
	(catalog.get_definition("pawn_terms", "short_redeem") as PawnTermsDefinition)._return_mode = "absent"
	var s := session()
	s.execute("open_shop"); end_night(s); s.execute("continue_run")
	s.execute("open_shop"); command(s, "pawn", "", 27); end_night(s); s.execute("continue_run")
	s.execute("open_shop"); s.execute("wait_until_seal")
	check.call(not s.execute("resolve_night").ok and not s.execute("continue_run").ok, "最后一夜也必须核妥到期票")
	s.choose_pawn_disposal(s.read_state().pawn_tickets[0].ticket_id, "transfer")
	check.call(s.execute("resolve_night").ok and s.read_state().cash == 94, "最后一夜转当回款二十一，正确结算")
	_roundtrip(s)
	check.call(s.execute("continue_run").ok and s.read_state().phase == "run_ended", "最终夜核票后才合卷")

func _legacy_archives() -> void:
	var path := "user://tests/pawn_old_archive.json"
	paths.append(path)
	var record := {"run_token": "ab".repeat(16), "run_id": "p0_daily_loop", "night": 2, "cash": 0, "principal": 300, "arrears": 9, "overdue": 1, "inventory_cost": 0, "pawn_principal": 0}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"bankruptcy_archive": [record]})); file.close()
	var digest := FileAccess.get_sha256(path)
	var saver := SaveManager.new("user://tests/pawn_no_current_file.json")
	saver.legacy_archive_path = path
	saver.prior_version_path = "user://tests/pawn_no_prior_file.json"
	check.call(saver.read_bankruptcy_archive() == [record] and FileAccess.get_sha256(path) == digest, "仅有旧v7时也合并破铺录，原文件不变")
