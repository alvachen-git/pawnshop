class_name M3Tests
extends RefCounted

var check: Callable
var catalog: ContentCatalog
var definition: RunDefinition
var paths: Array[String] = []

func run(expect: Callable) -> void:
	check = expect
	catalog = JsonContentProvider.new("res://tests/fixtures/m3_manifest.json").load_catalog().catalog
	definition = catalog.get_definition("runs", catalog.default_run_id)
	_sales()
	_pawn_redemption()
	_default_and_rollback()
	_deadlines()
	_extensions_and_providers()
	_schema()
	_open_ticket_at_end()
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func session(content: ContentCatalog = null, saver: SaveManager = null) -> RunSession:
	if content == null: content = catalog
	if saver == null:
		var path := "user://tests/m3_%d_%d.json" % [Time.get_ticks_usec(), paths.size()]
		paths.append(path)
		saver = SaveManager.new(path)
	return RunSession.new(content.get_definition("runs", content.default_run_id), content.content_version, saver, content)

func command(s: RunSession, action: String, detail := "", amount := 0) -> ActionResult:
	return s.counter_command(action, s.counter_model().active_id, detail, amount)

func end_night(s: RunSession) -> void:
	s.execute("wait_until_seal")
	check.call(s.execute("resolve_night").ok, "M3夜末对账并存档")

func _buy(s: RunSession, price := 18) -> String:
	s.execute("open_shop")
	if price == 18:
		for action in ["observe", "base", "light"]: command(s, "appraise", action)
		command(s, "pressure", "repair")
	command(s, "offer", "", price)
	return s.read_state().inventory_instances.back().instance_id

func _sales() -> void:
	var s := session()
	var id := _buy(s)
	check.call(s.read_state().cash == 82 and s.counter_model().inventory.body.contains("成本占款 18"), "收货占用现金且成本不是利润")
	var before := s.read_state()
	for index in 10: s.counter_model()
	check.call(s.read_state() == before, "买家报价预览不耗时不占额度")
	check.call(not s.commerce_command("sell", id, "buyer_collector").ok and s.read_state() == before, "未到收藏客窗口不可出售")
	check.call(s.commerce_command("sell", id, "buyer_recycler").ok, "当前买家机会可收货")
	check.call(s.read_state().cash == 94 and s.read_state().sale_records[0].realized_profit == -6, "18成本以12出售，真实亏损6")
	before = s.read_state()
	check.call(not s.commerce_command("sell", id, "buyer_recycler").ok and s.read_state() == before, "重复出售/过期按钮不可重复收款")
	end_night(s)
	check.call(s.read_state().summaries[0].realized_profit == -6 and s.read_state().summaries[0].inventory_cost == 0, "日结区分现金变化与已实现亏损")
	_roundtrip(s)
	_mutations(s, ["sale_price", "sale_duplicate", "sale_buyer", "ownership", "profit", "summary", "ledger_duplicate"])
	var high := session()
	id = _buy(high)
	high.execute("long_task")
	check.call(high.commerce_command("sell", id, "buyer_collector").ok and high.read_state().cash == 106, "相同物品卖给偏好买家24，利润6")
	end_night(high)
	_roundtrip(high)
	var blind := session()
	id = _buy(blind, 60)
	blind.commerce_command("sell", id, "buyer_recycler")
	check.call(blind.read_state().cash == 52 and blind.read_state().sale_records[0].realized_profit == -48, "错误估价高价收货最终兑现亏损48")
	# A second item cannot consume the same buyer quota again.
	var quota := session()
	var first := _buy(quota, 60)
	quota.commerce_command("sell", first, "buyer_recycler")
	command(quota, "offer", "", 40)
	var second: String = quota.read_state().inventory_instances.back().instance_id
	before = quota.read_state()
	check.call(not quota.commerce_command("sell", second, "buyer_recycler").ok and quota.read_state() == before, "买家每夜额度不能无限出货")
	check.call(not quota.commerce_command("sell", second, "buyer_collector").ok, "偏好/窗口不匹配买家不可收货")

