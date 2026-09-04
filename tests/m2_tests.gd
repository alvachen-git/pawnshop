class_name M2Tests
extends RefCounted

var check: Callable
var catalog: ContentCatalog
var definition: RunDefinition
var _paths: Array[String] = []

func run(expect: Callable) -> void:
	check = expect
	catalog = JsonContentProvider.new("res://data/content_manifest.json").load_catalog().catalog
	definition = catalog.get_definition("runs", catalog.default_run_id)
	_evidence()
	_negotiation()
	_atomic_purchase()
	_waiting_and_deadlines()
	_persistence()
	_content_contract()
	_checkpoint_failure()
	for path in _paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _session() -> RunSession:
	var path := "user://tests/m2_%d_%d.json" % [Time.get_ticks_usec(), _paths.size()]
	_paths.append(path)
	return RunSession.new(definition, catalog.content_version, SaveManager.new(path), catalog)

func _open(session: RunSession) -> String:
	session.execute("open_shop")
	return session.counter_model().active_id

func _command(session: RunSession, command: String, detail := "", price := 0) -> ActionResult:
	return session.counter_command(command, session.counter_model().active_id, detail, price)

func _evidence() -> void:
	var first := _session()
	var second := _session()
	var id := _open(first)
	_open(second)
	check.call(not id.is_empty(), "开铺后第一位顾客入场。")
	var snapshot := first.read_state()
	for count in 20: first.counter_model()
	check.call(first.read_state() == snapshot, "免费查询不会推进时间或消耗耐心。")
	check.call(not _command(first, "appraise", "light").ok and first.read_state().game_minutes == 0, "缺少前置证据不能跳过鉴定步骤。")
	for action in ["observe", "base", "light"]:
		check.call(_command(first, "appraise", action).ok, "确定性鉴定动作：" + action)
		_command(second, "appraise", action)
	check.call(first.counter_model().appraisal == second.counter_model().appraisal, "相同变体和行动得到相同证据，无成功率抽签。")
	check.call(first.counter_model().appraisal.body.contains("18–25") and first.counter_model().appraisal.body.contains("补釉接缝"), "物理证据揭示修补并收窄估值。")
	var minute: int = first.read_state().game_minutes
	check.call(not _command(first, "appraise", "light").ok and first.read_state().game_minutes == minute, "重复鉴定不产生新信息或重复耗时。")
	_command(first, "judge", "sound")
	check.call(first.counter_model().appraisal.body.contains("完好真品") and first.counter_model().appraisal.body.contains("18–25"), "玩家错误判断不会改写证据估值。")
	check.call(_command(first, "question", "condition").ok, "卖家口供可询问。")
	minute = first.read_state().game_minutes
	check.call(not _command(first, "question", "condition").ok and first.read_state().game_minutes == minute, "同一问题不能无限试探。")
	check.call(first.counter_model().dialogue.body.contains("未证实"), "卖家口供不会伪装为已验证证据。")
	var instance := ItemInstance.new()
	instance.revealed_clue_ids = ["shape"]
	var item: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
	check.call(not AppraisalSystem.new().can_perform(instance, item, "base", []), "没有放大镜时动作被领域层拒绝。")
	var serialized := JSON.stringify(first.counter_model())
	check.call(not serialized.contains("reserve_price") and not serialized.contains("selected_variant_id") and not serialized.contains("true_value") and not serialized.contains('"patience":'), "表现层读模型不泄露底价、真值、变体或精确耐心。")

