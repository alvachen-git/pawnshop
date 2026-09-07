extends SceneTree

var failures := 0
var checks := 0
var catalog: ContentCatalog
var definition: RunDefinition
var serial := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> RunSession:
	serial += 1
	return RunSession.new(definition, 12, SaveManager.new("user://tests/opening_%d_%d.json" % [Time.get_ticks_usec(), serial]), catalog)

func choose(s: RunSession, id := "") -> void:
	var model := s.event_model()
	if model.buttons.is_empty():
		check(false, "事件缺少选项 " + model.pending_id)
		return
	var target: String = model.buttons[0].detail if id.is_empty() else id
	var result := s.event_command(model.pending_id, target)
	check(result.ok, "选择 " + target + "：" + result.message)

func drain(s: RunSession) -> void:
	for step in 60:
		if s.read_state().pending_event_id.is_empty(): return
		choose(s)
	check(false, "事件链不能结束")

func resume(s: RunSession) -> void:
	var state := s.read_state()
	var result := s.load_checkpoint()
	check(result.ok and s.read_state() == state, "事件状态跨存档恢复：" + result.message)

func _run() -> void:
	check(not CounterSchema.validate("runs", {"customer_slots": null}, "test", "$").is_empty(), "损坏的来访数组返回校验问题")
	check(not EventSchema.validate({"choices": null}, "test", "$").is_empty(), "损坏的事件选项返回校验问题")
	var loaded := JsonContentProvider.new("res://data/opening_manifest.json").load_catalog()
	check(loaded.is_success(), "开场内容完整校验")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		quit(1)
		return
	catalog = loaded.catalog
	definition = catalog.get_definition("runs", catalog.default_run_id)
	var s := fresh()
	check(s.read_state().pending_event_id == "evt_intro_factory_paycut", "从纱厂开始")
	check(not s.execute("open_shop").ok, "不能跳过未处理的开场")
	for step in 12:
		choose(s)
		resume(s)
	check(s.read_state().pending_event_id == "evt_intro_shop_inspection", "抵达四热点")
	var before := s.read_state()
	check(not s.event_command(before.pending_event_id, "ready").ok and before == s.read_state(), "未看明账旧册不能开铺")
	choose(s, "ledger")
	resume(s)
	before = s.read_state()
	check(not s.event_command(before.pending_event_id, "ledger").ok and before == s.read_state(), "重复热点不刷标记")
	choose(s, "accounts")
	check("300" in s.event_model().feedback, "明账从实际债务取值")
	choose(s, "ready")
	resume(s)
	check(s.read_state().cash == definition.initial_cash and s.read_state().game_minutes == 0, "序章不扣经营现金与时间")
	check(s.execute("open_shop").ok, "18点开铺")
	drain(s)
	var visit: CustomerVisit = s._counter.customers.active(s._day.state)
	check(visit.item.definition_id == "intro_silver_hairpin", "教程银簪进入正式柜台")
	var receipts: Array = []
	s.transaction_completed.connect(func(receipt: Dictionary) -> void: receipts.append(receipt))
	var cash: int = s.read_state().cash
	check(s.counter_command("appraise", visit.visit_id, "observe").ok, "观察")
	check(s.counter_command("question", visit.visit_id, "origin").ok, "询问来源")
	check(s.counter_command("appraise", visit.visit_id, "inspect").ok, "快速鉴看")
	check("condition_mended" in visit.item.revealed_clue_ids, "实际揭露旧修证据")
	check(s.counter_command("offer", visit.visit_id, "", 1).ok and visit.status == "active", "首次极低价仍能修正")
	check(receipts.is_empty() and s.read_state().cash == cash and "INTRO_FIRST_TRADE_DONE" not in s.read_state().narrative_flags, "拒绝报价不产生假交易")
	var price: int = visit.trade.reserve_price
	check(s.counter_command("offer", visit.visit_id, "", price).ok, "合理价成交")
	check(s.read_state().cash == cash-price and s.read_state().inventory_instances.size() == 1 and receipts.size() == 1, "真实扣款入库只发一张凭据")
	drain(s)
	check("INTRO_FIRST_TRADE_DONE" in s.read_state().narrative_flags, "真实成交后确认首单")
	var item: String = s.read_state().inventory_instances[0].instance_id
	check(s.commerce_command("sell", item, "buyer_silversmith").ok, "正式卖货接口")
	check(s.read_state().cash > cash, "银楼售出产生小额实际利润")
	check(s.execute("close_shop").ok, "正常关门")
	check(s.execute("wait_until_seal").ok, "等到03点")
	check(s.execute("resolve_night").ok, "正常结账封铺：" + s.message)
	resume(s)
	check(s.read_state().risk_pending.is_empty(), "首夜无强鬼事件")
	check(s.execute("enter_room").ok, "进入寝屋：" + s.message)
	resume(s)
	choose(s, "photo")
	resume(s)
	choose(s, "lamp")
	check(s.event_model().feedback == "火稳，色暖。", "命灯正文")
	choose(s, "letter")
	choose(s, "settled")
	resume(s)
	check(s.execute("sleep").ok, "床进入睡眠")
	resume(s)
	drain(s)
	resume(s)
	check("INTRO_COMPLETE" in s.read_state().narrative_flags, "开场完成")
	check(s.execute("finish_sleep").ok and s.execute("continue_run").ok, "无梦无索命进入下一夜")
	resume(s)
	check(s.read_state().current_night_index == 2, "第二夜可正常经营")
	# Alternate route: walk the first seller, acquire a later item, and still finish.
	var rejected := fresh()
	drain(rejected)
	rejected.execute("open_shop")
	drain(rejected)
	rejected.counter_command("reject", rejected.counter_model().active_id)
	check("INTRO_FIRST_TRADE_DONE" not in rejected.read_state().narrative_flags, "送客不算成交")
	for step in 60:
		if not rejected.counter_model().active_id.is_empty(): break
		rejected.execute("short_task")
	var next := rejected._counter.customers.active(rejected._day.state)
	check(next != null, "教程失败后仍有正常客流")
	if next != null:
		rejected.counter_command("offer", next.visit_id, "", next.trade.reserve_price)
		drain(rejected)
		check("INTRO_FIRST_TRADE_DONE" in rejected.read_state().narrative_flags, "后续首笔真实交易补齐标记")
	# Tampering and failed writes must not invent props or advance dialogue.
	var codec := SaveCodec.new()
	var tampered := codec.encode(s._day.state, 12)
	tampered.narrative_flags.erase("INTRO_LETTER_STORED")
	check(codec.decode(tampered, definition, 12, catalog) == null, "拒绝道具标记与事件历史不符的存档")
	var blocked := fresh()
	blocked._save.path = "res://project.godot/unwritable.json"
	before = blocked.read_state()
	check(not blocked.event_command(before.pending_event_id, "continue").ok and blocked.read_state() == before, "保存失败整段回滚")
	print("OPENING TESTS: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
