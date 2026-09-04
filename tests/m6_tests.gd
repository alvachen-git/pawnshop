class_name M6Tests
extends M5Tests

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://tests/fixtures/m6_manifest.json").load_catalog()
	_expect.call(loaded.is_success(), "M6生产内容通过校验")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_basic_fees()
	_arrears()
	_mirror_routes()
	_mirror_evidence()
	_combined_and_rollback()
	_save_corruption()
	_legacy_archive()
	for path in paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func empty_night(s: RunSession) -> void:
	events(s)
	_expect.call(s.execute("open_shop").ok, "息费测试开铺")
	seal(s)

func low_cash(cash: int) -> RunSession:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_debt_mirror.json")).records[0]
	source.initial_cash = cash
	var definition := RunDefinition.from_dto(RunDTO.from_source(source))
	var path := "user://tests/m6_low_%d.json" % Time.get_ticks_usec()
	paths.append(path)
	return RunSession.new(definition, catalog.content_version, SaveManager.new(path), catalog)

func _basic_fees() -> void:
	var s := session()
	for cash in [92, 84, 76]:
		empty_night(s)
		_expect.call(s.read_state().cash == cash and s.definition.fee_policy.principal == 300, "空店每日扣8且本金不变：%d" % cash)
		var summary: Dictionary = s.read_state().summaries.back()
		_expect.call(summary.realized_profit == 0 and summary.operating_profit == -8 and summary.fees_paid == 8, "交易毛利与当夜费用、净收益分列")
		var before := s.read_state()
		_expect.call(not s.execute("resolve_night").ok and before == s.read_state(), "重复结算不重复付款")
		_expect.call(s.load_checkpoint().ok and before == s.read_state(), "息费日结可精确重载：" + s.message)
		_expect.call(s.execute("continue_run").ok, "正常经营无需窥镜可推进")
	_expect.call(s.read_state().phase == "run_ended", "无交易也可完成三夜")

func _arrears() -> void:
	var s := low_cash(5)
	empty_night(s)
	_expect.call(s.read_state().cash == 0 and s.read_state().fee_arrears == [{"origin_night": 1, "due_night": 2, "amount": 3}] and s.read_state().phase == "day_summary", "短款只宽限一夜，现金零不立即失败")
	_expect.call(s.execute("continue_run").ok, "短款可进入次夜")
	empty_night(s)
	_expect.call(s.read_state().phase == "bankrupt" and s.read_state().bankruptcy_archive.size() == 1 and s.read_state().fee_arrears.size() == 2, "旧欠未补齐经营失败，当夜费用也保留")
	var before := s.read_state()
	_expect.call(s.load_checkpoint().ok and s.read_state() == before and not s.can_execute("continue_run"), "破铺终局不能通过读档继续")
	s.new_run()
	_expect.call(s.read_state().bankruptcy_archive.size() == 1 and s.read_state().fee_arrears.is_empty(), "新经营保留破铺录，重新记息费")
	# Unit-level FIFO boundary; cash is deliberately supplied as a service input here.
	for available in [2, 3, 10, 11]:
		var state := RunState.create(run_def)
		state.current_night_index = 2
		state.game_minutes = 540
		state.cash = available
		state.fee_arrears = [{"origin_night": 1, "due_night": 2, "amount": 3}]
		FeeService.settle(state, run_def)
		_expect.call((FeeService.overdue(state) > 0) == (available == 2), "旧欠优先与刚好还清边界：%d" % available)
		_expect.call(FeeService.outstanding(state) == maxi(0, 11 - available), "剩余短款准确：%d" % available)
	var example := RunState.create(run_def)
	example.current_night_index = 2
	example.cash = 10
	example.fee_arrears = [{"origin_night": 1, "due_night": 2, "amount": 5}]
	FeeService.settle(example, run_def)
	_expect.call(example.fee_arrears == [{"origin_night": 2, "due_night": 3, "amount": 3}], "昨日欠5、今晚10，只留下新欠3")
	var third_arrears := low_cash(20)
	for n in 3:
		empty_night(third_arrears)
		_expect.call(third_arrears.execute("continue_run").ok, "第三夜新欠不提前判负")
	_expect.call(third_arrears.read_state().phase == "run_ended" and third_arrears.read_state().fee_arrears[0].due_night == 4, "试玩结束保留第四夜到期欠款")
	var due_third := low_cash(12)
	for n in 3:
		empty_night(due_third)
		if n < 2: due_third.execute("continue_run")
	_expect.call(due_third.read_state().phase == "bankrupt", "第二夜欠款在第三夜仍然到期")
	var rescue := session()
	events(rescue)
	rescue.execute("open_shop")
	_expect.call(rescue.counter_command("offer", rescue.counter_model().active_id, "", 95).ok, "通过真实买卖制造库存占款")
	seal(rescue)
	rescue.execute("continue_run")
	events(rescue)
	rescue.execute("open_shop")
	var item_id: String = rescue.read_state().inventory_instances[0].instance_id
	_expect.call(rescue.commerce_command("sell", item_id, "buyer_recycler").ok, "到期前卖货筹齐现银")
	seal(rescue)
	_expect.call(rescue.read_state().phase == "day_summary" and rescue.read_state().fee_arrears.is_empty() and rescue.read_state().summaries.back().fees_paid == 11 and rescue.read_state().summaries.back().interest_expense == 3, "卖货脱困，旧欠还款不重复计费")
	var stock := session()
	events(stock); stock.execute("open_shop")
	stock.counter_command("offer", stock.counter_model().active_id, "", 95)
	seal(stock); stock.execute("continue_run"); empty_night(stock)
	_expect.call(stock.read_state().phase == "bankrupt" and stock.read_state().inventory_instances[0].ownership_state == "owned", "有库存仍按到期现金判负，不自动变卖")