func _negotiation() -> void:
	var session := _session()
	var id := _open(session)
	for action in ["observe", "base", "light"]: _command(session, "appraise", action)
	check.call(_command(session, "pressure", "repair").ok and session.counter_model().trade.asking_price == 32, "真实瑕疵施压降低要价并消耗一轮。")
	check.call(session.counter_model().trade.body.contains("轮次 2"), "正式施压计入有限议价轮次。")
	var snapshot := session.read_state()
	check.call(not _command(session, "pressure", "repair").ok and session.read_state() == snapshot, "同一瑕疵不可重复压价。")
	check.call(_command(session, "offer", "", 18).ok and session.read_state().cash == 82, "证据降低隐藏底价后可按18成交。")
	check.call(not session.counter_command("offer", id, "", 18).ok, "已成交顾客不能重复报价。")
	var stubborn := _session()
	id = _open(stubborn)
	for count in 3: stubborn.counter_command("offer", id, "", 1)
	check.call(stubborn.read_state().game_minutes == 15 and stubborn.read_state().cash == 100, "三轮低价试探耗时15分钟且不误扣现金。")
	check.call(_outcome(stubborn, id) in ["patience_exhausted", "rounds_exhausted"], "轮次/耐心用尽即离场。")
	check.call(not stubborn.counter_command("offer", id, "", 60).ok, "失败三轮后不能再接受底价成交。")
	var false_claim := _session()
	id = _open(false_claim)
	_command(false_claim, "appraise", "observe")
	_command(false_claim, "pressure", "shape")
	check.call(false_claim.counter_model().trade.asking_price == 72 and false_claim.counter_model().trade.body.contains("不耐烦"), "非瑕疵证据不会降价，并损失隐藏耐心。")
	_command(false_claim, "appraise", "base")
	_command(false_claim, "pressure", "mark")
	check.call(_outcome(false_claim, id) == "patience_exhausted", "错误施压可在轮次用尽前惹怒顾客离场。")

func _atomic_purchase() -> void:
	var session := _session()
	var id := _open(session)
	for amount in [-1, 0, 101, 1000001]:
		var snapshot := session.read_state()
		check.call(not session.counter_command("offer", id, "", amount).ok and session.read_state() == snapshot, "非法或现金不足报价不进入试价流程：%d" % amount)
	_command(session, "judge", "sound")
	check.call(_command(session, "offer", "", 60).ok, "玩家可以因误判而高价收货。")
	var state := session.read_state()
	check.call(state.cash == 40 and state.inventory_instances.size() == 1 and state.ledger_entries.size() == 1, "现金、库存、流水一次性提交。")
	var item: ItemDefinition = catalog.get_definition("items", state.inventory_instances[0].definition_id)
	var truth := item.find_variant(state.inventory_instances[0].selected_variant_id)
	check.call(state.inventory_instances[0].acquisition_price - truth.true_value == 40, "错误判断真实支付60收得价值20的物品，形成40估值缺口。")
	check.call(state.ledger_entries[0].amount == -60 and state.ledger_entries[0].balance == 40, "收购流水和现金余额可对账。")
	var before := session.read_state()
	session.counter_command("offer", id, "", 60)
	check.call(session.read_state() == before, "重复成交/过期意图不能重复扣款入库。")
	check.call(session.counter_model().inventory.body.contains("未出售") and session.counter_model().inventory.body.contains("60"), "库存显示成本且不冒充已实现盈亏。")
	var model := session.counter_model()
	model.inventory.body = "fake"
	check.call(session.counter_model().inventory.body != "fake", "库存表现层快照不能改写运行状态。")

func _waiting_and_deadlines() -> void:
	var waiting := _session()
	var id := _open(waiting)
	waiting.execute("wait_hour")
	check.call(waiting.counter_model().queue.contains("等待中 1 人"), "处理其他事务时第二位顾客排队。")
	waiting.execute("long_task")
	check.call(waiting.read_state().visit_history.any(func(entry: Dictionary) -> bool: return entry.outcome == "timed_out"), "排队顾客会按行动时间超时离场。")
	var refusal := _session()
	id = _open(refusal)
	check.call(_command(refusal, "reject").ok and refusal.read_state().game_minutes == 5 and _outcome(refusal, id) == "rejected", "拒客送走顾客并消耗5分钟。")
	var deadline := _session()
	id = _open(deadline)
	deadline.execute("wait_hour")
	deadline.execute("long_task")
	deadline.execute("short_task")
	check.call(not deadline.counter_command("offer", id, "", 60).ok and deadline.read_state().cash == 100 and deadline.read_state().inventory_instances.is_empty(), "动作结束恰到顾客离场时限时，不进行迟到成交。")
	check.call(deadline.read_state().game_minutes == 100 and _outcome(deadline, id) == "timed_out", "未及时完成仍消耗动作时间，并记录离场。")
	var closed := _session()
	id = _open(closed)
	closed.execute("close_shop")
	check.call(not closed.counter_command("offer", id, "", 60).ok and closed.read_state().visit_history.size() == definition.customer_slots.size(), "关门结束当前及后续来客机会，不能继续交易。")
	var dto := RunDTO.from_source(_source("res://data/runs/p0_daily_loop.json").records[0])
	dto.customer_slots = [{"id": "edge", "arrival": 535, "customer_id": "customer_citizen", "item_id": "item_blue_bowl", "variant_id": "sound"}]
	var edge_run := RunDefinition.from_dto(dto)
	var state := RunState.create(edge_run)
	var service := CounterService.new(catalog)
	service.customers.prepare_night(state, edge_run, catalog)
	var day := DayController.new(edge_run, state)
	day.execute("open_shop")
	day.spend_action(535)
	service.customers.update(state)
	id = service.customers.active(state).visit_id
	check.call(not service.execute(day, "question", id, "origin").ok and state.phase == &"night_resolution" and state.cash == 100, "03:00封铺优先于迟到的柜台效果。")