func _pawn_redemption() -> void:
	var s := session()
	s.execute("open_shop")
	var before := s.read_state()
	check.call(not command(s, "pawn", "", 101).ok and s.read_state() == before, "现金不足不消耗轮次或生成当票")
	command(s, "offer", "", 1)
	command(s, "pawn", "", 1)
	check.call(s.counter_model().trade.body.contains("轮次 1"), "收购和活当共用有限议价轮次")
	check.call(command(s, "pawn", "", 27).ok, "有限轮次内可活当成交")
	var ticket: Dictionary = s.read_state().pawn_tickets[0]
	check.call(s.read_state().cash == 73 and ticket.principal == 27 and ticket.redemption_amount == 33 and ticket.due_night == 2, "当约驱动本金、赎金及到期夜")
	before = s.read_state()
	check.call(not s.commerce_command("sell", ticket.item_instance_id, "buyer_recycler").ok and s.read_state() == before, "在当原物禁售且不耗时")
	check.call(not s.commerce_command("redeem", ticket.ticket_id).ok, "当户未返店不能凭空收赎金")
	end_night(s)
	check.call(s.read_state().summaries[0].pawn_principal == 27 and s.read_state().summaries[0].realized_profit == 0, "未到期本金独立列示且非亏损")
	_roundtrip(s)
	s.execute("continue_run")
	s.execute("open_shop")
	check.call(s.commerce_command("redeem", ticket.ticket_id).ok, "次夜当户到访可办理赎回")
	check.call(s.read_state().cash == 106 and s.read_state().pawn_tickets[0].status == "redeemed" and s.read_state().inventory_instances[0].ownership_state == "redeemed", "赎金/原物/当票同步提交")
	before = s.read_state()
	check.call(not s.commerce_command("redeem", ticket.ticket_id).ok and s.read_state() == before, "赎回不能重复收款")
	end_night(s)
	check.call(s.read_state().summaries[1].realized_profit == 6 and s.read_state().summaries[1].pawn_principal == 0, "赎回利润只计息费6不计归还本金")
	_roundtrip(s)
	_mutations(s, ["principal", "due", "redemption", "ticket_duplicate", "ticket_reference", "fraction", "redeem_time", "loan_missing"])

func _default_and_rollback() -> void:
	var path := "user://tests/m3_failure_%d.json" % Time.get_ticks_usec()
	paths.append(path)
	var saver := M1Tests.FailingSave.new(path)
	saver.fail_writes = false
	var s := session(null, saver)
	s.execute("open_shop")
	command(s, "reject")
	s.execute("medium_task")
	check.call(command(s, "pawn", "", 20).ok, "第二类顾客的候赎当约可办理")
	end_night(s)
	s.execute("continue_run")
	s.execute("open_shop")
	s.execute("wait_until_seal")
	var before := s.read_state()
	saver.fail_writes = true
	check.call(not s.execute("resolve_night").ok and s.read_state() == before, "存档失败深度回滚绝当和物品权属")
	check.call(not s.execute("resolve_night").ok and s.read_state() == before, "重复失败不会提前绝当")
	saver.fail_writes = false
	check.call(s.execute("resolve_night").ok, "写入恢复后可重试结算")
	check.call(s.read_state().pawn_tickets[0].status == "defaulted" and s.read_state().inventory_instances[0].ownership_state == "owned" and s.read_state().cash == 80, "未赎绝当只转现货不凭空改现金")
	_roundtrip(s)
	s.execute("continue_run")
	s.execute("open_shop")
	check.call(s.commerce_command("sell", s.read_state().inventory_instances[0].instance_id, "buyer_recycler").ok, "绝当现货可在下一夜正常出售")
	end_night(s)
	_roundtrip(s)
	check.call(s.execute("continue_run").ok and s.read_state().phase == "run_ended", "含绝当出售记录的三夜完整运行")
	_roundtrip(s)

func _deadlines() -> void:
	var s := session()
	var id := _buy(s, 60)
	while s.read_state().game_minutes < 530: s.execute("short_task")
	var cash: int = s.read_state().cash
	check.call(not s.commerce_command("sell", id, "buyer_recycler").ok and s.read_state().phase == "night_resolution" and s.read_state().cash == cash, "销售动作恰到03:00封铺，不迟到成交")
	end_night(s)
	var pawn := session()
	pawn.execute("open_shop")
	command(pawn, "pawn", "", 27)
	end_night(pawn)
	pawn.execute("continue_run")
	pawn.execute("open_shop")
	while pawn.read_state().game_minutes < 110: pawn.execute("short_task")
	cash = pawn.read_state().cash
	check.call(not pawn.commerce_command("redeem", pawn.read_state().pawn_tickets[0].ticket_id).ok and pawn.read_state().cash == cash and pawn.read_state().game_minutes == 120, "赎回恰到窗口末尾只耗时不交货收款")
	end_night(pawn)
	check.call(pawn.read_state().pawn_tickets[0].status == "defaulted", "错过返店窗口的当票夜末绝当")
	_roundtrip(pawn)

