class_name BargainingTests
extends RoomTests

func setup(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog()
	_expect.call(loaded.is_success(), "议价生产内容有效")
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)

func run(expect: Callable) -> void:
	setup(expect)
	_profiles()
	_limits()
	_evidence()
	_checkpoint(false)
	_checkpoint(true)
	_pawn_return()
	_legacy_and_schema()
	for path in paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _profiles() -> void:
	for customer_id in ["customer_citizen", "customer_house_agent", "customer_hawker", "customer_scholar"]:
		for situation in ["ordinary", "urgent"]:
			var customer := catalog.get_definition("customers", customer_id) as CustomerDefinition
			var visit := CustomerVisit.new()
			visit.situation_id = situation
			visit.trade.asking_price = 72
			visit.trade.reserve_price = 54
			visit.trade.rounds_left = 3
			visit.trade.patience = 3
			var response := BelittleService.apply(visit, customer)
			var discount := (5 if situation == "urgent" else 3) if customer.belittle.reaction == "yielding" else 0
			_expect.call(visit.trade.asking_price == 72 - discount and visit.trade.reserve_price == 54 - discount, "固定人物与处境 " + customer_id + situation)
			_expect.call(visit.trade.patience == (1 if customer.belittle.reaction == "proud" else 3), "坚定不额外掉耐心，重面子扣2")
			_expect.call(visit.trade.rounds_left == 2 and visit.trade.belittle_used and response.contains("72 →"), "反馈实际要价，消耗一轮一次")
	# A real urgent watch visit uses the existing seeded situation.
	var s := seeded(seed_for("n2_visit1", "sound", "urgent"))
	empty_night(s)
	s.execute("continue_run")
	open(s)
	var before := active(s).trade.asking_price
	var postings: int = s.read_state().ledger_entries.size()
	action(s, "belittle")
	_expect.call(active(s).trade.asking_price == before - 5, "真实急迫管事让5银元")
	_expect.call(s.read_state().ledger_entries.size() == postings, "试探不产生资金流水")

func _limits() -> void:
	var s := session()
	open(s)
	var v := active(s)
	var prices := Vector2i(v.trade.asking_price, v.trade.reserve_price)
	var bounds := s._counter.appraisal.valuation(v.item, catalog.get_definition("items", v.item.definition_id))
	var posted: Array = []
	s.transaction_completed.connect(func(receipt: Dictionary) -> void: posted.append(receipt))
	_expect.call(action(s, "belittle").ok, "无证据也能试探")
	_expect.call(v.trade.asking_price == prices.x - 3 and v.trade.reserve_price == prices.y - 3, "普通住户让3银元")
	_expect.call(s.read_state().game_minutes == 5 and s.read_state().cash == 100 and posted.is_empty(), "仅耗5分钟，无现金变化和成功页")
	_expect.call(s._counter.appraisal.valuation(v.item, catalog.get_definition("items", v.item.definition_id)) == bounds, "故意贬低不改估值")
	var state := s.read_state()
	_expect.call(not action(s, "belittle").ok and s.read_state() == state, "重复点击不推进时间或叠加收益")
	_expect.call(not s._counter.execute(s._day, "belittle", v.visit_id, "fake", 1).ok, "拒绝伪造试探参数")
	var terms := catalog.get_definition("pawn_terms", (catalog.get_definition("customers", v.customer_id) as CustomerDefinition).pawn_terms_id) as PawnTermsDefinition
	var loan := maxi(1, roundi(v.trade.reserve_price * terms.loan_ratio))
	_expect.call(action(s, "pawn", "", loan).ok and s.read_state().pawn_tickets.size() == 1, "活当门槛使用同一试探后的底价")
	for boundary in ["floor", "last_round", "angry", "deadline", "seal"]:
		s = session()
		open(s)
		v = active(s)
		match boundary:
			"floor":
				v.trade.asking_price = 2
				v.trade.reserve_price = 1
			"last_round": v.trade.rounds_left = 1
			"angry":
				v.customer_id = "customer_scholar"
				v.trade.patience = 2
			"deadline": s._day.state.game_minutes = v.expires_at - 5
			"seal":
				v.expires_at = run_def.night_minutes + 5
				s._day.state.game_minutes = run_def.night_minutes - 5
		var asking := v.trade.asking_price
		action(s, "belittle")
		match boundary:
			"floor": _expect.call(v.trade.asking_price == 1 and v.trade.reserve_price == 1, "最低要价和底价均为1")
			"last_round": _expect.call(v.status == "rounds_exhausted", "最后一轮按原规则结束接待")
			"angry": _expect.call(v.status == "patience_exhausted", "重面子客人耐心耗尽离场")
			_: _expect.call(v.trade.asking_price == asking and not v.trade.belittle_used and v.status != "active", "完成时离场不再生效 " + boundary)