func _persistence() -> void:
	var session := _session()
	_open(session)
	_command(session, "offer", "", 60)
	session.execute("close_shop")
	session.execute("wait_until_seal")
	check.call(session.execute("resolve_night").ok, "含收购物品的夜末检查点成功保存。")
	var restored := RunSession.new(definition, catalog.content_version, SaveManager.new(_paths.back()), catalog)
	check.call(restored.load_checkpoint().ok and restored.read_state() == session.read_state(), "库存、现金、流水和顾客历史精确恢复。")
	check.call(restored.execute("continue_run").ok and restored.read_state().inventory_instances.size() == 1 and restored.read_state().cash == 40, "跨夜保留收货成本和现金占款。")
	check.call(restored.counter_model().active_id.is_empty(), "恢复后开铺前不凭空接待顾客。")
	var save := SaveManager.new(_paths.back())
	save.catalog = catalog
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save.path))
	for mutation in ["duplicate", "price", "cash", "balance", "evidence", "variant", "reference", "missing_history", "version"]:
		var broken := valid.duplicate(true)
		match mutation:
			"duplicate": broken.inventory_instances.append(broken.inventory_instances[0])
			"price": broken.inventory_instances[0].acquisition_price += 1
			"cash": broken.cash += 1
			"balance": broken.ledger_entries[0].balance += 1
			"evidence": broken.inventory_instances[0].revealed_clue_ids = ["repair"]
			"variant": broken.inventory_instances[0].selected_variant_id = "sound"
			"reference": broken.inventory_instances[0].definition_id = "absent"
			"missing_history": broken.visit_history.clear()
			"version": broken.save_version = 1
		check.call(SaveCodec.new().decode(broken, definition, catalog.content_version, catalog) == null, "拒绝无法对账/伪造的交易存档：" + mutation)