func midnight(s: RunSession) -> String:
	var id := third(s)
	_expect.call(s.risk_command("cover", id).ok, "等客时覆镜")
	while s.read_state().game_minutes < 360:
		events(s)
		var delta := 360 - int(s.read_state().game_minutes)
		_expect.call(s.execute("wait_hour" if delta >= 60 else "short_task").ok, "等待子时来客")
	events(s)
	_expect.call(not s.risk_model().attention_id.is_empty(), "子时怀表来客出现窥镜邀请")
	return id

func _mirror_routes() -> void:
	var s := session()
	var id := midnight(s)
	var before := s.read_state()
	for i in 3: s.risk_model(); s.counter_model()
	_expect.call(s.read_state() == before, "窥镜邀请阅读不耗时")
	_expect.call(not s.mirror_command("midnight_old_ticket", "peek").ok and s.read_state() == before, "红布未揭不能窥镜")
	_expect.call(s.mirror_command("midnight_old_ticket", "decline").ok, "可放下好奇正常做生意")
	seal(s)
	_expect.call(s.read_state().summaries.back().outcome == "mirror_safe", "拒绝窥镜正常完成")
	var initial := session()
	id = midnight(initial)
	initial.risk_command("uncover", id)
	_expect.call(initial.mirror_command("midnight_old_ticket", "peek").ok and initial.read_state().game_minutes == 370, "揭布5、初窥5按动作计时")
	_expect.call(initial.risk_model().body.contains("正在回头") and initial.mirror_pending(), "追看前已出现异常警告")
	before = initial.read_state()
	_expect.call(not initial.execute("close_shop").ok and not initial.commerce_command("sell", id, "buyer_mirror").ok and initial.read_state() == before, "待选择不可用别的操作跳过")
	initial.mirror_command("midnight_old_ticket", "stop")
	initial.risk_command("cover", id)
	seal(initial)
	_expect.call(initial.read_state().summaries.back().outcome == "mirror_safe" and initial.load_checkpoint().ok, "初窥收回视线后覆镜可平安且可存档")
	var chased := session()
	id = midnight(chased)
	chased.risk_command("uncover", id)
	chased.mirror_command("midnight_old_ticket", "peek")
	chased.mirror_command("midnight_old_ticket", "pursue")
	chased.risk_command("cover", id)
	_expect.call(chased.commerce_command("sell", id, "buyer_mirror").ok, "追看后铜镜仍可合法出售")
	seal(chased)
	_expect.call(chased.read_state().risk_pending == id and chased.risk_model().body.contains("别回头"), "卖镜覆镜均不抹去追看纠缠，危机有二次预警")
	before = chased.read_state()
	_expect.call(chased.load_checkpoint().ok and before == chased.read_state(), "已售铜镜的人身纠缠可精确重载")
	_expect.call(chased.risk_command("retreat", id).ok and chased.read_state().phase == "day_summary", "追看仍有退出危机的机会")
	_expect.call(chased.read_state().risk_history.filter(func(row: Dictionary) -> bool: return row.action == "retreat").size() == 1, "一夜只应对一次危机")
	var timeout := session()
	id = midnight(timeout)
	timeout.risk_command("uncover", id)
	var visit := timeout._counter.customers.active(timeout._day.state)
	timeout._day.spend_action(visit.expires_at - 5 - timeout._day.state.game_minutes)
	timeout._counter.customers.update(timeout._day.state)
	_expect.call(not timeout.mirror_command("midnight_old_ticket", "peek").ok and timeout.read_state().mirror_history.back().action == "peek_expired", "窥看完成时客人离开，不给证据")
	timeout.risk_command("cover", id)
	seal(timeout)
	_expect.call(timeout.load_checkpoint().ok, "超时窥镜记录可还原")
	var absent := session()
	id = third(absent)
	_expect.call(absent.risk_model().attention_id.is_empty(), "子时前不出现能力邀请")
	absent._day.spend_action(360 - absent._day.state.game_minutes)
	absent._counter.customers.update(absent._day.state)
	absent.commerce_command("sell", id, "buyer_mirror")
	_expect.call(absent.risk_model().attention_id.is_empty() and not absent.mirror_command("midnight_old_ticket", "peek").ok, "先卖镜则无窥镜入口")

