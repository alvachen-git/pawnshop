class_name RunSession
extends RefCounted

signal changed

var definition: RunDefinition
var content_version: int
var message := "开铺前准备。查看面板不耗时；开铺后可接待顾客。"
var _day: DayController
var _save: SaveManager
var _counter: CounterService
var _events: EventDirector
var _commerce: CommerceService
var _risk: RiskManager
var _risk_error := ""

func _init(run_definition: RunDefinition, version: int, save_manager: SaveManager, catalog: ContentCatalog = null) -> void:
	definition = run_definition
	content_version = version
	_save = save_manager
	_day = DayController.new(definition, RunState.create(definition))
	_day.state.death_archive = _save.read_archive()
	if catalog != null:
		_counter = CounterService.new(catalog)
		_commerce = CommerceService.new(catalog)
		_events = EventDirector.new(catalog)
		if not definition.ghost_rule_ids.is_empty(): _risk = RiskManager.new(catalog)
		_save.catalog = catalog
		_counter.customers.prepare_night(_day.state, definition, catalog)
		_events.poll(_day.state, definition)

func read_state() -> Dictionary:
	return _day.state.to_read_model()

func has_save() -> bool:
	return _save.exists()

func can_execute(command: String) -> bool:
	return _day.state.risk_pending.is_empty() and _day.state.phase != &"dead" and _day.state.pending_event_id.is_empty() and _day.can_execute(command)

func execute(command: String) -> ActionResult:
	if not _day.state.risk_pending.is_empty() or _day.state.phase == &"dead": return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	# Only these commands create checkpoints. Snapshot before mutation for rollback.
	var checkpoint := command in ["resolve_night", "continue_run"]
	var previous: RunState
	if checkpoint:
		previous = _copy_state(_day.state)
	if command == "resolve_night" and _day.can_execute(command) and _commerce != null:
		_commerce.pawns.resolve_maturities(_day.state, definition.night_minutes)
	var result := _day.execute(command)
	if result.ok and _risk != null:
		_risk.capture_close(_day.state)
		if command == "resolve_night": _risk.settle(_day.state)
	if result.ok and _counter != null:
		if command == "continue_run" and _day.state.phase == &"pre_open":
			_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
		_counter.customers.update(_day.state)
	if result.ok and _events != null: _events.poll(_day.state, definition)
	if result.ok and checkpoint:
		if not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
		else:
			result.message = "这一夜的账，记下了。"
	message = result.message
	changed.emit()
	return result

func load_checkpoint() -> ActionResult:
	_risk_error = ""
	var restored := _save.load_state(definition, content_version)
	var result := ActionResult.new(restored != null, "账册翻回了上次合拢的那一页。" if restored != null else _save.error_message)
	if restored != null:
		_day.state = restored
		if _counter != null and restored.phase == &"pre_open":
			_counter.customers.prepare_night(restored, definition, _counter.catalog)
	message = result.message
	changed.emit()
	return result

func new_run() -> void:
	_risk_error = ""
	var archive := _day.state.death_archive.duplicate(true)
	_day.state = RunState.create(definition)
	_day.state.death_archive.assign(archive)
	if _counter != null:
		_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
	if _events != null: _events.poll(_day.state, definition)
	message = "暮色又落到了铺门前。柜上的账册，翻开了第一页。"
	changed.emit()

func _copy_state(source: RunState) -> RunState:
	var copy := RunState.new()
	for key in source.to_read_model():
		if key in ["inventory_instances", "pawn_tickets"]: continue
		copy.set(key, source.get(key).duplicate(true) if source.get(key) is Array or source.get(key) is Dictionary else source.get(key))
	for item in source.inventory_instances:
		var clone := ItemInstance.new()
		for key in item.to_data(): clone.set(key, item.to_data()[key])
		copy.inventory_instances.append(clone)
	for ticket in source.pawn_tickets:
		var clone := PawnTicket.new()
		for key in ticket.to_data(): clone.set(key, ticket.to_data()[key])
		copy.pawn_tickets.append(clone)
	copy.visits = source.visits.duplicate()
	return copy

func counter_command(command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	if not _day.state.risk_pending.is_empty() or _day.state.phase == &"dead": return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	var result := ActionResult.new(false, "当前运行未接入柜台内容。")
	if _counter != null:
		result = _counter.execute(_day, command, visit_id, detail, amount)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	changed.emit()
	return result

func counter_model() -> Dictionary:
	var model := CounterReadModels.build(_day, _counter, message)
	if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)
	if not _day.state.pending_event_id.is_empty():
		model.trade.can_offer = false
		model.trade.can_pawn = false
		for key in ["appraisal", "dialogue", "trade", "inventory", "ledger"]:
			for button in model[key].get("buttons", []):
				button.enabled = false
				button.reason = "请先处理铺中记事。"
	return model

func commerce_command(command: String, target: String, detail := "") -> ActionResult:
	if not _day.state.risk_pending.is_empty() or _day.state.phase == &"dead": return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	var result := ActionResult.new(false, "当前运行没有交易内容。")
	if _commerce != null:
		result = _commerce.execute(_day, command, target, detail)
		_counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	changed.emit()
	return result

func event_model() -> Dictionary:
	return _events.model(_day, message) if _events != null else {"body": "暂无记事。", "buttons": [], "pending_id": ""}

func event_command(event_id: String, choice_id: String) -> ActionResult:
	if not _day.state.risk_pending.is_empty() or _day.state.phase == &"dead": return _risk_blocked()
	var result := ActionResult.new(false, "没有事件内容。")
	if _events != null:
		result = _events.choose(_day, event_id, choice_id)
		if result.ok and _counter != null: _counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	message = result.message
	changed.emit()
	return result

func _event_blocked() -> ActionResult:
	message = "请先到「铺中记事」处理眼前的事情。"
	changed.emit()
	return ActionResult.new(false, message)

func risk_model() -> Dictionary:
	return RiskReadModels.build(_day, _risk, _risk_error) if _risk != null else {"body": "本运行未启用鬼货。", "buttons": [], "history": "", "pending_id": "", "held_ids": []}

func risk_command(command: String, id: String) -> ActionResult:
	if _risk == null: return ActionResult.new(false, "本运行未启用鬼货。")
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	var result: ActionResult
	if command in ["retreat", "defy"]:
		var previous := _copy_state(_day.state)
		result = _risk.respond(_day.state, id, command)
		if result.ok and not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			result = ActionResult.new(false, "应对未提交，请重试。" + _save.error_message)
	else:
		result = _risk.handle(_day, id, command)
		if result.ok:
			_counter.customers.update(_day.state)
			_events.poll(_day.state, definition)
	_risk_error = "" if result.ok else result.message
	message = result.message
	changed.emit()
	return result

func _risk_blocked() -> ActionResult:
	message = "灯已冷了，铺中再没有人应声。" if _day.state.phase == &"dead" else "请先在「鬼货与绝当录」应对镜中来客。"
	changed.emit()
	return ActionResult.new(false, message)