func _content_contract() -> void:
	var item_source := _source("res://data/items/items_m2.json")
	for mutation in ["missing", "enum", "fraction", "duplicate"]:
		var invalid := item_source.duplicate(true)
		match mutation:
			"missing": invalid.records[0].clues[0].erase("text")
			"enum": invalid.records[0].clues[0].judgement = "magic"
			"fraction": invalid.records[0].appraisal_actions[0].minutes = 2.5
			"duplicate": invalid.records[0].clues.append(invalid.records[0].clues[0])
		check.call(not SourceSchemaValidator.new().validate_collection("items", invalid, "memory://m2").is_empty(), "嵌套Schema拒绝：" + mutation)
	var dto := ItemDTO.from_source(item_source.records[0])
	dto.appraisal_actions[0].requires_clues = ["repair"]
	var invalid_catalog := ContentCatalog.new()
	invalid_catalog.add_definition("items", ItemDefinition.from_dto(dto))
	check.call(not InMemoryContentProvider.new(invalid_catalog).load_catalog().is_success(), "内存Provider也拒绝证据循环依赖。")
	var memory_catalog := ContentCatalog.new()
	memory_catalog.content_version = catalog.content_version
	memory_catalog.default_run_id = catalog.default_run_id
	for kind in ["buyers", "pawn_terms"]:
		for definition_entry in catalog.get_all(kind): memory_catalog.add_definition(kind, definition_entry)
	for record in item_source.records: memory_catalog.add_definition("items", ItemDefinition.from_dto(ItemDTO.from_source(record)))
	for record in _source("res://data/customers/customers_m2.json").records: memory_catalog.add_definition("customers", CustomerDefinition.from_dto(CustomerDTO.from_source(record)))
	memory_catalog.add_definition("runs", RunDefinition.from_dto(RunDTO.from_source(_source("res://data/runs/p0_daily_loop.json").records[0])))
	check.call(InMemoryContentProvider.new(memory_catalog).load_catalog().is_success(), "独立DTO映射的内存目录通过校验。")
	var json_session := _session()
	var memory_session := RunSession.new(memory_catalog.get_definition("runs", memory_catalog.default_run_id), memory_catalog.content_version, SaveManager.new(), memory_catalog)
	for session in [json_session, memory_session]:
		_open(session)
		for action in ["observe", "base", "light"]: _command(session, "appraise", action)
		_command(session, "pressure", "repair")
		_command(session, "offer", "", 18)
	check.call(json_session.read_state() == memory_session.read_state(), "JSON与独立内存目录驱动等价的鉴定/议价/收购结果。")
	var real_item: ItemDefinition = catalog.get_definition("items", "item_blue_bowl")
	var copied_clues := real_item.clues
	copied_clues.clear()
	check.call(not real_item.clues.is_empty(), "定义集合返回副本，运行时不能清空内容。")
	var renamed_item := ItemDTO.from_source(item_source.records[0])
	renamed_item.id = "new_content_item"
	var renamed_customer := CustomerDTO.from_source(_source("res://data/customers/customers_m2.json").records[0])
	renamed_customer.id = "new_content_customer"
	renamed_customer.pawn_terms_id = ""
	renamed_customer.item_pool = [renamed_item.id]
	var renamed_run := RunDTO.from_source(_source("res://data/runs/p0_daily_loop.json").records[0])
	renamed_run.id = "new_content_run"
	renamed_run.buyer_ids = []
	renamed_run.customer_slots = [{"id": "new_slot", "arrival": 0, "customer_id": renamed_customer.id, "item_id": renamed_item.id, "variant_id": "repaired"}]
	var renamed_catalog := ContentCatalog.new()
	renamed_catalog.default_run_id = renamed_run.id
	renamed_catalog.add_definition("items", ItemDefinition.from_dto(renamed_item))
	renamed_catalog.add_definition("customers", CustomerDefinition.from_dto(renamed_customer))
	renamed_catalog.add_definition("runs", RunDefinition.from_dto(renamed_run))
	check.call(InMemoryContentProvider.new(renamed_catalog).load_catalog().is_success(), "全新物品/顾客/运行ID只改数据即可通过校验。")
	var renamed_session := RunSession.new(renamed_catalog.get_definition("runs", renamed_run.id), 3, SaveManager.new(), renamed_catalog)
	_open(renamed_session)
	_command(renamed_session, "offer", "", 60)
	check.call(renamed_session.read_state().inventory_instances[0].definition_id == renamed_item.id, "业务不依赖青花碗或顾客具体ID。")

func _checkpoint_failure() -> void:
	var path := "user://tests/m2_rollback_%d.json" % Time.get_ticks_usec()
	_paths.append(path)
	var failing := M1Tests.FailingSave.new(path)
	var session := RunSession.new(definition, catalog.content_version, failing, catalog)
	_open(session)
	_command(session, "offer", "", 60)
	session.execute("close_shop")
	session.execute("wait_until_seal")
	var before := session.read_state()
	check.call(not session.execute("resolve_night").ok and session.read_state() == before, "交易后存档失败回滚结算但不丢失既有库存/现金。")
	failing.fail_writes = false
	check.call(session.execute("resolve_night").ok and session.read_state().inventory_instances.size() == 1 and session.read_state().cash == 40, "重试只保存一次，不重复扣款或入库。")

func _outcome(session: RunSession, id: String) -> String:
	for entry in session.read_state().visit_history:
		if entry.visit_id == id: return entry.outcome
	return ""

func _source(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