func _evidence() -> void:
	var s := seeded(seed_for("n1_visit1", "sound"))
	open(s)
	for check_id in ["observe", "base", "light"]: action(s, "appraise", check_id)
	var model := s.counter_model()
	var rows := 0
	for row in model.trade.buttons:
		if row.command != "pressure": continue
		rows += 1
		_expect.call(not row.label.contains("据此压价") and not row.label.contains("…") and row.evidence.length() > 16, "说辞与完整证据独立显示")
	_expect.call(rows == 3, "完好碗三条无效理由仍可判断，不隐藏答案")
	var price := active(s).trade.asking_price
	action(s, "pressure", "mark")
	_expect.call(active(s).trade.asking_price == price and active(s).trade.patience == 1 and s.message.contains("磨痕"), "无效施压保持原代价并解释反驳")
	var found := false
	for row in s.counter_model().trade.buttons:
		if row.command == "pressure" and row.detail == "mark": found = not row.enabled and row.label.contains("已谈过")
	_expect.call(found, "已用证据明确标注")
	s = seeded(seed_for("n1_visit1", "repaired"))
	open(s)
	action(s, "appraise", "light")
	action(s, "pressure", "repair")
	_expect.call(active(s).trade.asking_price == 32, "真实修补仍折40银元")
	action(s, "belittle")
	_expect.call(active(s).trade.asking_price == 29, "独立试探与证据各生效一次")

func _checkpoint(ordinary: bool) -> void:
	var s := session()
	open(s)
	if ordinary: wait_to(s, 210)
	_expect.call(active(s).scenario_id.is_empty() == ordinary, "覆盖有无情境的来访")
	action(s, "appraise", "observe")
	action(s, "belittle")
	var price := active(s).trade.reserve_price
	_expect.call(action(s, "offer", "", price).ok, "试探后真实成交")
	s.execute("wait_until_seal")
	events(s)
	var before := s.read_state()
	var failing := M4Tests.ToggleSave.new(s._save.path)
	failing.catalog = catalog
	s._save = failing
	failing.fail = true
	_expect.call(not s.execute("resolve_night").ok and before == s.read_state(), "写盘失败保留议价历史且完整回滚")
	failing.fail = false
	var retry := s.execute("resolve_night")
	_expect.call(retry.ok, "写盘重试成功：" + retry.message)
	resume(s, "试探与成交历史重放")
	finish_room(s)
	resume(s, "就寝后试探历史仍一致")
	var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
	var key := "bargaining_history" if ordinary else "scenario_history"
	var index := -1
	for i in payload[key].size():
		if payload[key][i].command == "belittle": index = i
	_expect.call(index >= 0, "试探有对应历史")
	for tamper in ["result", "repeat", "time", "remove"]:
		var bad: Dictionary = payload.duplicate(true)
		match tamper:
			"result": bad[key][index].belittle_result.asking += 1
			"repeat": bad[key].insert(index + 1, bad[key][index].duplicate(true))
			"time": bad[key][index].minute += 5
			"remove": bad[key].remove_at(index)
		_expect.call(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog) == null, "拒绝伪造议价 " + key + tamper)

func _pawn_return() -> void:
	for ordinary in [false, true]:
		var s := seeded(7)
		open(s)
		_expect.call(action(s, "belittle").ok and action(s, "pawn", "", 40).ok, "试探后活当并安排原主回访")
		seal(s)
		finish_room(s)
		_expect.call(s.execute("continue_run").ok, "进入回访夜")
		open(s)
		var before := s.read_state()
		_expect.call(s.counter_model().trade.get("pawn_return", false), "原主回访优先上柜")
		for button in s.counter_model().trade.buttons:
			_expect.call(button.command != "belittle", "回访不显示贬低选项")
		_expect.call(not action(s, "belittle").ok and s.read_state() == before, "回访拒绝贬低且不耗时改价")
		_expect.call(s.commerce_command("redeem", before.pawn_tickets[0].ticket_id).ok, "原主正常赎回")
		if ordinary:
			for visit in s._day.state.visits:
				if visit.scenario_id.is_empty():
					wait_to(s, visit.arrival)
					break
		_expect.call(active(s).scenario_id.is_empty() == ordinary, "回访后覆盖两类顺延来客")
		_expect.call(action(s, "belittle").ok, "新接待独立取得一次试探")
		var after := s.read_state()
		_expect.call(not action(s, "belittle").ok and s.read_state() == after, "新来客重复试探仍拒绝")
		seal(s)
		finish_room(s)
		resume(s, "回访顺延与议价历史联合恢复")

func _legacy_and_schema() -> void:
	var s := session()
	empty_night(s)
	var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
	payload.erase("bargaining_history")
	_expect.call(SaveCodec.new().decode(payload, run_def, catalog.content_version, catalog) != null, "旧档缺少试探记录仍可读")
	var customer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/customers/customers_m5.json")).records[0]
	for field in ["reaction", "minutes", "ordinary_discount", "cue"]:
		var bad := customer.duplicate(true)
		bad.belittle[field] = "unknown" if field == "reaction" else "" if field == "cue" else -1
		_expect.call(not CounterSchema.validate("customers", bad, "test", "test").is_empty(), "拒绝错误人物配置 " + field)
	var clone := (catalog.get_definition("customers", "customer_citizen") as CustomerDefinition).belittle
	clone.ordinary_discount = 100
	_expect.call((catalog.get_definition("customers", "customer_citizen") as CustomerDefinition).belittle.ordinary_discount == 3, "读取配置不会修改权威人物")