func _mirror_evidence() -> void:
	var s := session()
	var id := midnight(s)
	s.risk_command("uncover", id)
	_expect.call(s.mirror_command("midnight_old_ticket", "peek").ok, "取得铜镜来源证据")
	s.mirror_command("midnight_old_ticket", "stop")
	var visit := s._counter.customers.active(s._day.state)
	_expect.call(visit.item.revealed_clue_ids == ["flaw"] and visit.item.completed_action_ids.is_empty(), "窥镜未伪造普通鉴定动作")
	var bounds := AppraisalSystem.new().valuation(visit.item, catalog.get_definition("items", "item_pocket_watch"))
	_expect.call(bounds == Vector2i(20, 26), "铜镜损伤证据进入既有估值区间")
	_expect.call(s.counter_command("pressure", visit.visit_id, "flaw").ok, "铜镜证据可用于真实议价")
	var before := s.read_state()
	_expect.call(not s.counter_command("pressure", visit.visit_id, "flaw").ok and before == s.read_state(), "证据不能重复压价")
	_expect.call(s.counter_command("appraise", visit.visit_id, "observe").ok, "窥镜后可继续正常鉴定")
	_expect.call(s.counter_command("offer", visit.visit_id, "", 20).ok, "依据证据议价后收表")
	s.risk_command("cover", id)
	seal(s)
	before = s.read_state()
	_expect.call(s.load_checkpoint().ok and before == s.read_state(), "外部证据先于普通鉴定的顺序可还原")
	var data := SaveCodec.new().encode(s._day.state, catalog.content_version)
	data.mirror_history.clear()
	_expect.call(SaveCodec.new().decode(data, run_def, catalog.content_version, catalog) == null, "删除铜镜来源不能保留库存证据")

func _combined_and_rollback() -> void:
	var s := combined_session()
	var id: String = s.read_state().risk_pending
	_expect.call(not id.is_empty() and FeeService.overdue(s._day.state) == 1, "真实交易造成欠款到期与镜中危机同夜")
	var before_pending := s.read_state()
	_expect.call(s.load_checkpoint().ok and s.read_state() == before_pending, "两种后果并存的待应对存档可还原")
	var failing_response := M4Tests.ToggleSave.new(s._save.path)
	failing_response.catalog = catalog
	failing_response.fail = true
	s._save = failing_response
	_expect.call(not s.risk_command("retreat", id).ok and s.read_state() == before_pending, "生还与破铺写盘失败同时回滚，不重复收费或记档")
	failing_response.fail = false
	_expect.call(s.risk_command("retreat", id).ok and s.read_state().phase == "bankrupt" and s.read_state().bankruptcy_archive.size() == 1, "生还再进入经营失败并原子保存")
	_expect.call(s.load_checkpoint().ok and s.read_state().phase == "bankrupt", "生还后的破铺终局可重载")
	var death := combined_session()
	id = death.read_state().risk_pending
	_expect.call(death.risk_command("defy", id).ok and death.read_state().phase == "dead" and death.read_state().death_archive.size() == 1 and death.read_state().bankruptcy_archive.is_empty(), "死亡优先只记录一个终局")
	_expect.call(death.load_checkpoint().ok, "费用与死亡结果可一起精确重载")
	var rollback := session()
	events(rollback); rollback.execute("open_shop"); rollback.execute("wait_until_seal")
	var failing := M4Tests.ToggleSave.new(rollback._save.path)
	failing.catalog = catalog
	failing.fail = true
	rollback._save = failing
	var before := rollback.read_state()
	_expect.call(not rollback.execute("resolve_night").ok and before == rollback.read_state(), "息费写盘失败全部回滚")
	failing.fail = false
	_expect.call(rollback.execute("resolve_night").ok and rollback.read_state().cash == 92 and rollback.read_state().fee_history.size() == 1, "重试只扣一次息费")