func _extensions_and_providers() -> void:
	var memory := ContentCatalog.new()
	memory.content_version = catalog.content_version
	memory.default_run_id = catalog.default_run_id
	for kind in ContentCatalog.SUPPORTED_KINDS:
		for entry in catalog.get_all(kind): memory.add_definition(kind, entry)
	check.call(InMemoryContentProvider.new(memory).load_catalog().is_success(), "M3定义可通过内存Provider装配")
	var a := session()
	var b := session(memory)
	for s in [a, b]:
		var id := _buy(s)
		s.commerce_command("sell", id, "buyer_recycler")
	check.call(a.read_state() == b.read_state(), "销售/经济核心与内容Provider无关")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pawn_terms/terms_m3.json"))
	source.records[0].return_mode = "extend_once"
	var alternate := ContentCatalog.new()
	alternate.content_version = catalog.content_version
	alternate.default_run_id = catalog.default_run_id
	for kind in ContentCatalog.SUPPORTED_KINDS:
		if kind == "pawn_terms": continue
		for entry in catalog.get_all(kind): alternate.add_definition(kind, entry)
	for row in source.records: alternate.add_definition("pawn_terms", PawnTermsDefinition.from_dto(PawnTermsDTO.from_source(row)))
	check.call(InMemoryContentProvider.new(alternate).load_catalog().is_success(), "只改当约配置启用一次续当请求")
	var s := session(alternate)
	s.execute("open_shop")
	command(s, "pawn", "", 27)
	end_night(s)
	s.execute("continue_run")
	s.execute("open_shop")
	var id: String = s.read_state().pawn_tickets[0].ticket_id
	check.call(not s.commerce_command("redeem", id).ok, "续当请求不能当作赎回强收本金")
	check.call(s.commerce_command("extend", id).ok and s.read_state().cash == 76 and s.read_state().pawn_tickets[0].due_night == 3, "续当收取3息费并延长一夜")
	check.call(not s.commerce_command("extend", id).ok, "不可重复续当刷现金")
	end_night(s)
	_roundtrip(s, alternate)
	s.execute("continue_run")
	s.execute("open_shop")
	check.call(s.commerce_command("redeem", id).ok and s.read_state().cash == 109, "续当后到期赎回包含原本金和息费")
	end_night(s)
	_roundtrip(s, alternate)

func _roundtrip(s: RunSession, content: ContentCatalog = null) -> void:
	if content == null: content = catalog
	var codec := SaveCodec.new()
	var raw: Variant = JSON.parse_string(JSON.stringify(codec.encode(s._day.state, content.content_version)))
	var restored := codec.decode(raw, s.definition, content.content_version, content)
	check.call(restored != null and restored.to_read_model() == s.read_state(), "M3 JSON存档精确往返：" + codec.error_message)

func _mutations(s: RunSession, changes: Array) -> void:
	for change in changes:
		var raw := SaveCodec.new().encode(s._day.state, catalog.content_version)
		match change:
			"sale_price": raw.sale_records[0].price += 1
			"sale_duplicate": raw.sale_records.append(raw.sale_records[0])
			"sale_buyer": raw.sale_records[0].buyer_id = "missing"
			"ownership": raw.inventory_instances[0].ownership_state = "owned"
			"profit": raw.ledger_entries.back().realized_profit += 1
			"summary": raw.summaries[0].inventory_cost += 1
			"ledger_duplicate": raw.ledger_entries.append(raw.ledger_entries.back())
			"principal": raw.pawn_tickets[0].principal += 1
			"due": raw.pawn_tickets[0].due_night += 1
			"redemption": raw.pawn_tickets[0].redemption_amount += 1
			"ticket_duplicate": raw.pawn_tickets.append(raw.pawn_tickets[0])
			"ticket_reference": raw.pawn_tickets[0].terms_id = "missing"
			"fraction": raw.pawn_tickets[0].principal = 27.5
			"redeem_time": raw.pawn_tickets[0].closed_minute = 120
			"loan_missing": raw.ledger_entries.pop_front()
		check.call(SaveCodec.new().decode(raw, definition, catalog.content_version, catalog) == null, "M3拒绝损坏/伪造存档：" + change)

func _schema() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buyers/buyers_m3.json"))
	for change in ["missing", "fraction", "range"]:
		var bad := source.duplicate(true)
		match change:
			"missing": bad.records[0].erase("capacity_per_night")
			"fraction": bad.records[0].action_minutes = 2.5
			"range": bad.records[0].value_multiplier = -1
		check.call(not SourceSchemaValidator.new().validate_collection("buyers", bad, "memory://buyer").is_empty(), "买家Schema拒绝：" + change)
	var terms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pawn_terms/terms_m3.json"))
	terms.records[0].return_mode = "unlimited_cash"
	check.call(not SourceSchemaValidator.new().validate_collection("pawn_terms", terms, "memory://pawn").is_empty(), "当约Schema拒绝非法返当枚举")
	var dto := RunDTO.from_source(JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_daily_loop.json")).records[0])
	dto.buyer_ids = ["missing_buyer"]
	var invalid := ContentCatalog.new()
	invalid.default_run_id = dto.id
	for kind in ContentCatalog.SUPPORTED_KINDS:
		if kind != "runs":
			for entry in catalog.get_all(kind): invalid.add_definition(kind, entry)
	invalid.add_definition("runs", RunDefinition.from_dto(dto))
	check.call(not InMemoryContentProvider.new(invalid).load_catalog().is_success(), "内存Provider拒绝失效买家引用")

func _open_ticket_at_end() -> void:
	var s := session()
	for index in 2:
		s.execute("open_shop")
		end_night(s)
		s.execute("continue_run")
	s.execute("open_shop")
	command(s, "pawn", "", 27)
	end_night(s)
	s.execute("continue_run")
	check.call(s.read_state().pawn_tickets[0].status == "active" and s.read_state().pawn_tickets[0].due_night == 4 and s.read_state().summaries[2].pawn_principal == 27, "试玩结束不提前强制未到期当票绝当")
	_roundtrip(s)
