class_name M4Tests
extends RefCounted

class ToggleSave extends SaveManager:
	var fail := false
	func save_state(state: RunState, run: RunDefinition, version: int) -> bool:
		if fail:
			error_message = "测试写档失败"
			return false
		return super.save_state(state, run, version)

var _expect: Callable
var _catalog: ContentCatalog
var _run: RunDefinition
var _paths: Array = []

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://tests/fixtures/m4_manifest.json").load_catalog()
	_expect.call(loaded.is_success(), "M4生产Manifest通过源结构与领域校验")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		return
	_catalog = loaded.catalog
	_run = _catalog.get_definition("runs", _catalog.default_run_id)
	_expect.call(_catalog.get_count("items") == 8 and _catalog.get_count("customers") == 4 and _catalog.get_count("events") == 7, "M4生效内容为8物品、4顾客、7事件")
	_content_and_extension()
	_director_boundaries()
	_three_nights_and_saves()
	_inventory_event()
	_invalid_content()
	for path in _paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _session(catalog: ContentCatalog = _catalog, run: RunDefinition = _run) -> RunSession:
	var path := "user://tests/m4_%d_%d.json" % [Time.get_ticks_usec(), _paths.size()]
	_paths.append(path)
	return RunSession.new(run, catalog.content_version, SaveManager.new(path), catalog)