func _save_corruption() -> void:
	var s := session()
	var id := midnight(s)
	s.risk_command("uncover", id); s.mirror_command("midnight_old_ticket", "peek"); s.mirror_command("midnight_old_ticket", "pursue"); s.risk_command("cover", id)
	seal(s)
	var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
	for kind in ["fees", "deadline", "source", "choice", "time", "cloth", "pending", "bankrupt"]:
		var data: Dictionary = payload.duplicate(true)
		match kind:
			"fees": data.fee_history[0].paid = 0
			"deadline": data.fee_arrears.append({"origin_night": 3, "due_night": 5, "amount": 1})
			"source": data.mirror_history[0].mirror_id = "missing"
			"choice": data.mirror_history.append(data.mirror_history.back().duplicate())
			"time": data.mirror_history[0].minute = 100
			"cloth": data.mirror_history[0].minute = 360
			"pending": data.risk_pending = ""
			"bankrupt": data.phase = "bankrupt"
		_expect.call(SaveCodec.new().decode(data, run_def, catalog.content_version, catalog) == null, "篡改拒绝：" + kind)

func _legacy_archive() -> void:
	var legacy_catalog := JsonContentProvider.new("res://tests/fixtures/m5_manifest.json").load_catalog().catalog
	var legacy_run := legacy_catalog.get_definition("runs", "p0_m5") as RunDefinition
	var path := "user://tests/m6_legacy_%d.json" % Time.get_ticks_usec()
	paths.append(path)
	var legacy := RunSession.new(legacy_run, legacy_catalog.content_version, SaveManager.new(path), legacy_catalog)
	var id := third(legacy)
	seal(legacy); legacy.risk_command("defy", id)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data.save_version = 5
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
	var bytes := FileAccess.get_file_as_bytes(path)
	var fresh := session()
	fresh._save.legacy_archive_path = path
	fresh = RunSession.new(run_def, catalog.content_version, fresh._save, catalog)
	_expect.call(fresh.read_state().death_archive.size() == 1 and fresh.read_state().cash == 100 and fresh.read_state().fee_history.is_empty(), "旧V5只导入有效绝当录，新经营不补扣")
	empty_night(fresh)
	_expect.call(FileAccess.get_file_as_bytes(path) == bytes, "旧存档文件逐字节保持不变")

func combined_session() -> RunSession:
	var s := low_cash(140)
	empty_night(s); s.execute("continue_run"); events(s); s.execute("open_shop")
	_expect.call(s.counter_command("offer", s.counter_model().active_id, "", 125).ok, "第二夜收表后余银7")
	seal(s); s.execute("continue_run"); events(s); s.execute("open_shop")
	var watch: String = s.read_state().inventory_instances[0].instance_id
	s.execute("wait_hour"); events(s)
	_expect.call(s.commerce_command("sell", watch, "buyer_introduced").ok, "第三夜卖表取得100银元")
	_expect.call(s.counter_command("offer", s.counter_model().active_id, "", 100).ok, "收镜占尽现银，旧欠尚未偿付")
	var id: String = s.read_state().inventory_instances.back().instance_id
	while s.read_state().game_minutes < 360:
		events(s)
		s.execute("wait_hour" if 360 - int(s.read_state().game_minutes) >= 60 else "short_task")
	events(s)
	_expect.call(s.mirror_command("midnight_old_ticket", "peek").ok and s.mirror_command("midnight_old_ticket", "pursue").ok, "追看后覆镜仍留纠缠")
	s.risk_command("cover", id)
	seal(s)
	return s