func _source(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _resolve(session: RunSession, preferred := "") -> void:
	for guard in 20:
		var id: String = session.read_state().pending_event_id
		if id.is_empty(): return
		var event := session._events.catalog.get_definition("events", id) as EventDefinition
		var choice: String = preferred if event.find_choice(preferred) != null else event.choices[0].id
		_expect.call(session.event_command(id, choice).ok, "配置事件可处理：" + id)
	_expect.call(false, "事件链必须有限")

func _finish(session: RunSession) -> void:
	_resolve(session)
	if session.read_state().phase == "open": _expect.call(session.execute("close_shop").ok, "M4关门")
	_resolve(session)
	_expect.call(session.execute("wait_until_seal").ok, "M4推进到封铺")
	_expect.call(session.execute("resolve_night").ok, "M4结算写档：" + session.message)

func _content_and_extension() -> void:
	var seen: Array = []
	var schedules: Array = []
	for night in 3:
		var state := RunState.create(_run)
		state.current_night_index = night + 1
		CustomerManager.new().prepare_night(state, _run, _catalog)
		var ids: Array = []
		for visit in state.visits:
			ids.append(String(visit.item.definition_id))
			if visit.item.definition_id not in seen: seen.append(String(visit.item.definition_id))
		schedules.append(ids)
		_expect.call(state.visits.size() == 4, "每夜只加载本夜4个来访槽")
	_expect.call(seen.size() == 8 and schedules[0] != schedules[1] and schedules[1] != schedules[2], "三夜编排覆盖8种货且互不相同")
	for definition: ItemDefinition in _catalog.get_all("items"):
		for variant in definition.possible_variants:
			var instance := ItemInstance.new()
			instance.definition_id = definition.id
			instance.selected_variant_id = variant.id
			var appraisal := AppraisalSystem.new()
			for action in definition.appraisal_actions:
				if appraisal.can_perform(instance, definition, action.id, _run.tools): appraisal.perform(instance, definition, action.id)
			var bounds := appraisal.valuation(instance, definition)
			_expect.call(instance.revealed_clue_ids.size() == variant.clue_ids.size() and bounds.x <= variant.true_value and bounds.y >= variant.true_value and bounds.y - bounds.x < definition.unknown_max - definition.unknown_min, "证据覆盖并收窄估值：%s/%s" % [definition.id, variant.id])
	# This file is the entire extension: no Trade/Appraisal/Customer/Event code changes.
	var fixture := _source("res://tests/fixtures/m4_extension.json")
	var mapper := ContentMapper.new()
	var catalog := ContentCatalog.new()
	catalog.content_version = 5
	catalog.default_run_id = "extension_run"
	for kind in fixture:
		var schema := SourceSchemaValidator.new().validate_collection(kind, {"schema_version": 1, "records": fixture[kind]}, "fixture")
		_expect.call(schema.is_empty(), "新增配置通过源校验：" + kind)
		for record in fixture[kind]: catalog.add_definition(kind, mapper.map_record(kind, record))
	var memory := InMemoryContentProvider.new(catalog).load_catalog()
	_expect.call(memory.is_success(), "全新物品/顾客/事件/运行ID只改JSON即可通过领域校验")
	if not memory.is_success():
		for issue in memory.issues: print(issue.format_message())
		return
	var run: RunDefinition = catalog.get_definition("runs", catalog.default_run_id)
	var session := _session(catalog, run)
	_expect.call(session.read_state().pending_event_id == "extension_event", "新事件由通用导演触发")
	_resolve(session)
	session.execute("open_shop")
	var id: String = session.counter_model().active_id
	_expect.call(not id.is_empty(), "全新顾客由CustomerManager出现")
	for action in ["look", "inspect"]: _expect.call(session.counter_command("appraise", id, action).ok, "全新物品使用既有鉴定核心：" + action)
	_expect.call(session.counter_command("offer", id, "", 24).ok and session.read_state().cash == 76 and session.read_state().inventory_instances.size() == 1, "全新商品成交扣款入库，无特定ID分支")
	var before := session.read_state()
	for i in 5: session.event_model(); session.counter_model()
	_expect.call(before == session.read_state(), "查询所有ReadModel不改权威状态")
	var dto := EventDTO.from_source(fixture.events[0])
	var immutable := EventDefinition.from_dto(dto)
	dto.choices[0].grant_flags.clear()
	var returned := immutable.choices
	returned.clear()
	_expect.call(immutable.choices.size() == 1 and immutable.choices[0].grant_flags == ["extension_seen"], "事件定义不共享DTO或返回数组的可变状态")

func _director_boundaries() -> void:
	var session := _session()
	var before := session.read_state()
	_expect.call(before.pending_event_id == "shen_opening", "沈怀川锚点优先于随机闲谈")
	_expect.call(not session.execute("open_shop").ok and before == session.read_state(), "未处理锚点不能开铺或消耗时间")
	_expect.call(not session.event_command("shen_opening", "missing").ok and before == session.read_state(), "未知选项不产生状态变化")
	_expect.call(session.event_command("shen_opening", "independent").ok, "可选择自行经营")
	_expect.call(not session.event_command("shen_opening", "contact").ok and "contact_requested" not in session.read_state().narrative_flags, "旧事件意图不能重复产生效果")
	var offered: String = session.read_state().pending_event_id
	for i in 10: session.event_model()
	_expect.call(session.read_state().pending_event_id == offered, "查看事件不重新抽样")
	_resolve(session)
	_expect.call(session.read_state().event_history.size() == 2 and session.read_state().pending_event_id.is_empty(), "锚点不占普通事件额度；一夜只选一个普通事件")
	var director := EventDirector.new(_catalog)
	var state := RunState.create(_run)
	state.current_night_index = 2
	state.narrative_flags = ["contact_requested"]
	_expect.call(director.select_next(state, _run) == "cash_lesson", "第二夜锚点优先于符合条件的回信")
	# Deterministic weighted selection across independent states, with both outcomes reachable.
	var choices := {}
	for seed in 40:
		var a := RunState.create(_run)
		a.run_seed = seed
		a.event_history = [{"event_id": "shen_opening", "night": 1}]
		var selected := director.select_next(a, _run)
		choices[selected] = true
		_expect.call(selected == director.select_next(a, _run), "相同seed与历史的事件选择确定性：%d" % seed)
	_expect.call(choices.size() == 2 and choices.has("rain_news") and choices.has("patient_buyer"), "不同seed可选中两种加权普通事件")
	# Boundary tests use independent data definitions, not edits to production state.
	var row: Dictionary = _source("res://data/events/events_m4.json").records[4].duplicate(true)
	row.night_max = 3
	row.max_count = 3
	row.cooldown = 1
	var cooldown := EventDefinition.from_dto(EventDTO.from_source(row))
	state.event_history = [{"event_id": row.id, "night": 1}]
	_expect.call(not director.eligible(state, cooldown), "事件冷却期不重复出现")
	state.current_night_index = 3
	_expect.call(director.eligible(state, cooldown), "冷却结束后可再次进入候选")
	row.conflicts_with = ["patient_buyer"]
	var conflict := EventDefinition.from_dto(EventDTO.from_source(row))
	state.event_history = [{"event_id": "patient_buyer", "night": 3}]
	_expect.call(not director.eligible(state, conflict), "当夜互斥事件不可共存")
	row.phase = "open"
	row.window_start = 60
	row.window_end = 90
	row.choices[0].minutes = 10
	var window := EventDefinition.from_dto(EventDTO.from_source(row))
	state.event_history.clear()
	state.phase = &"open"
	state.game_minutes = 55
	_expect.call(not director.eligible(state, window), "事件窗口开始前不可触发")
	state.game_minutes = 60
	_expect.call(director.eligible(state, window), "事件窗口起点可触发")
	state.game_minutes = 90
	_expect.call(not director.eligible(state, window), "事件窗口终点不再触发")

func _three_nights_and_saves() -> void:
	var session := _session()
	_resolve(session, "contact")
	session.execute("open_shop")
	var id: String = session.counter_model().active_id
	_expect.call(session.counter_command("pawn", id, "", 27).ok, "M4仍可活当放款27")
	_finish(session)
	var save := session._save
	var checkpoint := session.read_state()
	_expect.call(session.load_checkpoint().ok and session.read_state() == checkpoint, "M4日结恢复事件历史、选择、资金和当票")
	_expect.call(session.execute("continue_run").ok and session.read_state().pending_event_id == "cash_lesson", "下一夜检查点包含未处理锚点")
	var next := session.read_state()
	_resolve(session)
	_expect.call("buyer_introduced" in session.read_state().narrative_flags, "前夜选择触发次夜回信并解锁买家")
	_expect.call(session.load_checkpoint().ok and session.read_state() == next, "重读下一夜检查点恢复原待办，不保留夜内解锁")
	_resolve(session)
	session.execute("open_shop")
	_expect.call(session.commerce_command("redeem", session.read_state().pawn_tickets[0].ticket_id).ok and session.read_state().cash == 106, "M4事件不破坏到访赎回")
	id = session.counter_model().active_id
	_expect.call(session.counter_command("offer", id, "", 80).ok and session.read_state().cash == 26, "第二夜收购怀表真实占用现金")
	var watch: String = session.read_state().inventory_instances[1].instance_id
	_expect.call(not session.commerce_command("sell", watch, "buyer_introduced").ok, "介绍买家仍受19点营业窗口约束")
	session.execute("wait_hour")
	_expect.call(session.commerce_command("sell", watch, "buyer_introduced").ok and session.read_state().cash == 126, "事件介绍真实买家：80收货、100出售、利润20")
	_finish(session)
	var codec := SaveCodec.new()
	var encoded := codec.encode(session._day.state, 5)
	_expect.call(codec.decode(JSON.parse_string(JSON.stringify(encoded)), _run, 5, _catalog) != null, "M4含事件与买家解锁的存档往返")
	for mode in ["flag", "choice", "duplicate", "pending", "time", "anchor", "old_version"]:
		var bad := encoded.duplicate(true)
		match mode:
			"flag": bad.narrative_flags.append("invented_unlock")
			"choice": bad.event_history[0].choice_id = "missing"
			"duplicate": bad.event_history.append(bad.event_history[0].duplicate())
			"pending": bad.pending_event_id = "shen_opening"
			"time": bad.event_history[0].minute = 5
			"anchor": bad.event_history.remove_at(0)
			"old_version": bad.save_version = 3
		_expect.call(codec.decode(bad, _run, 5, _catalog) == null, "拒绝损坏或不兼容M4事件存档：" + mode)
	# Fail after the next-night event has been scheduled; rollback includes all narrative state.
	var failing := ToggleSave.new(save.path)
	failing.catalog = _catalog
	session._save = failing
	failing.fail = true
	var prior := session.read_state()
	for attempt in 2: _expect.call(not session.execute("continue_run").ok and prior == session.read_state(), "写档失败完整回滚新夜、待办与事件状态")
	failing.fail = false
	_expect.call(session.execute("continue_run").ok, "写档恢复后可继续第三夜")
	_resolve(session)
	session.execute("open_shop")
	_finish(session)
	_expect.call(session.execute("continue_run").ok and session.read_state().phase == "run_ended", "含记事、交易与活当的三夜完整闭环")
	_expect.call(session.load_checkpoint().ok and session.read_state().phase == "run_ended", "三夜结束检查点恢复")

func _invalid_content() -> void:
	var event: Dictionary = _source("res://data/events/events_m4.json").records[0]
	for mode in ["missing", "weight", "fraction", "effects"]:
		var row := event.duplicate(true)
		match mode:
			"missing": row.erase("choices")
			"weight": row.weight = -1
			"fraction": row.cooldown = 0.5
			"effects": row.choices[0].grant_flags = [7]
		_expect.call(not EventSchema.validate(row, "test", "event").is_empty(), "事件源校验拒绝：" + mode)
	for mode in ["anchor_window", "unknown_flag", "missing_item", "choice_cost", "missing_conflict"]:
		var row := event.duplicate(true)
		row.id = "invalid_event"
		match mode:
			"anchor_window": row.phase = "open"
			"unknown_flag": row.required_flags = ["unknown"]
			"missing_item": row.required_items = ["unknown"]
			"choice_cost": row.choices[0].minutes = 5
			"missing_conflict": row.conflicts_with = ["unknown"]
		var catalog := ContentCatalog.new()
		catalog.add_definition("events", EventDefinition.from_dto(EventDTO.from_source(row)))
		_expect.call(not EventDomainValidator.validate(catalog).is_empty(), "内存Provider领域校验拒绝：" + mode)

func _inventory_event() -> void:
	var session := _session()
	_resolve(session, "independent")
	session.execute("open_shop")
	session.counter_command("reject", session.counter_model().active_id)
	session.execute("wait_hour")
	session.execute("long_task")
	_expect.call(session.counter_command("offer", session.counter_model().active_id, "", 35).ok and session.read_state().inventory_instances.size() == 1, "第二类顾客带来的烛台可按配置收购")
	_finish(session)
	session.execute("continue_run")
	_resolve(session)
	_expect.call("buyer_introduced" not in session.read_state().narrative_flags, "自行经营分支不会收到介绍或解锁买家")
	session.execute("open_shop")
	session.execute("close_shop")
	_expect.call(session.read_state().pending_event_id == "stock_note", "持仓条件在下一夜关门后触发；前夜事件额度不污染后夜")
	var before := session.read_state()
	_expect.call(not session.counter_command("offer", "stale", "", 1).ok and session.read_state() == before, "待处理事件阻止过期柜台操作")
	_expect.call(session.event_command("stock_note", "note").ok and session.read_state().game_minutes == before.game_minutes + 5, "关门后的正式事件选择消耗5分钟")
	_expect.call(session.read_state().inventory_instances[0].revealed_clue_ids.is_empty(), "提醒不凭空赠送鉴定证据")
	session.execute("wait_until_seal")
	_expect.call(session.execute("resolve_night").ok, "含持仓条件与关门事件的存档通过历史校验")
	var saved := session.read_state()
	_expect.call(session.load_checkpoint().ok and session.read_state() == saved, "持仓条件事件读档不重复执行")
